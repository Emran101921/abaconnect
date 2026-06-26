import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, TherapyType } from '../../generated/prisma/client';
import { AgenciesService } from '../agencies/agencies.service';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  AGENCY_PLATFORM_MODULE_KEYS,
  AGENCY_PLATFORM_MODULE_LABELS,
  BLOOMORA_COMPLIANCE_DISCLAIMER,
  DEFAULT_ENABLED_MODULES,
  INTEGRATION_CATALOG,
  PermissionScopeType,
} from './agency-platform.constants';
import { AgencyReferralStatus } from '../../generated/prisma/client';
import {
  hasInterventionistSignature,
  hasParentSignature,
  isEipFormFullySigned,
  isReadyForParentSignature,
} from '../sessions/eip-form.util';

@Injectable()
export class AgencyPlatformService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly agenciesService: AgenciesService,
    private readonly audit: AuditService,
  ) {}

  async resolveAgency(userId: string, tenantId: string) {
    return this.agenciesService.resolveAgencyForAdmin(userId, tenantId);
  }

  async assertModuleEnabled(
    userId: string,
    tenantId: string,
    moduleKey: string,
  ) {
    const agency = await this.resolveAgency(userId, tenantId);
    await this.ensureDefaultModules(agency.id, tenantId);
    const module = await this.prisma.agencyFeatureModule.findUnique({
      where: {
        agencyId_moduleKey: { agencyId: agency.id, moduleKey },
      },
    });
    if (module && !module.enabled) {
      throw new ForbiddenException(`Module "${moduleKey}" is disabled for this agency`);
    }
    return agency;
  }

  async getClientCoordinationSummary(
    userId: string,
    tenantId: string,
    childId: string,
  ) {
    const agency = await this.resolveAgency(userId, tenantId);
    const assignment =
      await this.prisma.childServiceCoordinatorAssignment.findFirst({
        where: {
          agencyId: agency.id,
          childId,
          status: 'ACTIVE',
        },
        include: {
          serviceCoordinator: true,
        },
      });

    const [notesCount, lastNote, screening] = await Promise.all([
      this.prisma.serviceCoordinationNote.count({
        where: { agencyId: agency.id, childId },
      }),
      this.prisma.serviceCoordinationNote.findFirst({
        where: { agencyId: agency.id, childId },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.eiInitialScreening.findFirst({
        where: { childId },
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    const coordinator = assignment?.serviceCoordinator;
    const coordinatorName = coordinator
      ? `${coordinator.firstName ?? ''} ${coordinator.lastName ?? ''}`.trim()
      : undefined;

    return {
      childId,
      assignmentId: assignment?.id,
      assignedCoordinatorName: coordinatorName || undefined,
      isUrgent: assignment?.isUrgent ?? false,
      coordinationNotesCount: notesCount,
      lastCoordinationNoteAt: lastNote?.createdAt,
      screeningRiskLevel: screening?.priorityLevel ?? undefined,
      evaluationRequested: screening?.followUpRequired ?? false,
    };
  }

  async listReferrals(userId: string, tenantId: string) {
    const agency = await this.resolveAgency(userId, tenantId);
    return this.prisma.agencyReferral.findMany({
      where: { agencyId: agency.id, tenantId },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }

  async upsertReferral(
    userId: string,
    tenantId: string,
    input: {
      id?: string;
      contactName?: string;
      contactPhone?: string;
      contactEmail?: string;
      childName?: string;
      sourceName?: string;
      sourceType?: string;
      status?: AgencyReferralStatus;
      notes?: string;
    },
  ) {
    const agency = await this.resolveAgency(userId, tenantId);
    const data = {
      contactName: input.contactName?.trim() || null,
      contactPhone: input.contactPhone?.trim() || null,
      contactEmail: input.contactEmail?.trim() || null,
      childName: input.childName?.trim() || null,
      sourceName: input.sourceName?.trim() || null,
      sourceType: input.sourceType?.trim() || null,
      status: input.status ?? AgencyReferralStatus.NEW,
      notes: input.notes?.trim() || null,
    };

    const referral = input.id
      ? await this.prisma.agencyReferral.update({
          where: { id: input.id, agencyId: agency.id, tenantId },
          data,
        })
      : await this.prisma.agencyReferral.create({
          data: { ...data, agencyId: agency.id, tenantId },
        });

    await this.audit.log({
      tenantId,
      actorId: userId,
      action: input.id ? 'UPDATE' : 'CREATE',
      resourceType: 'AgencyReferral',
      resourceId: referral.id,
      metadata: { agencyId: agency.id, status: referral.status },
    });

    return referral;
  }

  listIntegrationCatalog() {
    return INTEGRATION_CATALOG.map((item) => ({ ...item, enabled: false }));
  }

  async listProviderPayRates(
    userId: string,
    tenantId: string,
    therapistId?: string,
  ) {
    const agency = await this.resolveAgency(userId, tenantId);
    return this.prisma.providerPayRate.findMany({
      where: {
        agencyId: agency.id,
        tenantId,
        ...(therapistId ? { therapistId } : {}),
        active: true,
      },
      orderBy: { effectiveFrom: 'desc' },
    });
  }

  async upsertProviderPayRate(
    userId: string,
    tenantId: string,
    input: {
      id?: string;
      therapistId: string;
      serviceType?: TherapyType;
      rateCents: number;
      rateUnit?: string;
      effectiveFrom?: Date;
      active?: boolean;
    },
  ) {
    const agency = await this.resolveAgency(userId, tenantId);
    const link = await this.prisma.agencyTherapist.findFirst({
      where: {
        agencyId: agency.id,
        therapistId: input.therapistId,
      },
    });
    if (!link) {
      throw new NotFoundException('Provider not found in this agency');
    }
    if (input.rateCents < 0) {
      throw new BadRequestException('Rate must be zero or greater');
    }

    const data = {
      therapistId: input.therapistId,
      serviceType: input.serviceType ?? null,
      rateCents: input.rateCents,
      rateUnit: input.rateUnit?.trim() || 'hour',
      effectiveFrom: input.effectiveFrom ?? new Date(),
      active: input.active ?? true,
    };

    const rate = input.id
      ? await this.prisma.providerPayRate.update({
          where: { id: input.id, agencyId: agency.id, tenantId },
          data,
        })
      : await this.prisma.providerPayRate.create({
          data: { ...data, agencyId: agency.id, tenantId },
        });

    await this.audit.log({
      tenantId,
      actorId: userId,
      action: input.id ? 'UPDATE' : 'CREATE',
      resourceType: 'ProviderPayRate',
      resourceId: rate.id,
      metadata: { agencyId: agency.id, therapistId: input.therapistId },
    });

    return rate;
  }

  async convertReferralToClient(
    userId: string,
    tenantId: string,
    input: {
      referralId: string;
      dateOfBirth: Date;
      firstName?: string;
      lastName?: string;
    },
  ) {
    const agency = await this.resolveAgency(userId, tenantId);
    const referral = await this.prisma.agencyReferral.findFirst({
      where: { id: input.referralId, agencyId: agency.id, tenantId },
    });
    if (!referral) {
      throw new NotFoundException('Referral not found');
    }
    if (referral.convertedChildId) {
      throw new BadRequestException('Referral already converted to a client');
    }

    const fallbackName = (referral.childName ?? referral.contactName ?? 'New Child')
      .trim();
    const parts = fallbackName.split(/\s+/).filter(Boolean);
    const firstName = input.firstName?.trim() || parts[0] || 'New';
    const lastName =
      input.lastName?.trim() || parts.slice(1).join(' ') || 'Child';

    const child = await this.agenciesService.addCaseloadChild(
      agency.id,
      tenantId,
      userId,
      {
        firstName,
        lastName,
        dateOfBirth: input.dateOfBirth,
        guardianName: referral.contactName ?? undefined,
        guardianPhone: referral.contactPhone ?? undefined,
        guardianEmail: referral.contactEmail ?? undefined,
      },
    );

    const updated = await this.prisma.agencyReferral.update({
      where: { id: referral.id },
      data: {
        status: AgencyReferralStatus.CONVERTED_TO_CLIENT,
        convertedChildId: child.id,
        notes: referral.notes
          ? `${referral.notes}\nConverted to caseload client.`
          : 'Converted to caseload client.',
      },
    });

    await this.audit.log({
      tenantId,
      actorId: userId,
      action: 'UPDATE',
      resourceType: 'AgencyReferral',
      resourceId: referral.id,
      patientId: child.id,
      metadata: {
        agencyId: agency.id,
        status: updated.status,
        convertedChildId: child.id,
      },
    });

    return { referral: updated, childId: child.id };
  }

  async getOperationalAlerts(userId: string, tenantId: string) {
    const agency = await this.resolveAgency(userId, tenantId);
    const [openReferrals, sessions] = await Promise.all([
      this.prisma.agencyReferral.count({
        where: {
          agencyId: agency.id,
          tenantId,
          status: {
            notIn: [
              AgencyReferralStatus.CONVERTED_TO_CLIENT,
              AgencyReferralStatus.NOT_ELIGIBLE,
              AgencyReferralStatus.CLOSED,
            ],
          },
        },
      }),
      this.prisma.session.findMany({
        where: { tenantId, soapNote: { isNot: null } },
        include: { soapNote: true },
        orderBy: { updatedAt: 'desc' },
        take: 300,
      }),
    ]);

    let unsignedSessionNotes = 0;
    let awaitingParentSignatures = 0;
    for (const session of sessions) {
      const eip = session.soapNote?.eipFormData as Record<string, unknown> | null;
      if (!isEipFormFullySigned(eip)) {
        unsignedSessionNotes += 1;
      }
      if (
        hasInterventionistSignature(eip) &&
        isReadyForParentSignature(eip) &&
        !hasParentSignature(eip)
      ) {
        awaitingParentSignatures += 1;
      }
    }

    const alerts: Array<{
      key: string;
      label: string;
      count: number;
      routeHint?: string;
    }> = [];

    if (openReferrals > 0) {
      alerts.push({
        key: 'open_referrals',
        label: 'Open referrals in pipeline',
        count: openReferrals,
        routeHint: 'referrals',
      });
    }
    if (unsignedSessionNotes > 0) {
      alerts.push({
        key: 'unsigned_notes',
        label: 'Session notes awaiting completion',
        count: unsignedSessionNotes,
        routeHint: 'session-notes',
      });
    }
    if (awaitingParentSignatures > 0) {
      alerts.push({
        key: 'parent_signatures',
        label: 'Notes awaiting parent/caregiver signature',
        count: awaitingParentSignatures,
        routeHint: 'session-notes',
      });
    }

    return alerts;
  }

  async getPlatformOverview(userId: string, tenantId: string) {
    const agency = await this.resolveAgency(userId, tenantId);
    await this.ensureDefaultModules(agency.id, tenantId);
    const [branches, departments, programs, modules, settings, grants] =
      await Promise.all([
        this.prisma.agencyBranch.findMany({
          where: { agencyId: agency.id, tenantId },
          orderBy: { name: 'asc' },
        }),
        this.prisma.agencyDepartment.findMany({
          where: { agencyId: agency.id, tenantId },
          orderBy: { name: 'asc' },
        }),
        this.prisma.agencyProgram.findMany({
          where: { agencyId: agency.id, tenantId },
          orderBy: { name: 'asc' },
        }),
        this.prisma.agencyFeatureModule.findMany({
          where: { agencyId: agency.id, tenantId },
          orderBy: { moduleKey: 'asc' },
        }),
        this.getOrCreatePlatformSettings(agency.id, tenantId),
        this.prisma.agencyPermissionGrant.findMany({
          where: { agencyId: agency.id, tenantId },
          orderBy: { createdAt: 'desc' },
        }),
      ]);

    return {
      agencyId: agency.id,
      complianceDisclaimer: BLOOMORA_COMPLIANCE_DISCLAIMER,
      branches,
      departments,
      programs,
      modules: this.mergeModuleCatalog(modules),
      settings: settings.settings as Record<string, unknown>,
      permissionGrants: grants,
    };
  }

  async listBranches(userId: string, tenantId: string) {
    const agency = await this.resolveAgency(userId, tenantId);
    return this.prisma.agencyBranch.findMany({
      where: { agencyId: agency.id, tenantId },
      orderBy: { name: 'asc' },
    });
  }

  async upsertBranch(
    userId: string,
    tenantId: string,
    input: {
      id?: string;
      name: string;
      region?: string;
      addressLine1?: string;
      addressLine2?: string;
      city?: string;
      state?: string;
      zipCode?: string;
      phone?: string;
      email?: string;
      active?: boolean;
    },
  ) {
    const agency = await this.resolveAgency(userId, tenantId);
    const data = {
      name: input.name.trim(),
      region: input.region?.trim() || null,
      addressLine1: input.addressLine1?.trim() || null,
      addressLine2: input.addressLine2?.trim() || null,
      city: input.city?.trim() || null,
      state: input.state?.trim() || null,
      zipCode: input.zipCode?.trim() || null,
      phone: input.phone?.trim() || null,
      email: input.email?.trim() || null,
      active: input.active ?? true,
    };
    if (!data.name) {
      throw new BadRequestException('Branch name is required');
    }

    const branch = input.id
      ? await this.prisma.agencyBranch.update({
          where: { id: input.id, agencyId: agency.id, tenantId },
          data,
        })
      : await this.prisma.agencyBranch.create({
          data: { ...data, agencyId: agency.id, tenantId },
        });

    await this.audit.log({
      tenantId,
      actorId: userId,
      action: input.id ? 'UPDATE' : 'CREATE',
      resourceType: 'AgencyBranch',
      resourceId: branch.id,
      metadata: { agencyId: agency.id, name: branch.name },
    });

    return branch;
  }

  async upsertDepartment(
    userId: string,
    tenantId: string,
    input: {
      id?: string;
      branchId?: string;
      name: string;
      code?: string;
      active?: boolean;
    },
  ) {
    const agency = await this.resolveAgency(userId, tenantId);
    const name = input.name.trim();
    if (!name) {
      throw new BadRequestException('Department name is required');
    }
    if (input.branchId) {
      const branch = await this.prisma.agencyBranch.findFirst({
        where: { id: input.branchId, agencyId: agency.id, tenantId },
      });
      if (!branch) {
        throw new NotFoundException('Branch not found');
      }
    }

    const data = {
      name,
      branchId: input.branchId ?? null,
      code: input.code?.trim() || null,
      active: input.active ?? true,
    };

    const department = input.id
      ? await this.prisma.agencyDepartment.update({
          where: { id: input.id, agencyId: agency.id, tenantId },
          data,
        })
      : await this.prisma.agencyDepartment.create({
          data: { ...data, agencyId: agency.id, tenantId },
        });

    await this.audit.log({
      tenantId,
      actorId: userId,
      action: input.id ? 'UPDATE' : 'CREATE',
      resourceType: 'AgencyDepartment',
      resourceId: department.id,
      metadata: { agencyId: agency.id, name: department.name },
    });

    return department;
  }

  async upsertProgram(
    userId: string,
    tenantId: string,
    input: {
      id?: string;
      name: string;
      code?: string;
      serviceType?: TherapyType;
      description?: string;
      region?: string;
      active?: boolean;
      settings?: Record<string, unknown>;
    },
  ) {
    const agency = await this.resolveAgency(userId, tenantId);
    const name = input.name.trim();
    if (!name) {
      throw new BadRequestException('Program name is required');
    }

    const data = {
      name,
      code: input.code?.trim() || null,
      serviceType: input.serviceType ?? null,
      description: input.description?.trim() || null,
      region: input.region?.trim() || null,
      active: input.active ?? true,
      settings: (input.settings ?? {}) as Prisma.InputJsonValue,
    };

    const program = input.id
      ? await this.prisma.agencyProgram.update({
          where: { id: input.id, agencyId: agency.id, tenantId },
          data,
        })
      : await this.prisma.agencyProgram.create({
          data: { ...data, agencyId: agency.id, tenantId },
        });

    await this.audit.log({
      tenantId,
      actorId: userId,
      action: input.id ? 'UPDATE' : 'CREATE',
      resourceType: 'AgencyProgram',
      resourceId: program.id,
      metadata: { agencyId: agency.id, name: program.name },
    });

    return program;
  }

  async updateFeatureModule(
    userId: string,
    tenantId: string,
    moduleKey: string,
    enabled: boolean,
    settings?: Record<string, unknown>,
  ) {
    const agency = await this.resolveAgency(userId, tenantId);
    if (
      !AGENCY_PLATFORM_MODULE_KEYS.includes(
        moduleKey as (typeof AGENCY_PLATFORM_MODULE_KEYS)[number],
      )
    ) {
      throw new BadRequestException('Unknown module key');
    }

    await this.ensureDefaultModules(agency.id, tenantId);
    const module = await this.prisma.agencyFeatureModule.update({
      where: {
        agencyId_moduleKey: { agencyId: agency.id, moduleKey },
      },
      data: {
        enabled,
        settings: (settings ?? {}) as Prisma.InputJsonValue,
      },
    });

    await this.audit.log({
      tenantId,
      actorId: userId,
      action: 'UPDATE',
      resourceType: 'AgencyFeatureModule',
      resourceId: module.id,
      metadata: { agencyId: agency.id, moduleKey, enabled },
    });

    return module;
  }

  async updatePlatformSettings(
    userId: string,
    tenantId: string,
    patch: Record<string, unknown>,
  ) {
    const agency = await this.resolveAgency(userId, tenantId);
    const current = await this.getOrCreatePlatformSettings(agency.id, tenantId);
    const merged = {
      ...(current.settings as Record<string, unknown>),
      ...patch,
    };
    const updated = await this.prisma.agencyPlatformSetting.update({
      where: { agencyId: agency.id },
      data: { settings: merged as Prisma.InputJsonValue },
    });

    await this.audit.log({
      tenantId,
      actorId: userId,
      action: 'UPDATE',
      resourceType: 'AgencyPlatformSetting',
      resourceId: updated.id,
      metadata: { agencyId: agency.id, keys: Object.keys(patch) },
    });

    return updated;
  }

  async upsertPermissionGrant(
    userId: string,
    tenantId: string,
    input: {
      id?: string;
      scopeType: PermissionScopeType;
      scopeId?: string;
      permission: string;
      granted?: boolean;
    },
  ) {
    const agency = await this.resolveAgency(userId, tenantId);
    const permission = input.permission.trim();
    if (!permission) {
      throw new BadRequestException('Permission is required');
    }

    const data = {
      scopeType: input.scopeType,
      scopeId: input.scopeId ?? null,
      permission,
      granted: input.granted ?? true,
    };

    const grant = input.id
      ? await this.prisma.agencyPermissionGrant.update({
          where: { id: input.id, agencyId: agency.id, tenantId },
          data,
        })
      : await this.prisma.agencyPermissionGrant.create({
          data: { ...data, agencyId: agency.id, tenantId },
        });

    await this.audit.log({
      tenantId,
      actorId: userId,
      action: 'PERMISSION_CHANGED',
      resourceType: 'AgencyPermissionGrant',
      resourceId: grant.id,
      metadata: {
        agencyId: agency.id,
        scopeType: grant.scopeType,
        permission: grant.permission,
        granted: grant.granted,
      },
    });

    return grant;
  }

  async listAuditLogs(
    userId: string,
    tenantId: string,
    take = 100,
    patientId?: string,
  ) {
    await this.resolveAgency(userId, tenantId);
    return this.audit.searchForTenant(tenantId, {
      patientId,
      take,
    });
  }

  private async getOrCreatePlatformSettings(agencyId: string, tenantId: string) {
    const existing = await this.prisma.agencyPlatformSetting.findUnique({
      where: { agencyId },
    });
    if (existing) {
      return existing;
    }
    return this.prisma.agencyPlatformSetting.create({
      data: {
        agencyId,
        tenantId,
        settings: {
          customFields: [],
          serviceTypes: [],
          payerTypes: [],
          billingRules: {},
          payrollRules: {},
          documentationTemplates: [],
          authorizationRules: {},
          attendanceRules: {},
          notificationSettings: {},
          complianceDeadlines: [],
          credentialRequirements: [],
        },
      },
    });
  }

  private async ensureDefaultModules(agencyId: string, tenantId: string) {
    const existing = await this.prisma.agencyFeatureModule.findMany({
      where: { agencyId },
      select: { moduleKey: true },
    });
    const existingKeys = new Set(existing.map((m) => m.moduleKey));
    const missing = AGENCY_PLATFORM_MODULE_KEYS.filter(
      (key) => !existingKeys.has(key),
    );
    if (missing.length === 0) {
      return;
    }
    await this.prisma.agencyFeatureModule.createMany({
      data: missing.map((moduleKey) => ({
        agencyId,
        tenantId,
        moduleKey,
        enabled: DEFAULT_ENABLED_MODULES[moduleKey],
      })),
      skipDuplicates: true,
    });
  }

  private mergeModuleCatalog(
    rows: Array<{
      id: string;
      moduleKey: string;
      enabled: boolean;
      settings: Prisma.JsonValue;
    }>,
  ) {
    const byKey = new Map(rows.map((row) => [row.moduleKey, row]));
    return AGENCY_PLATFORM_MODULE_KEYS.map((moduleKey) => {
      const row = byKey.get(moduleKey);
      return {
        id: row?.id ?? moduleKey,
        moduleKey,
        label: AGENCY_PLATFORM_MODULE_LABELS[moduleKey],
        enabled: row?.enabled ?? DEFAULT_ENABLED_MODULES[moduleKey],
        settings: (row?.settings ?? {}) as Record<string, unknown>,
      };
    });
  }
}
