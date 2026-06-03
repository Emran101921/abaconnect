import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { MessagingService } from './messaging.service';

@Controller('messaging')
export class MessagingController {
  constructor(private readonly messagingService: MessagingService) {}

  @Post()
  create(@Body() data: Record<string, unknown>) {
    return this.messagingService.create(data);
  }

  @Get()
  findAll() {
    return this.messagingService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.messagingService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() data: Record<string, unknown>) {
    return this.messagingService.update(id, data);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.messagingService.remove(id);
  }
}
