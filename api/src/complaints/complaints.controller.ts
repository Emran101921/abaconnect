import { Body, Controller, Get, Param, Patch, Post } from '@nestjs/common';
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
    @Body()
    body: {
      reporterUserId: string;
      category: string;
      subject: string;
      description: string;
      therapistId?: string;
    },
  ) {
    return this.complaintsService.fileComplaint(body.reporterUserId, body);
  }

  @Patch(':id/resolve')
  @Roles('PLATFORM_ADMIN')
  resolve(@Param('id') id: string, @Body('resolution') resolution: string) {
    return this.complaintsService.resolveComplaint(id, resolution);
  }
}
