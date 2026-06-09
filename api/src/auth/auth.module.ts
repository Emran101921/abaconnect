import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { SecurityModule } from '../security/security.module';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { MfaService } from './mfa.service';
import { RefreshTokenService } from './refresh-token.service';
import { JwtStrategy } from './jwt.strategy';

@Module({
  imports: [
    SecurityModule,
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_SECRET') ?? 'change-me',
        signOptions: {
          expiresIn: config.get<number>('JWT_EXPIRES_SECONDS') ?? 3600,
        },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, MfaService, RefreshTokenService, JwtStrategy],
  exports: [AuthService, JwtModule],
})
export class AuthModule {}
