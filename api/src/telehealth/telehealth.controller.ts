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
import { TelehealthService } from './telehealth.service';
import { BlockScaffoldRestGuard } from '../common/guards/block-scaffold-rest.guard';

@Controller('telehealth')
@UseGuards(BlockScaffoldRestGuard)
export class TelehealthController {
  constructor(private readonly telehealthService: TelehealthService) {}

  @Post()
  create(@Body() data: Record<string, unknown>) {
    return this.telehealthService.create(data);
  }

  @Get()
  findAll() {
    return this.telehealthService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.telehealthService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() data: Record<string, unknown>) {
    return this.telehealthService.update(id, data);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.telehealthService.remove(id);
  }
}
