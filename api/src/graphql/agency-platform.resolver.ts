import { Args, ID, Int, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { AgencyPlatformService } from '../agency-platform/agency-platform.service';
import {
  UpsertAgencyBranchInput,
  UpsertAgencyDepartmentInput,
  UpsertAgencyProgramInput,
  UpdateAgencyFeatureModuleInput,
  UpdateAgencyPlatformSettingsInput,
  UpsertAgencyPermissionGrantInput,
  UpsertAgencyReferralInput,
  UpsertProviderPayRateInput,
  ConvertAgencyReferralInput,
  AgencyPayrollRunInput,
} from './inputs/agency-platform.inputs';
import {
  AgencyAuditLogType,
  AgencyBranchType,
  AgencyClientCoordinationSummaryType,
  AgencyDepartmentType,
  AgencyFeatureModuleType,
  AgencyIntegrationCatalogItemType,
  AgencyOperationalAlertType,
  AgencyPermissionGrantType,
  AgencyPlatformOverviewType,
  AgencyProgramType,
  AgencyReferralType,
  ConvertAgencyReferralResultType,
  ProviderPayRateType,
  AgencyPayrollRunPreviewType,
} from './types/agency-platform.types';
import { AgencyReferralStatus } from '../../generated/prisma/client';

function mapBranch(row: {
  id: string;
  name: string;
  region: string | null;
  addressLine1: string | null;
  addressLine2: string | null;
  city: string | null;
  state: string | null;
  zipCode: string | null;
  phone: string | null;
  email: string | null;
  active: boolean;
}): AgencyBranchType {
  return {
    id: row.id,
    name: row.name,
    region: row.region ?? undefined,
    addressLine1: row.addressLine1 ?? undefined,
    addressLine2: row.addressLine2 ?? undefined,
    city: row.city ?? undefined,
    state: row.state ?? undefined,
    zipCode: row.zipCode ?? undefined,
    phone: row.phone ?? undefined,
    email: row.email ?? undefined,
    active: row.active,
  };
}

function mapDepartment(row: {
  id: string;
  branchId: string | null;
  name: string;
  code: string | null;
  active: boolean;
}): AgencyDepartmentType {
  return {
    id: row.id,
    branchId: row.branchId ?? undefined,
    name: row.name,
    code: row.code ?? undefined,
    active: row.active,
  };
}

function mapProgram(row: {
  id: string;
  name: string;
  code: string | null;
  serviceType: string | null;
  description: string | null;
  region: string | null;
  active: boolean;
  settings: unknown;
}): AgencyProgramType {
  return {
    id: row.id,
    name: row.name,
    code: row.code ?? undefined,
    serviceType: (row.serviceType ??
      undefined) as AgencyProgramType['serviceType'],
    description: row.description ?? undefined,
    region: row.region ?? undefined,
    active: row.active,
    settingsJson: JSON.stringify(row.settings ?? {}),
  };
}

function mapModule(row: {
  id: string;
  moduleKey: string;
  label: string;
  enabled: boolean;
  settings: Record<string, unknown>;
}): AgencyFeatureModuleType {
  return {
    id: row.id,
    moduleKey: row.moduleKey,
    label: row.label,
    enabled: row.enabled,
    settingsJson: JSON.stringify(row.settings ?? {}),
  };
}

function mapOverview(
  overview: Awaited<ReturnType<AgencyPlatformService['getPlatformOverview']>>,
): AgencyPlatformOverviewType {
  return {
    agencyId: overview.agencyId,
    complianceDisclaimer: overview.complianceDisclaimer,
    branches: overview.branches.map(mapBranch),
    departments: overview.departments.map(mapDepartment),
    programs: overview.programs.map(mapProgram),
    modules: overview.modules.map(mapModule),
    settingsJson: JSON.stringify(overview.settings ?? {}),
    permissionGrants: overview.permissionGrants.map((grant) => ({
      id: grant.id,
      scopeType: grant.scopeType,
      scopeId: grant.scopeId ?? undefined,
      permission: grant.permission,
      granted: grant.granted,
    })),
  };
}

function mapReferral(row: {
  id: string;
  contactName: string | null;
  contactPhone: string | null;
  contactEmail: string | null;
  childName: string | null;
  sourceName: string | null;
  sourceType: string | null;
  status: string;
  notes: string | null;
  convertedChildId: string | null;
  createdAt: Date;
}): AgencyReferralType {
  return {
    id: row.id,
    contactName: row.contactName ?? undefined,
    contactPhone: row.contactPhone ?? undefined,
    contactEmail: row.contactEmail ?? undefined,
    childName: row.childName ?? undefined,
    sourceName: row.sourceName ?? undefined,
    sourceType: row.sourceType ?? undefined,
    status: row.status,
    notes: row.notes ?? undefined,
    convertedChildId: row.convertedChildId ?? undefined,
    createdAt: row.createdAt,
  };
}

@Resolver()
@Roles('AGENCY_ADMIN', 'PLATFORM_ADMIN', 'DEPARTMENT_ADMIN')
export class AgencyPlatformResolver {
  constructor(private readonly platform: AgencyPlatformService) {}

  @Query(() => AgencyPlatformOverviewType, { name: 'agencyPlatformOverview' })
  async agencyPlatformOverview(
    @CurrentUser() user: AuthUser,
  ): Promise<AgencyPlatformOverviewType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const overview = await this.platform.getPlatformOverview(
      user.id,
      user.tenantId,
    );
    return mapOverview(overview);
  }

  @Query(() => [AgencyAuditLogType], { name: 'agencyAuditLogs' })
  async agencyAuditLogs(
    @CurrentUser() user: AuthUser,
    @Args('take', { type: () => Int, nullable: true }) take?: number,
    @Args('patientId', { type: () => ID, nullable: true }) patientId?: string,
  ): Promise<AgencyAuditLogType[]> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const rows = await this.platform.listAuditLogs(
      user.id,
      user.tenantId,
      take ?? 100,
      patientId,
    );
    return rows.map((row) => ({
      id: row.id,
      action: row.action,
      entityType: row.entityType,
      entityId: row.entityId ?? undefined,
      patientId: row.patientId ?? undefined,
      actorRole: row.actorRole ?? undefined,
      createdAt: row.createdAt,
    }));
  }

  @Mutation(() => AgencyBranchType, { name: 'upsertAgencyBranch' })
  async upsertAgencyBranch(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpsertAgencyBranchInput,
  ): Promise<AgencyBranchType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const branch = await this.platform.upsertBranch(
      user.id,
      user.tenantId,
      input,
    );
    return mapBranch(branch);
  }

  @Mutation(() => AgencyDepartmentType, { name: 'upsertAgencyDepartment' })
  async upsertAgencyDepartment(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpsertAgencyDepartmentInput,
  ): Promise<AgencyDepartmentType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const department = await this.platform.upsertDepartment(
      user.id,
      user.tenantId,
      input,
    );
    return mapDepartment(department);
  }

  @Mutation(() => AgencyProgramType, { name: 'upsertAgencyProgram' })
  async upsertAgencyProgram(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpsertAgencyProgramInput,
  ): Promise<AgencyProgramType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const program = await this.platform.upsertProgram(user.id, user.tenantId, {
      ...input,
      settings: input.settingsJson
        ? (JSON.parse(input.settingsJson) as Record<string, unknown>)
        : undefined,
    });
    return mapProgram(program);
  }

  @Mutation(() => AgencyFeatureModuleType, {
    name: 'updateAgencyFeatureModule',
  })
  async updateAgencyFeatureModule(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpdateAgencyFeatureModuleInput,
  ): Promise<AgencyFeatureModuleType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const module = await this.platform.updateFeatureModule(
      user.id,
      user.tenantId,
      input.moduleKey,
      input.enabled,
      input.settingsJson
        ? (JSON.parse(input.settingsJson) as Record<string, unknown>)
        : undefined,
    );
    return {
      id: module.id,
      moduleKey: module.moduleKey,
      label: module.moduleKey,
      enabled: module.enabled,
      settingsJson: JSON.stringify(module.settings ?? {}),
    };
  }

  @Mutation(() => AgencyPlatformOverviewType, {
    name: 'updateAgencyPlatformSettings',
  })
  async updateAgencyPlatformSettings(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpdateAgencyPlatformSettingsInput,
  ): Promise<AgencyPlatformOverviewType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const patch = JSON.parse(input.settingsJson) as Record<string, unknown>;
    await this.platform.updatePlatformSettings(user.id, user.tenantId, patch);
    const overview = await this.platform.getPlatformOverview(
      user.id,
      user.tenantId,
    );
    return mapOverview(overview);
  }

  @Mutation(() => AgencyPermissionGrantType, {
    name: 'upsertAgencyPermissionGrant',
  })
  async upsertAgencyPermissionGrant(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpsertAgencyPermissionGrantInput,
  ): Promise<AgencyPermissionGrantType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const grant = await this.platform.upsertPermissionGrant(
      user.id,
      user.tenantId,
      {
        ...input,
        scopeType: input.scopeType as
          | 'ROLE'
          | 'DEPARTMENT'
          | 'PROGRAM'
          | 'USER',
      },
    );
    return {
      id: grant.id,
      scopeType: grant.scopeType,
      scopeId: grant.scopeId ?? undefined,
      permission: grant.permission,
      granted: grant.granted,
    };
  }

  @Query(() => AgencyClientCoordinationSummaryType, {
    name: 'agencyClientCoordinationSummary',
  })
  async agencyClientCoordinationSummary(
    @CurrentUser() user: AuthUser,
    @Args('childId', { type: () => ID }) childId: string,
  ): Promise<AgencyClientCoordinationSummaryType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    await this.platform.assertModuleEnabled(
      user.id,
      user.tenantId,
      'service_coordination',
    );
    return this.platform.getClientCoordinationSummary(
      user.id,
      user.tenantId,
      childId,
    );
  }

  @Query(() => [AgencyReferralType], { name: 'agencyReferrals' })
  async agencyReferrals(
    @CurrentUser() user: AuthUser,
  ): Promise<AgencyReferralType[]> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    await this.platform.assertModuleEnabled(
      user.id,
      user.tenantId,
      'referrals',
    );
    const rows = await this.platform.listReferrals(user.id, user.tenantId);
    return rows.map((row) => mapReferral(row));
  }

  @Mutation(() => AgencyReferralType, { name: 'upsertAgencyReferral' })
  async upsertAgencyReferral(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpsertAgencyReferralInput,
  ): Promise<AgencyReferralType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    await this.platform.assertModuleEnabled(
      user.id,
      user.tenantId,
      'referrals',
    );
    const row = await this.platform.upsertReferral(user.id, user.tenantId, {
      ...input,
      status: input.status as AgencyReferralStatus | undefined,
    });
    return mapReferral(row);
  }

  @Mutation(() => ConvertAgencyReferralResultType, {
    name: 'convertAgencyReferralToClient',
  })
  async convertAgencyReferralToClient(
    @CurrentUser() user: AuthUser,
    @Args('input') input: ConvertAgencyReferralInput,
  ): Promise<ConvertAgencyReferralResultType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    await this.platform.assertModuleEnabled(
      user.id,
      user.tenantId,
      'referrals',
    );
    const result = await this.platform.convertReferralToClient(
      user.id,
      user.tenantId,
      input,
    );
    return {
      referralId: result.referral.id,
      childId: result.childId,
      status: result.referral.status,
    };
  }

  @Query(() => [AgencyIntegrationCatalogItemType], {
    name: 'agencyIntegrationCatalog',
  })
  async agencyIntegrationCatalog(
    @CurrentUser() user: AuthUser,
  ): Promise<AgencyIntegrationCatalogItemType[]> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    await this.platform.assertModuleEnabled(
      user.id,
      user.tenantId,
      'integrations',
    );
    return this.platform.listIntegrationCatalog();
  }

  @Query(() => [ProviderPayRateType], { name: 'agencyProviderPayRates' })
  async agencyProviderPayRates(
    @CurrentUser() user: AuthUser,
    @Args('therapistId', { type: () => ID, nullable: true })
    therapistId?: string,
  ): Promise<ProviderPayRateType[]> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    await this.platform.assertModuleEnabled(user.id, user.tenantId, 'payroll');
    const rows = await this.platform.listProviderPayRates(
      user.id,
      user.tenantId,
      therapistId,
    );
    return rows.map((row) => ({
      id: row.id,
      therapistId: row.therapistId,
      serviceType: row.serviceType ?? undefined,
      rateCents: row.rateCents,
      rateUnit: row.rateUnit,
      effectiveFrom: row.effectiveFrom,
    }));
  }

  @Mutation(() => ProviderPayRateType, { name: 'upsertAgencyProviderPayRate' })
  async upsertAgencyProviderPayRate(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpsertProviderPayRateInput,
  ): Promise<ProviderPayRateType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    await this.platform.assertModuleEnabled(user.id, user.tenantId, 'payroll');
    const row = await this.platform.upsertProviderPayRate(
      user.id,
      user.tenantId,
      input,
    );
    return {
      id: row.id,
      therapistId: row.therapistId,
      serviceType: row.serviceType ?? undefined,
      rateCents: row.rateCents,
      rateUnit: row.rateUnit,
      effectiveFrom: row.effectiveFrom,
    };
  }

  @Query(() => [AgencyOperationalAlertType], {
    name: 'agencyOperationalAlerts',
  })
  async agencyOperationalAlerts(
    @CurrentUser() user: AuthUser,
  ): Promise<AgencyOperationalAlertType[]> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    return this.platform.getOperationalAlerts(user.id, user.tenantId);
  }

  @Query(() => AgencyPayrollRunPreviewType, { name: 'agencyPayrollRunPreview' })
  async agencyPayrollRunPreview(
    @CurrentUser() user: AuthUser,
    @Args('input') input: AgencyPayrollRunInput,
  ): Promise<AgencyPayrollRunPreviewType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    return this.platform.getPayrollRunPreview(user.id, user.tenantId, {
      from: input.from,
      to: input.to,
    });
  }
}
