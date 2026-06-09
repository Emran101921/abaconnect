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
import { GpsService } from './gps.service';
import { BlockScaffoldRestGuard } from '../common/guards/block-scaffold-rest.guard';

@Controller('gps')
@UseGuards(BlockScaffoldRestGuard)
export class GpsController {
  constructor(private readonly gpsService: GpsService) {}

  @Post()
  create(@Body() data: Record<string, unknown>) {
    return this.gpsService.create(data);
  }

  @Get()
  findAll() {
    return this.gpsService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.gpsService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() data: Record<string, unknown>) {
    return this.gpsService.update(id, data);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.gpsService.remove(id);
  }
}
