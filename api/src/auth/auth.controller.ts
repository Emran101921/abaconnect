import { Body, Controller, Get, Post, Req } from '@nestjs/common';
import type { Request } from 'express';
import { Throttle } from '@nestjs/throttler';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';
import { MfaService } from './mfa.service';
import { LoginDto, RegisterDto } from './dto/auth.dto';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly mfaService: MfaService,
  ) {}

  @Public()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Public()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('login')
  login(@Body() dto: LoginDto, @Req() req: Request) {
    return this.authService.login(dto, {
      ipAddress: req.ip,
      userAgent: req.headers['user-agent'],
    });
  }

  @Public()
  @Post('refresh')
  refresh(@Body('refreshToken') refreshToken: string) {
    return this.authService.refresh(refreshToken);
  }

  @Public()
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('forgot-password')
  forgotPassword(@Body('email') email: string) {
    return this.authService.requestPasswordReset(email);
  }

  @Public()
  @Post('reset-password')
  resetPassword(
    @Body('token') token: string,
    @Body('newPassword') newPassword: string,
  ) {
    return this.authService.resetPassword(token, newPassword);
  }

  @Public()
  @Post('login/mfa')
  loginMfa(
    @Body('mfaChallengeToken') mfaChallengeToken: string,
    @Body('code') code: string,
  ) {
    return this.authService.completeMfaLogin(mfaChallengeToken, code);
  }

  @Post('logout')
  logout(@CurrentUser() user: AuthUser) {
    return this.authService.logout(user.id);
  }

  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.authService.me(user.id);
  }

  @Get('mfa/status')
  mfaStatus(@CurrentUser() user: AuthUser) {
    return this.mfaService.status(user.id);
  }

  @Post('mfa/setup')
  mfaSetup(@CurrentUser() user: AuthUser) {
    return this.mfaService.beginSetup(user.id);
  }

  @Post('mfa/enable')
  mfaEnable(@CurrentUser() user: AuthUser, @Body('code') code: string) {
    return this.mfaService.enable(user.id, code);
  }

  @Post('mfa/disable')
  mfaDisable(
    @CurrentUser() user: AuthUser,
    @Body('code') code: string,
    @Body('password') password: string,
  ) {
    return this.mfaService.disable(user.id, code, password);
  }

  @Post('device')
  registerDevice(
    @CurrentUser() user: AuthUser,
    @Body('deviceToken') deviceToken: string,
    @Body('platform') platform: string,
    @Body('appVersion') appVersion?: string,
  ) {
    return this.authService.registerDevice(user.id, {
      deviceToken,
      platform,
      appVersion,
    });
  }
}
