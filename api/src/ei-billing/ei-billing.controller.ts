import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { EiClearinghouseWorkflow } from '../../generated/prisma/client';
import { EiBillingClearinghouseService } from './ei-billing-clearinghouse.service';
import {
  resolveEiBillingActor,
} from './ei-billing-access.util';
import { PrismaService } from '../prisma/prisma.service';

@Controller('admin/ei-billing/clearinghouse')
@Roles('PLATFORM_ADMIN')
export class EiBillingController {
  constructor(
    private readonly clearinghouse: EiBillingClearinghouseService,
    private readonly prisma: PrismaService,
  ) {}

  @Get('configs')
  async listConfigs(
    @CurrentUser() user: AuthUser,
    @Query('agencyId') agencyId?: string,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    return this.clearinghouse.getConfig(actor, agencyId);
  }

  @Put('configs')
  async upsertConfig(
    @CurrentUser() user: AuthUser,
    @Body()
    body: {
      id?: string;
      agencyId?: string;
      name: string;
      workflow: EiClearinghouseWorkflow;
      tradingPartnerId?: string;
      submitterId?: string;
      receiverId?: string;
      apiEndpointRef?: string;
      sftpHostRef?: string;
      credentialsRef?: string;
      baaSignedAt?: string;
      baaEffectiveDate?: string;
      testMode?: boolean;
      isActive?: boolean;
    },
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    return this.clearinghouse.upsertConfig(actor, {
      ...body,
      baaSignedAt: body.baaSignedAt ? new Date(body.baaSignedAt) : undefined,
      baaEffectiveDate: body.baaEffectiveDate
        ? new Date(body.baaEffectiveDate)
        : undefined,
    });
  }

  @Post('configs/:id/test')
  async testConnection(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    return this.clearinghouse.testConnection(actor, id);
  }
}
