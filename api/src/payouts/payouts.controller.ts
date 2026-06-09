import { Body, Controller, Get, Param, Patch, Post } from '@nestjs/common';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { PayoutsService } from './payouts.service';

@Controller('payouts')
export class PayoutsController {
  constructor(private readonly payoutsService: PayoutsService) {}

  @Get()
  @Roles('PLATFORM_ADMIN')
  findAll(@CurrentUser() user: AuthUser) {
    return this.payoutsService.listForTenant(user.tenantId ?? '');
  }

  @Post()
  @Roles('PLATFORM_ADMIN')
  create(
    @Body()
    body: {
      tenantId: string;
      therapistId: string;
      amount: number;
      periodStart: string;
      periodEnd: string;
    },
  ) {
    return this.payoutsService.createForTherapist(body.tenantId, {
      therapistId: body.therapistId,
      amount: body.amount,
      periodStart: new Date(body.periodStart),
      periodEnd: new Date(body.periodEnd),
    });
  }

  @Patch(':id/paid')
  @Roles('PLATFORM_ADMIN')
  markPaid(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.payoutsService.markPaid(user.tenantId ?? '', id);
  }
}
