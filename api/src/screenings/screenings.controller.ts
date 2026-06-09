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
import { ScreeningsService } from './screenings.service';
import { BlockScaffoldRestGuard } from '../common/guards/block-scaffold-rest.guard';

@Controller('screenings')
@UseGuards(BlockScaffoldRestGuard)
export class ScreeningsController {
  constructor(private readonly screeningsService: ScreeningsService) {}

  @Post()
  create(@Body() data: Record<string, unknown>) {
    return this.screeningsService.create(data);
  }

  @Get()
  findAll() {
    return this.screeningsService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.screeningsService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() data: Record<string, unknown>) {
    return this.screeningsService.update(id, data);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.screeningsService.remove(id);
  }
}
