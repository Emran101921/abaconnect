import { Controller, Get, Param, Query } from '@nestjs/common';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { AuditService } from './audit.service';

@Controller('audit')
@Roles('PLATFORM_ADMIN')
export class AuditController {
  constructor(private readonly auditService: AuditService) {}

  @Get()
  findAll(@CurrentUser() user: AuthUser, @Query('take') take?: string) {
    return this.auditService.findAllForTenant(
      user.tenantId!,
      take ? Number(take) : 50,
    );
  }

  @Get(':id')
  findOne(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.auditService.findOneForTenant(user.tenantId!, id);
  }
}
