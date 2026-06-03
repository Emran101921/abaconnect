import { Controller, Get } from '@nestjs/common';
import { Public } from './common/decorators/public.decorator';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Public()
  @Get()
  getHello(): string {
    return this.appService.getHello();
  }

  @Public()
  @Get('health')
  health(): { status: string; api: string; graphql: string } {
    return {
      status: 'ok',
      api: '/api/v1',
      graphql: '/graphql',
    };
  }

  @Public()
  @Get('payments/success')
  paymentSuccess(): { ok: boolean; message: string } {
    return {
      ok: true,
      message:
        'Payment received. Return to the ABAConnect app and refresh Payments.',
    };
  }

  @Public()
  @Get('payments/cancel')
  paymentCancel(): { ok: boolean; message: string } {
    return {
      ok: false,
      message: 'Checkout cancelled. You can try again from the app.',
    };
  }
}
