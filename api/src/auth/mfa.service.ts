import { BadRequestException, Injectable } from '@nestjs/common';
import { generateSecret, generateURI, verify } from 'otplib';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class MfaService {
  constructor(private readonly prisma: PrismaService) {}

  generateSecret(email: string): { secret: string; otpauthUrl: string } {
    const secret = generateSecret();
    const otpauthUrl = generateURI({
      issuer: 'ABAConnect',
      label: email,
      secret,
    });
    return { secret, otpauthUrl };
  }

  async verifyCode(secret: string, code: string): Promise<boolean> {
    const result = await verify({
      secret,
      token: code.replace(/\s/g, ''),
      epochTolerance: 30,
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
      data: { mfaSecret: secret, mfaEnabled: false },
    });
    return { secret, otpauthUrl };
  }

  async enable(userId: string, code: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user?.mfaSecret) {
      throw new BadRequestException('Run MFA setup first');
    }
    if (!(await this.verifyCode(user.mfaSecret, code))) {
      throw new BadRequestException('Invalid verification code');
    }
    await this.prisma.user.update({
      where: { id: userId },
      data: { mfaEnabled: true },
    });
    return { enabled: true };
  }

  async disable(userId: string, code: string, password: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user?.mfaSecret || !user.mfaEnabled) {
      throw new BadRequestException('MFA is not enabled');
    }
    const bcrypt = await import('bcrypt');
    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) {
      throw new BadRequestException('Invalid password');
    }
    if (!(await this.verifyCode(user.mfaSecret, code))) {
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
    return this.verifyCode(user.mfaSecret, code);
  }
}
