import {
  UseGuards,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { ComplianceService } from './compliance.service';
import { BlockScaffoldRestGuard } from '../common/guards/block-scaffold-rest.guard';

@Controller('compliance')
@UseGuards(BlockScaffoldRestGuard)
export class ComplianceController {
  constructor(private readonly complianceService: ComplianceService) {}

  @Post()
  create(@Body() data: Record<string, unknown>) {
    return this.complianceService.create(data);
  }

  @Get()
  findAll() {
    return this.complianceService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.complianceService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() data: Record<string, unknown>) {
    return this.complianceService.update(id, data);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.complianceService.remove(id);
  }
}
