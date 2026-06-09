import { Controller, Get, Query } from '@nestjs/common';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { SecurityEventService } from './security-event.service';

@Controller('security')
@Roles('PLATFORM_ADMIN')
export class SecurityController {
  constructor(private readonly securityEvents: SecurityEventService) {}

  @Get('events')
  listEvents(
    @CurrentUser() user: AuthUser,
    @Query('take') take?: string,
    @Query('eventType') eventType?: string,
    @Query('userId') userId?: string,
  ) {
    return this.securityEvents.listForInvestigation({
      tenantId: user.tenantId!,
      take: take ? Number(take) : 50,
      eventType,
      userId,
    });
  }
}
