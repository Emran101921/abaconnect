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
import { ParentsService } from './parents.service';
import { BlockScaffoldRestGuard } from '../common/guards/block-scaffold-rest.guard';

@Controller('parents')
@UseGuards(BlockScaffoldRestGuard)
export class ParentsController {
  constructor(private readonly parentsService: ParentsService) {}

  @Post()
  create(
    @Body()
    data: {
      userId: string;
      tenantId: string;
      addressLine1?: string;
      city?: string;
      state?: string;
      zipCode?: string;
    },
  ) {
    return this.parentsService.create(data);
  }

  @Get()
  findAll() {
    return this.parentsService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.parentsService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() data: Record<string, unknown>) {
    return this.parentsService.update(id, data);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.parentsService.remove(id);
  }
}
