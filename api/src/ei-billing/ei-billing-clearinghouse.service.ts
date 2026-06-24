import { Injectable, NotFoundException } from '@nestjs/common';
import { AuditAction, EiClearinghouseWorkflow, Prisma } from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { EiBillingActor } from './ei-billing-access.util';
import { EiBillingAuditService } from './ei-billing-audit.service';
import { EiBillingAdapterRegistry } from './adapters/ei-billing-adapter.registry';

@Injectable()
export class EiBillingClearinghouseService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: EiBillingAuditService,
    private readonly adapters: EiBillingAdapterRegistry,
  ) {}

  async getConfig(actor: EiBillingActor, agencyId?: string) {
    return this.prisma.eiClearinghouseConfig.findMany({
      where: {
        tenantId: actor.tenantId,
        ...(agencyId ? { agencyId } : {}),
      },
      orderBy: { updatedAt: 'desc' },
    });
  }

  async upsertConfig(
    actor: EiBillingActor,
    input: {
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
      baaSignedAt?: Date;
      baaEffectiveDate?: Date;
      testMode?: boolean;
      isActive?: boolean;
    },
  ) {
    const data = {
      tenantId: actor.tenantId,
      agencyId: input.agencyId,
      name: input.name,
      workflow: input.workflow,
      tradingPartnerId: input.tradingPartnerId,
      submitterId: input.submitterId,
      receiverId: input.receiverId,
      apiEndpointRef: input.apiEndpointRef,
      sftpHostRef: input.sftpHostRef,
      credentialsRef: input.credentialsRef,
      baaSignedAt: input.baaSignedAt,
      baaEffectiveDate: input.baaEffectiveDate,
      testMode: input.testMode ?? true,
      isActive: input.isActive ?? false,
    };

    const config = input.id
      ? await this.prisma.eiClearinghouseConfig.update({
          where: { id: input.id },
          data,
        })
      : await this.prisma.eiClearinghouseConfig.create({ data });

    await this.audit.log(
      actor.tenantId,
      actor.id,
      actor.role,
      AuditAction.EI_BILLING_CLEARINGHOUSE_CONFIG_UPDATED,
      'EiClearinghouseConfig',
      config.id,
      { workflow: input.workflow, testMode: config.testMode },
    );

    return config;
  }

  async testConnection(actor: EiBillingActor, configId: string) {
    const config = await this.prisma.eiClearinghouseConfig.findFirst({
      where: { id: configId, tenantId: actor.tenantId },
    });
    if (!config) {
      throw new NotFoundException('Clearinghouse config not found');
    }

    const adapter = this.adapters.getAdapter(config.workflow);
    const result = await adapter.testConnection(config);

    const updated = await this.prisma.eiClearinghouseConfig.update({
      where: { id: configId },
      data: {
        lastConnectionTestAt: new Date(),
        lastConnectionTestResult: result.message,
        errorLogs: result.success
          ? (config.errorLogs as Prisma.InputJsonValue)
          : (JSON.parse(
              JSON.stringify([
                ...(Array.isArray(config.errorLogs) ? config.errorLogs : []),
                {
                  at: new Date().toISOString(),
                  message: result.message,
                },
              ]),
            ) as Prisma.InputJsonValue),
      },
    });

    await this.audit.log(
      actor.tenantId,
      actor.id,
      actor.role,
      AuditAction.EI_BILLING_CLEARINGHOUSE_TESTED,
      'EiClearinghouseConfig',
      configId,
      { success: result.success, message: result.message },
    );

    return { config: updated, result };
  }
}
