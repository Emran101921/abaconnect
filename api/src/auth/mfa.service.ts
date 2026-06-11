import { BadRequestException, Injectable } from '@nestjs/common';
import { createGuardrails } from '@otplib/core';
import { generateSecret, generateURI, verify } from 'otplib';
import { decryptField, encryptField } from '../common/crypto/field-crypto.util';
import { PrismaService } from '../prisma/prisma.service';
import { DeviceContext, DeviceService } from './device.service';

const ROLES_REQUIRING_MFA = new Set(['PARENT', 'THERAPIST', 'AGENCY_ADMIN']);

@Injectable()
export class MfaService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly devices: DeviceService,
  ) {}

  private encryptionKey(): string {
    return (
      process.env.PHI_ENCRYPTION_KEY ??
      process.env.JWT_SECRET ??
      'dev-only-phi-key'
    );
  }

  private encryptSecret(secret: string): string {
    return encryptField(secret, this.encryptionKey());
  }

  private decryptSecret(stored: string): string {
    try {
      return decryptField(stored, this.encryptionKey());
    } catch {
      return stored;
    }
  }

  generateSecret(email: string): { secret: string; otpauthUrl: string } {
    const secret = generateSecret();
    const otpauthUrl = generateURI({
      issuer: 'BloomOra',
      label: email,
      secret,
    });
    return { secret, otpauthUrl };
  }

  async verifyCode(secret: string, code: string): Promise<boolean> {
    const token = code.replace(/\s/g, '');
    const bypass = process.env.DEV_MFA_BYPASS_CODE?.trim();
    if (
      process.env.NODE_ENV !== 'production' &&
      bypass &&
      /^\d{6}$/.test(bypass) &&
      token === bypass
    ) {
      return true;
    }
    const result = await verify({
      secret,
      token,
      epochTolerance: 30,
      guardrails: createGuardrails({ MIN_SECRET_BYTES: 10 }),
    });
    return result.valid;
  }

  async beginSetup(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new BadRequestException('User not found');
    }
    if (user.mfaEnabled) {
      throw new BadRequestException('MFA is already enabled');
    }
    const { secret, otpauthUrl } = this.generateSecret(user.email);
    await this.prisma.user.update({
      where: { id: userId },
      data: { mfaSecret: this.encryptSecret(secret), mfaEnabled: false },
    });
    const payload: { otpauthUrl: string; secret?: string } = { otpauthUrl };
    if (process.env.NODE_ENV !== 'production') {
      payload.secret = secret;
    }
    return payload;
  }

  async enable(userId: string, code: string, ctx?: DeviceContext) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user?.mfaSecret) {
      throw new BadRequestException('Run MFA setup first');
    }
    const secret = this.decryptSecret(user.mfaSecret);
    if (!(await this.verifyCode(secret, code))) {
      throw new BadRequestException('Invalid verification code');
    }
    await this.prisma.user.update({
      where: { id: userId },
      data: { mfaEnabled: true },
    });
    // Stamp the enrolling device with model + IP + approximate location and
    // mark it trusted so future logins from it are recognized.
    await this.devices.recordMfaSetup(
      { id: user.id, tenantId: user.tenantId },
      ctx,
    );
    return { enabled: true };
  }

  async disable(userId: string, code: string, password: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user?.mfaSecret || !user.mfaEnabled) {
      throw new BadRequestException('MFA is not enabled');
    }
    if (ROLES_REQUIRING_MFA.has(user.role)) {
      throw new BadRequestException(
        'Two-factor authentication is required for this account and cannot be disabled',
      );
    }
    const bcrypt = await import('bcrypt');
    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) {
      throw new BadRequestException('Invalid password');
    }
    const secret = this.decryptSecret(user.mfaSecret);
    if (!(await this.verifyCode(secret, code))) {
      throw new BadRequestException('Invalid verification code');
    }
    await this.prisma.user.update({
      where: { id: userId },
      data: { mfaEnabled: false, mfaSecret: null },
    });
    return { enabled: false };
  }

  async status(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    return { enabled: user?.mfaEnabled ?? false };
  }

  async verifyForUser(
    user: { mfaSecret: string | null; mfaEnabled: boolean },
    code: string,
  ): Promise<boolean> {
    if (!user.mfaEnabled || !user.mfaSecret) {
      return true;
    }
    return this.verifyCode(this.decryptSecret(user.mfaSecret), code);
  }
}
