import { Body, Controller, Get, Param, Patch, Post } from '@nestjs/common';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { ComplaintsService } from './complaints.service';

@Controller('complaints')
export class ComplaintsController {
  constructor(private readonly complaintsService: ComplaintsService) {}

  @Get()
  @Roles('PLATFORM_ADMIN')
  findAll() {
    return this.complaintsService.findAll();
  }

  @Post('file')
  file(
    @CurrentUser() user: AuthUser,
    @Body()
    body: {
      category: string;
      subject: string;
      description: string;
      therapistId?: string;
    },
  ) {
    return this.complaintsService.fileComplaint(user.id, body);
  }

  @Patch(':id/resolve')
  @Roles('PLATFORM_ADMIN')
  resolve(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body('resolution') resolution: string,
  ) {
    return this.complaintsService.resolveComplaint(
      user.tenantId!,
      id,
      resolution,
    );
  }
}
