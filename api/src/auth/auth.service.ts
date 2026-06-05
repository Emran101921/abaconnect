import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { MailService } from '../mail/mail.service';
import { PrismaService } from '../prisma/prisma.service';
import { MfaService } from './mfa.service';
import { JwtPayload } from './jwt.strategy';

export interface RegisterDto {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
  role?: 'PARENT' | 'THERAPIST' | 'AGENCY_ADMIN' | 'PLATFORM_ADMIN';
  tenantId?: string;
}

export interface LoginDto {
  email: string;
  password: string;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export type LoginResult =
  | AuthTokens
  | { requiresMfa: true; mfaChallengeToken: string };

export interface AuthMeResponse {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  role: string;
  tenantId: string;
  parentId?: string;
  therapistId?: string;
  mfaEnabled: boolean;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly mfaService: MfaService,
    private readonly mailService: MailService,
  ) {}

  async me(userId: string): Promise<AuthMeResponse> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { parent: true, therapist: true },
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      role: user.role,
      tenantId: user.tenantId,
      parentId: user.parent?.id,
      therapistId: user.therapist?.id,
      mfaEnabled: user.mfaEnabled,
    };
  }

  async register(dto: RegisterDto): Promise<AuthTokens> {
    const tenantId = dto.tenantId ?? (await this.defaultTenantId());
    const existing = await this.findUserByEmail(dto.email, tenantId);
    if (existing) {
      throw new ConflictException('Email already registered');
    }
    const passwordHash = await bcrypt.hash(dto.password, 10);
    const role = dto.role ?? 'PARENT';
    const user = await this.prisma.user.create({
      data: {
        tenantId,
        email: dto.email,
        passwordHash,
        role,
        firstName: dto.firstName,
        lastName: dto.lastName,
      },
    });
    if (role === 'PARENT') {
      await this.prisma.parent.create({
        data: { userId: user.id, tenantId },
      });
    }
    if (role === 'THERAPIST') {
      await this.prisma.therapist.create({
        data: { userId: user.id, tenantId },
      });
    }
    await this.prisma.auditLog.create({
      data: {
        tenantId,
        actorId: user.id,
        action: 'CREATE',
        entityType: 'user',
        entityId: user.id,
        metadata: { event: 'register' },
      },
    });
    return this.issueTokens(user.id, user.email, [role], tenantId);
  }

  async login(dto: LoginDto): Promise<LoginResult> {
    const user = await this.prisma.user.findFirst({
      where: { email: dto.email },
    });
    if (!user?.passwordHash) {
      throw new UnauthorizedException('Invalid credentials');
    }
    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (user.mfaEnabled && user.mfaSecret) {
      const mfaChallengeToken = this.jwtService.sign(
        { sub: user.id, purpose: 'mfa_challenge' },
        { expiresIn: '5m' },
      );
      return { requiresMfa: true, mfaChallengeToken };
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });
    return this.issueTokens(user.id, user.email, [user.role], user.tenantId);
  }

  async completeMfaLogin(
    mfaChallengeToken: string,
    code: string,
  ): Promise<AuthTokens> {
    let payload: { sub: string; purpose?: string };
    try {
      payload = this.jwtService.verify(mfaChallengeToken);
    } catch {
      throw new UnauthorizedException('MFA challenge expired — sign in again');
    }
    if (payload.purpose !== 'mfa_challenge') {
      throw new UnauthorizedException('Invalid MFA challenge');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
    });
    if (!user?.mfaSecret) {
      throw new UnauthorizedException('MFA not configured');
    }
    if (!(await this.mfaService.verifyForUser(user, code))) {
      throw new UnauthorizedException('Invalid authenticator code');
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });
    return this.issueTokens(user.id, user.email, [user.role], user.tenantId);
  }

  async requestPasswordReset(email: string): Promise<{
    message: string;
    resetToken?: string;
  }> {
    const user = await this.findUserByEmail(email);
    const message =
      'If an account exists for this email, password reset instructions have been sent.';
    if (!user) {
      return { message };
    }

    const resetToken = this.jwtService.sign(
      { sub: user.id, purpose: 'password_reset' },
      {
        secret: process.env.JWT_RESET_SECRET ?? process.env.JWT_SECRET,
        expiresIn: '1h',
      },
    );

    await this.prisma.auditLog.create({
      data: {
        tenantId: user.tenantId,
        actorId: user.id,
        action: 'UPDATE',
        entityType: 'user',
        entityId: user.id,
        metadata: { event: 'password_reset_requested' },
      },
    });

    const appUrl = process.env.APP_URL ?? 'http://localhost:3000';
    const resetUrl = `${appUrl}/reset-password?token=${encodeURIComponent(resetToken)}`;
    await this.mailService.sendPasswordResetEmail(user.email, resetUrl);

    if (process.env.NODE_ENV !== 'production') {
      return { message, resetToken };
    }
    return { message };
  }

  async resetPassword(
    token: string,
    newPassword: string,
  ): Promise<{ message: string }> {
    if (newPassword.length < 8) {
      throw new BadRequestException('Password must be at least 8 characters');
    }

    let payload: { sub: string; purpose?: string };
    try {
      payload = this.jwtService.verify(token, {
        secret: process.env.JWT_RESET_SECRET ?? process.env.JWT_SECRET,
      });
    } catch {
      throw new UnauthorizedException('Invalid or expired reset token');
    }

    if (payload.purpose !== 'password_reset') {
      throw new UnauthorizedException('Invalid reset token');
    }

    const passwordHash = await bcrypt.hash(newPassword, 10);
    const user = await this.prisma.user.update({
      where: { id: payload.sub },
      data: { passwordHash },
    });

    await this.prisma.auditLog.create({
      data: {
        tenantId: user.tenantId,
        actorId: user.id,
        action: 'UPDATE',
        entityType: 'user',
        entityId: user.id,
        metadata: { event: 'password_reset_completed' },
      },
    });

    return { message: 'Password updated successfully' };
  }

  async refresh(refreshToken: string): Promise<AuthTokens> {
    try {
      const payload = this.jwtService.verify<JwtPayload>(refreshToken, {
        secret: process.env.JWT_REFRESH_SECRET ?? process.env.JWT_SECRET,
      });
      return this.issueTokens(
        payload.sub,
        payload.email,
        payload.roles,
        payload.tenantId,
      );
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  private issueTokens(
    userId: string,
    email: string,
    roles?: string[],
    tenantId?: string,
  ): AuthTokens {
    const payload: JwtPayload = { sub: userId, email, roles, tenantId };
    const accessToken = this.jwtService.sign(payload);
    const refreshToken = this.jwtService.sign(payload, {
      secret: process.env.JWT_REFRESH_SECRET ?? process.env.JWT_SECRET,
      expiresIn: '7d',
    });
    return { accessToken, refreshToken };
  }

  async registerDevice(
    userId: string,
    data: { deviceToken: string; platform: string; appVersion?: string },
  ) {
    if (!data.deviceToken?.trim()) {
      throw new BadRequestException('deviceToken is required');
    }
    const platform = data.platform?.trim() || 'unknown';
    return this.prisma.userDevice.upsert({
      where: {
        userId_deviceToken: {
          userId,
          deviceToken: data.deviceToken.trim(),
        },
      },
      create: {
        userId,
        deviceToken: data.deviceToken.trim(),
        platform,
        appVersion: data.appVersion,
      },
      update: {
        platform,
        appVersion: data.appVersion,
        lastSeenAt: new Date(),
      },
    });
  }

  private async defaultTenantId(): Promise<string> {
    const tenant = await this.prisma.tenant.findFirst({
      where: { slug: 'abaconnect' },
    });
    if (!tenant) {
      throw new ConflictException(
        'Platform tenant not seeded. Run: npx prisma db seed',
      );
    }
    return tenant.id;
  }

  private async findUserByEmail(
    email: string,
    tenantId?: string,
  ): Promise<{
    id: string;
    email: string;
    passwordHash: string;
    role: string;
    tenantId: string;
  } | null> {
    if (tenantId) {
      return this.prisma.user.findUnique({
        where: { tenantId_email: { tenantId, email } },
      });
    }
    return this.prisma.user.findFirst({ where: { email } });
  }
}
