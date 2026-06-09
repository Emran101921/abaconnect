import { Body, Controller, Get, Param, Patch } from '@nestjs/common';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { DisputesService } from './disputes.service';

@Controller('disputes')
export class DisputesController {
  constructor(private readonly disputesService: DisputesService) {}

  @Get()
  @Roles('PLATFORM_ADMIN')
  findAll() {
    return this.disputesService.findAll();
  }

  @Patch(':id/resolve')
  @Roles('PLATFORM_ADMIN')
  resolve(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body('resolution') resolution: string,
  ) {
    return this.disputesService.resolve(user.tenantId!, id, resolution);
  }
}
