import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { AuditService } from './audit.service';

@Controller('audit')
export class AuditController {
  constructor(private readonly auditService: AuditService) {}

  @Post()
  create(@Body() data: Record<string, unknown>) {
    return this.auditService.create(data);
  }

  @Get()
  findAll() {
    return this.auditService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.auditService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() data: Record<string, unknown>) {
    return this.auditService.update(id, data);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.auditService.remove(id);
  }

  @Post('log')
  log(
    @Body()
    body: {
      action: string;
      actorId?: string;
      metadata?: Record<string, unknown>;
    },
  ) {
    return this.auditService.log(body.action, body.actorId, body.metadata);
  }
}
