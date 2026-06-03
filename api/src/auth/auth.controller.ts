import { Body, Controller, Get, Post } from '@nestjs/common';
import { AuthUser, CurrentUser } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';
import { MfaService } from './mfa.service';
import { AuthService, LoginDto, RegisterDto } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly mfaService: MfaService,
  ) {}

  @Public()
  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Public()
  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Public()
  @Post('refresh')
  refresh(@Body('refreshToken') refreshToken: string) {
    return this.authService.refresh(refreshToken);
  }

  @Public()
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
}
