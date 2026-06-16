import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { createHash } from 'crypto';
import { MailService } from '../mail/mail.service';
import { PrismaService } from '../prisma/prisma.service';
import { SecurityEventService } from '../security/security-event.service';
import { MfaService } from './mfa.service';
import { RefreshTokenService } from './refresh-token.service';
import { DeviceContext, DeviceService } from './device.service';
import { LoginDto, RegisterDto } from './dto/auth.dto';
import { JwtPayload } from './jwt.strategy';

const MAX_FAILED_LOGIN_ATTEMPTS = 5;
const LOCKOUT_MINUTES = 15;

/// Roles that must complete HIPAA consent + MFA enrollment before use.
const ROLES_REQUIRING_ONBOARDING = new Set<string>([
  'PARENT',
  'THERAPIST',
  'AGENCY_ADMIN',
  'SERVICE_COORDINATOR',
]);

export type { LoginDto, RegisterDto };

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export type LoginResult =
  | AuthTokens
  | { requiresMfa: true; mfaChallengeToken: string; newDevice: boolean };

export type LoginContext = DeviceContext;

export interface AuthMeResponse {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  role: string;
  tenantId: string;
  parentId?: string;
  therapistId?: string;
  agencyId?: string;
  agencyOnboardingComplete?: boolean;
  mfaEnabled: boolean;
  hipaaConsentGranted: boolean;
  /** True when the user has acknowledged the currently active Notice of Privacy Practices. */
  privacyNoticeAcknowledged: boolean;
  activeNoticeVersion: string | null;
  onboardingComplete: boolean;
  /** Therapists only — true when admin has approved PHI access. */
  providerPhiAccessApproved?: boolean;
  providerOnboardingStatus?: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly mfaService: MfaService,
    private readonly mailService: MailService,
    private readonly refreshTokens: RefreshTokenService,
    private readonly securityEvents: SecurityEventService,
    private readonly devices: DeviceService,
  ) {}

  async me(userId: string): Promise<AuthMeResponse> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { parent: true, therapist: true, agency: true },
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    const { acknowledged, activeVersion } =
      await this.privacyNoticeAcknowledgmentStatus(user.id, user.tenantId);
    const hipaaConsentGranted = acknowledged;
    const requiresOnboarding = ROLES_REQUIRING_ONBOARDING.has(user.role);
    const providerPhiAccessApproved = user.therapist?.phiAccessApproved;
    const providerOnboardingStatus = user.therapist?.onboardingStatus;
    const agencyOnboardingComplete = user.agency?.onboardingComplete;
    const onboardingComplete = requiresOnboarding
      ? hipaaConsentGranted &&
        user.mfaEnabled &&
        (user.role !== 'THERAPIST' || providerPhiAccessApproved === true) &&
        (user.role !== 'AGENCY_ADMIN' || agencyOnboardingComplete === true)
      : true;
    return {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      role: user.role,
      tenantId: user.tenantId,
      parentId: user.parent?.id,
      therapistId: user.therapist?.id,
      agencyId: user.agencyId ?? undefined,
      agencyOnboardingComplete,
      mfaEnabled: user.mfaEnabled,
      hipaaConsentGranted,
      privacyNoticeAcknowledged: acknowledged,
      activeNoticeVersion: activeVersion,
      onboardingComplete,
      providerPhiAccessApproved,
      providerOnboardingStatus,
    };
  }

  private async privacyNoticeAcknowledgmentStatus(
    userId: string,
    tenantId: string,
  ): Promise<{ acknowledged: boolean; activeVersion: string | null }> {
    const active = await this.prisma.privacyNoticeVersion.findFirst({
      where: {
        isActive: true,
        OR: [{ tenantId }, { tenantId: null }],
      },
      orderBy: [{ tenantId: 'desc' }, { effectiveDate: 'desc' }],
      select: { id: true, versionNumber: true },
    });
    if (!active) {
      return { acknowledged: true, activeVersion: null };
    }
    const ack = await this.prisma.hipaaNoticeAcknowledgment.findFirst({
      where: { userId, noticeVersionId: active.id },
      select: { id: true },
    });
    return {
      acknowledged: ack != null,
      activeVersion: active.versionNumber,
    };
  }

  /** Devices a user has authenticated from (for the security/devices screen). */
  listDevices(userId: string) {
    return this.devices.listForUser(userId);
  }

  async register(dto: RegisterDto): Promise<AuthTokens> {
    const tenantId = dto.tenantId ?? (await this.defaultTenantId());
    const existing = await this.findUserByEmail(dto.email, tenantId);
    if (existing) {
      throw new ConflictException('Email already registered');
    }
    const passwordHash = await bcrypt.hash(dto.password, 10);
    const requestedRole = dto.role ?? 'PARENT';
    const role = this.resolvePublicRegisterRole(requestedRole);

    if (role === 'AGENCY_ADMIN' && !dto.agencyName?.trim()) {
      throw new BadRequestException('Agency name is required');
    }

    const user = await this.prisma.$transaction(async (tx) => {
      let agencyId: string | undefined;
      if (role === 'AGENCY_ADMIN') {
        const agency = await tx.agency.create({
          data: {
            tenantId,
            name: dto.agencyName!.trim(),
            ein: dto.agencyEin?.trim() || undefined,
            phone: dto.agencyPhone?.trim() || undefined,
            state: dto.agencyState?.trim() || undefined,
            zipCode: dto.agencyZipCode?.trim() || undefined,
            email: dto.email,
            onboardingComplete: false,
          },
        });
        agencyId = agency.id;
      }

      const created = await tx.user.create({
        data: {
          tenantId,
          email: dto.email,
          passwordHash,
          role,
          firstName: dto.firstName,
          lastName: dto.lastName,
          phone: dto.agencyPhone?.trim() || undefined,
          agencyId,
        },
      });

      if (role === 'PARENT') {
        await tx.parent.create({
          data: { userId: created.id, tenantId },
        });
      }
      if (role === 'THERAPIST') {
        await tx.therapist.create({
          data: { userId: created.id, tenantId },
        });
      }

      return created;
    });

    await this.prisma.auditLog.create({
      data: {
        tenantId,
        actorId: user.id,
        action: 'CREATE',
        entityType: 'user',
        entityId: user.id,
        metadata: { event: 'register', role },
      },
    });
    const created = await this.prisma.user.findUniqueOrThrow({
      where: { id: user.id },
    });
    return this.issueTokensForUser(created);
  }

  async login(dto: LoginDto, ctx?: LoginContext): Promise<LoginResult> {
    // Resolve login against a specific tenant so duplicate emails across
    // tenants can never collapse to an arbitrary row (cross-tenant auth).
    const tenantId = dto.tenantId ?? (await this.defaultTenantId());
    const user = await this.prisma.user.findUnique({
      where: { tenantId_email: { tenantId, email: dto.email } },
    });

    if (!user?.passwordHash) {
      await this.logUnknownLoginFailure(dto.email, 'unknown_email', ctx);
      throw new UnauthorizedException('Invalid credentials');
    }

    if (user.lockedUntil && user.lockedUntil > new Date()) {
      await this.securityEvents.log({
        tenantId: user.tenantId,
        userId: user.id,
        eventType: 'ACCOUNT_LOCKED',
        severity: 'WARNING',
        ipAddress: ctx?.ipAddress,
        userAgent: ctx?.userAgent,
        metadata: { reason: 'lockout_active' },
      });
      throw new UnauthorizedException(
        'Account temporarily locked. Try again later.',
      );
    }

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) {
      await this.handleFailedLogin(user, 'invalid_password', ctx);
      throw new UnauthorizedException('Invalid credentials');
    }
    if (!user.isActive) {
      await this.handleFailedLogin(user, 'inactive_account', ctx);
      throw new UnauthorizedException('Invalid credentials');
    }
    if (user.role === 'SERVICE_COORDINATOR') {
      const rosterActive = await this.prisma.agencyRoster.findFirst({
        where: {
          userId: user.id,
          role: 'SERVICE_COORDINATOR',
          status: 'ACTIVE',
          removedAt: null,
        },
      });
      if (!rosterActive) {
        await this.handleFailedLogin(user, 'roster_suspended', ctx);
        throw new UnauthorizedException('Invalid credentials');
      }
    }

    // Record the device this login originates from
    // new/untrusted device. New devices always require a fresh MFA challenge.
    const { isNewDevice } = await this.devices.recordLogin(
      { id: user.id, tenantId: user.tenantId },
      ctx,
    );

    // Step-up MFA is required only when signing in from a new or previously
    // untrusted device. Known trusted devices may proceed with password only.
    if (user.mfaEnabled && user.mfaSecret && isNewDevice) {
      await this.resetLoginAttempts(user.id);
      const mfaChallengeToken = this.jwtService.sign(
        {
          sub: user.id,
          purpose: 'mfa_challenge',
          deviceId: ctx?.deviceId,
          newDevice: true,
        },
        { expiresIn: '5m' },
      );
      return { requiresMfa: true, mfaChallengeToken, newDevice: true };
    }

    await this.resetLoginAttempts(user.id);
    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });
    return this.issueTokensForUser(user);
  }

  async completeMfaLogin(
    mfaChallengeToken: string,
    code: string,
    ctx?: LoginContext,
  ): Promise<AuthTokens> {
    let payload: { sub: string; purpose?: string; deviceId?: string };
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
    if (!user?.mfaSecret || !user.isActive) {
      throw new UnauthorizedException('MFA not configured');
    }
    if (!(await this.mfaService.verifyForUser(user, code))) {
      throw new UnauthorizedException('Invalid authenticator code');
    }

    await this.resetLoginAttempts(user.id);
    // Trust the device now that MFA has been satisfied, stamping it with the
    // current model + IP + approximate location.
    await this.devices.trustAfterMfa(
      { id: user.id, tenantId: user.tenantId },
      { ...ctx, deviceId: ctx?.deviceId ?? payload.deviceId },
    );
    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });
    return this.issueTokensForUser(user);
  }

  async logout(userId: string): Promise<{ message: string }> {
    await this.refreshTokens.revokeAllForUser(userId);
    await this.prisma.user.update({
      where: { id: userId },
      data: { tokenVersion: { increment: 1 } },
    });
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (user) {
      await this.prisma.auditLog.create({
        data: {
          tenantId: user.tenantId,
          actorId: userId,
          action: 'UPDATE',
          entityType: 'user',
          entityId: userId,
          metadata: { event: 'logout' },
        },
      });
    }
    return { message: 'Logged out' };
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
      data: {
        passwordHash,
        tokenVersion: { increment: 1 },
      },
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
      const stored = await this.refreshTokens.assertValid(refreshToken);
      const payload = this.jwtService.verify<JwtPayload>(refreshToken, {
        secret: process.env.JWT_REFRESH_SECRET ?? process.env.JWT_SECRET,
      });
      if (payload.sub !== stored.userId) {
        throw new UnauthorizedException('Invalid refresh token');
      }
      const user = await this.prisma.user.findUnique({
        where: { id: payload.sub },
      });
      if (!user?.isActive) {
        throw new UnauthorizedException('Invalid refresh token');
      }
      if (
        payload.tokenVersion != null &&
        payload.tokenVersion !== user.tokenVersion
      ) {
        throw new UnauthorizedException('Session has been revoked');
      }
      await this.refreshTokens.revokeToken(refreshToken);
      return this.issueTokensForUser(user);
    } catch (error) {
      if (error instanceof UnauthorizedException) throw error;
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  private async issueTokensForUser(user: {
    id: string;
    email: string;
    role: string;
    tenantId: string;
    tokenVersion: number;
  }): Promise<AuthTokens> {
    const tokens = this.issueTokens(
      user.id,
      user.email,
      [user.role],
      user.tenantId,
      user.tokenVersion,
    );
    await this.refreshTokens.store(
      user.id,
      tokens.refreshToken,
      new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    );
    return tokens;
  }

  private issueTokens(
    userId: string,
    email: string,
    roles?: string[],
    tenantId?: string,
    tokenVersion = 0,
  ): AuthTokens {
    const payload: JwtPayload = {
      sub: userId,
      email,
      roles,
      tenantId,
      tokenVersion,
    };
    const accessToken = this.jwtService.sign(payload);
    const refreshToken = this.jwtService.sign(payload, {
      secret: process.env.JWT_REFRESH_SECRET ?? process.env.JWT_SECRET,
      expiresIn: '7d',
    });
    return { accessToken, refreshToken };
  }

  private resolvePublicRegisterRole(
    role: RegisterDto['role'],
  ): 'PARENT' | 'THERAPIST' | 'AGENCY_ADMIN' {
    if (role === 'THERAPIST') return 'THERAPIST';
    if (role === 'AGENCY_ADMIN') return 'AGENCY_ADMIN';
    if (role && role !== 'PARENT') {
      throw new BadRequestException(
        'Only parent, therapist, and agency accounts can self-register',
      );
    }
    return 'PARENT';
  }

  private async handleFailedLogin(
    user: {
      id: string;
      tenantId: string;
      failedLoginAttempts: number;
    },
    reason: string,
    ctx?: LoginContext,
  ): Promise<void> {
    const attempts = user.failedLoginAttempts + 1;
    const lockedUntil =
      attempts >= MAX_FAILED_LOGIN_ATTEMPTS
        ? new Date(Date.now() + LOCKOUT_MINUTES * 60 * 1000)
        : null;

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        failedLoginAttempts: attempts,
        lockedUntil,
      },
    });

    await this.securityEvents.log({
      tenantId: user.tenantId,
      userId: user.id,
      eventType: 'LOGIN_FAILED',
      severity: lockedUntil ? 'WARNING' : 'INFO',
      ipAddress: ctx?.ipAddress,
      userAgent: ctx?.userAgent,
      metadata: { reason, attempts },
    });

    if (lockedUntil) {
      await this.securityEvents.log({
        tenantId: user.tenantId,
        userId: user.id,
        eventType: 'ACCOUNT_LOCKED',
        severity: 'WARNING',
        ipAddress: ctx?.ipAddress,
        userAgent: ctx?.userAgent,
        metadata: { lockoutMinutes: LOCKOUT_MINUTES, attempts },
      });
    }

    await this.prisma.auditLog.create({
      data: {
        tenantId: user.tenantId,
        actorId: user.id,
        action: 'LOGIN_FAILED',
        entityType: 'User',
        entityId: user.id,
        success: false,
        ipAddress: ctx?.ipAddress,
        userAgent: ctx?.userAgent,
        deviceId: ctx?.deviceId,
        metadata: { reason, attempts },
      },
    });
  }

  private async logUnknownLoginFailure(
    email: string,
    reason: string,
    ctx?: LoginContext,
  ): Promise<void> {
    const emailHash = createHash('sha256')
      .update(email.trim().toLowerCase())
      .digest('hex');
    await this.securityEvents.log({
      eventType: 'LOGIN_FAILED',
      severity: 'INFO',
      ipAddress: ctx?.ipAddress,
      userAgent: ctx?.userAgent,
      metadata: { reason, emailHash },
    });
  }

  private async resetLoginAttempts(userId: string): Promise<void> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { failedLoginAttempts: 0, lockedUntil: null },
    });
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
