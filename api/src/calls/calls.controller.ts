import { Controller, UseGuards } from '@nestjs/common';
import { BlockScaffoldRestGuard } from '../common/guards/block-scaffold-rest.guard';

@Controller('calls')
@UseGuards(BlockScaffoldRestGuard)
export class CallsController {}
