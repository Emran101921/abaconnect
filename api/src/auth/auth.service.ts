import {
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
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

export interface AuthMeResponse {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  role: string;
  tenantId: string;
  parentId?: string;
  therapistId?: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
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

  async login(dto: LoginDto): Promise<AuthTokens> {
    const user = await this.findUserByEmail(dto.email);
    if (!user?.passwordHash) {
      throw new UnauthorizedException('Invalid credentials');
    }
    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) {
      throw new UnauthorizedException('Invalid credentials');
    }
    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });
    return this.issueTokens(user.id, user.email, [user.role], user.tenantId);
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
