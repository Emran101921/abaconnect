import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { MatchingService } from './matching.service';

@Controller('matching')
export class MatchingController {
  constructor(private readonly matchingService: MatchingService) {}

  @Post()
  create(@Body() data: Record<string, unknown>) {
    return this.matchingService.create(data);
  }

  @Get()
  findAll() {
    return this.matchingService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.matchingService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() data: Record<string, unknown>) {
    return this.matchingService.update(id, data);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.matchingService.remove(id);
  }

  @Post('discover')
  discover(
    @Body()
    body: {
      tenantId: string;
      therapyType?: string;
      latitude?: number;
      longitude?: number;
    },
  ) {
    return this.matchingService.findTherapistsForMatch(
      body.tenantId,
      body.therapyType,
      body.latitude,
      body.longitude,
    );
  }

  @Post('score')
  scoreProviders(
    @Body()
    body: {
      providers: { id: string; distanceKm: number; rating: number }[];
      weights?: { distance: number; rating: number };
    },
  ) {
    return this.matchingService.scoreProviders(
      body.providers ?? [],
      body.weights,
    );
  }
}
