import { Controller, Get } from '@nestjs/common';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { ComplianceService } from './compliance.service';

@Controller('compliance/me')
export class UserComplianceController {
  constructor(private readonly compliance: ComplianceService) {}

  @Get('phi-access-report')
  @Roles('PARENT', 'THERAPIST')
  getPhiAccessReport(@CurrentUser() user: AuthUser) {
    return this.compliance.getPhiAccessReportForUser(user.id);
  }
}
