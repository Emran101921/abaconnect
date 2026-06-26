import { Field, ID, Int, ObjectType } from '@nestjs/graphql';
import { TherapyType } from '../../../generated/prisma/client';

@ObjectType()
export class AgencyBranchType {
  @Field(() => ID)
  id!: string;

  @Field()
  name!: string;

  @Field({ nullable: true })
  region?: string;

  @Field({ nullable: true })
  addressLine1?: string;

  @Field({ nullable: true })
  addressLine2?: string;

  @Field({ nullable: true })
  city?: string;

  @Field({ nullable: true })
  state?: string;

  @Field({ nullable: true })
  zipCode?: string;

  @Field({ nullable: true })
  phone?: string;

  @Field({ nullable: true })
  email?: string;

  @Field()
  active!: boolean;
}

@ObjectType()
export class AgencyDepartmentType {
  @Field(() => ID)
  id!: string;

  @Field({ nullable: true })
  branchId?: string;

  @Field()
  name!: string;

  @Field({ nullable: true })
  code?: string;

  @Field()
  active!: boolean;
}

@ObjectType()
export class AgencyProgramType {
  @Field(() => ID)
  id!: string;

  @Field()
  name!: string;

  @Field({ nullable: true })
  code?: string;

  @Field(() => TherapyType, { nullable: true })
  serviceType?: TherapyType;

  @Field({ nullable: true })
  description?: string;

  @Field({ nullable: true })
  region?: string;

  @Field()
  active!: boolean;

  @Field()
  settingsJson!: string;
}

@ObjectType()
export class AgencyFeatureModuleType {
  @Field(() => ID)
  id!: string;

  @Field()
  moduleKey!: string;

  @Field()
  label!: string;

  @Field()
  enabled!: boolean;

  @Field()
  settingsJson!: string;
}

@ObjectType()
export class AgencyPermissionGrantType {
  @Field(() => ID)
  id!: string;

  @Field()
  scopeType!: string;

  @Field({ nullable: true })
  scopeId?: string;

  @Field()
  permission!: string;

  @Field()
  granted!: boolean;
}

@ObjectType()
export class AgencyPlatformOverviewType {
  @Field(() => ID)
  agencyId!: string;

  @Field()
  complianceDisclaimer!: string;

  @Field(() => [AgencyBranchType])
  branches!: AgencyBranchType[];

  @Field(() => [AgencyDepartmentType])
  departments!: AgencyDepartmentType[];

  @Field(() => [AgencyProgramType])
  programs!: AgencyProgramType[];

  @Field(() => [AgencyFeatureModuleType])
  modules!: AgencyFeatureModuleType[];

  @Field()
  settingsJson!: string;

  @Field(() => [AgencyPermissionGrantType])
  permissionGrants!: AgencyPermissionGrantType[];
}

@ObjectType()
export class AgencyClientCoordinationSummaryType {
  @Field(() => ID)
  childId!: string;

  @Field({ nullable: true })
  assignmentId?: string;

  @Field({ nullable: true })
  assignedCoordinatorName?: string;

  @Field()
  isUrgent!: boolean;

  @Field()
  coordinationNotesCount!: number;

  @Field({ nullable: true })
  lastCoordinationNoteAt?: Date;

  @Field({ nullable: true })
  screeningRiskLevel?: string;

  @Field()
  evaluationRequested!: boolean;
}

@ObjectType()
export class AgencyReferralType {
  @Field(() => ID)
  id!: string;

  @Field({ nullable: true })
  contactName?: string;

  @Field({ nullable: true })
  contactPhone?: string;

  @Field({ nullable: true })
  contactEmail?: string;

  @Field({ nullable: true })
  childName?: string;

  @Field({ nullable: true })
  sourceName?: string;

  @Field({ nullable: true })
  sourceType?: string;

  @Field()
  status!: string;

  @Field({ nullable: true })
  notes?: string;

  @Field({ nullable: true })
  convertedChildId?: string;

  @Field()
  createdAt!: Date;
}

@ObjectType()
export class AgencyOperationalAlertType {
  @Field()
  key!: string;

  @Field()
  label!: string;

  @Field()
  count!: number;

  @Field({ nullable: true })
  routeHint?: string;
}

@ObjectType()
export class ConvertAgencyReferralResultType {
  @Field(() => ID)
  referralId!: string;

  @Field(() => ID)
  childId!: string;

  @Field()
  status!: string;
}

@ObjectType()
export class AgencyIntegrationCatalogItemType {
  @Field()
  key!: string;

  @Field()
  label!: string;

  @Field()
  category!: string;

  @Field()
  description!: string;

  @Field()
  enabled!: boolean;
}

@ObjectType()
export class ProviderPayRateType {
  @Field(() => ID)
  id!: string;

  @Field(() => ID)
  therapistId!: string;

  @Field(() => TherapyType, { nullable: true })
  serviceType?: TherapyType;

  @Field()
  rateCents!: number;

  @Field()
  rateUnit!: string;

  @Field()
  effectiveFrom!: Date;
}

@ObjectType()
export class AgencyAuditLogType {
  @Field(() => ID)
  id!: string;

  @Field()
  action!: string;

  @Field()
  entityType!: string;

  @Field({ nullable: true })
  entityId?: string;

  @Field({ nullable: true })
  patientId?: string;

  @Field({ nullable: true })
  actorRole?: string;

  @Field()
  createdAt!: Date;
}

@ObjectType()
export class AgencyPayrollRunLineType {
  @Field(() => ID)
  therapistId!: string;

  @Field()
  therapistName!: string;

  @Field(() => Int)
  sessionCount!: number;

  @Field()
  hours!: number;

  @Field()
  rateDisplay!: string;

  @Field(() => Int)
  estimatedPayCents!: number;
}

@ObjectType()
export class AgencyPayrollRunPreviewType {
  @Field()
  fromDate!: Date;

  @Field()
  toDate!: Date;

  @Field(() => [AgencyPayrollRunLineType])
  lines!: AgencyPayrollRunLineType[];

  @Field(() => Int)
  totalEstimatedPayCents!: number;
}
