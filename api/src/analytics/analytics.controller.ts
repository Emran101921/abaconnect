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
import { AnalyticsService } from './analytics.service';
import { BlockScaffoldRestGuard } from '../common/guards/block-scaffold-rest.guard';

@Controller('analytics')
@UseGuards(BlockScaffoldRestGuard)
export class AnalyticsController {
  constructor(private readonly analyticsService: AnalyticsService) {}

  @Post()
  create(@Body() data: Record<string, unknown>) {
    return this.analyticsService.create(data);
  }

  @Get()
  findAll() {
    return this.analyticsService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.analyticsService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() data: Record<string, unknown>) {
    return this.analyticsService.update(id, data);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.analyticsService.remove(id);
  }
}
