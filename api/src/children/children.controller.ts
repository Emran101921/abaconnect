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
import { ChildrenService } from './children.service';
import { BlockScaffoldRestGuard } from '../common/guards/block-scaffold-rest.guard';

@Controller('children')
@UseGuards(BlockScaffoldRestGuard)
export class ChildrenController {
  constructor(private readonly childrenService: ChildrenService) {}

  @Post()
  create(
    @Body()
    data: {
      parentId: string;
      tenantId: string;
      firstName: string;
      lastName: string;
      dateOfBirth: string;
      gender?: string;
    },
  ) {
    return this.childrenService.create({
      ...data,
      dateOfBirth: new Date(data.dateOfBirth),
    });
  }

  @Get()
  findAll() {
    return this.childrenService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.childrenService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() data: Record<string, unknown>) {
    return this.childrenService.update(id, data);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.childrenService.remove(id);
  }
}
