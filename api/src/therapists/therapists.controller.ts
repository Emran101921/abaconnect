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
import { TherapistsService } from './therapists.service';
import { BlockScaffoldRestGuard } from '../common/guards/block-scaffold-rest.guard';

@Controller('therapists')
@UseGuards(BlockScaffoldRestGuard)
export class TherapistsController {
  constructor(private readonly therapistsService: TherapistsService) {}

  @Post()
  create(@Body() data: Record<string, unknown>) {
    return this.therapistsService.create(data);
  }

  @Get()
  findAll() {
    return this.therapistsService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.therapistsService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() data: Record<string, unknown>) {
    return this.therapistsService.update(id, data);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.therapistsService.remove(id);
  }
}
