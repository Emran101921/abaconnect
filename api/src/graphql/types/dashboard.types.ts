import {
  Field,
  Float,
  ID,
  Int,
  ObjectType,
  registerEnumType,
} from '@nestjs/graphql';

export enum AnalyticsClaimPipelineFilter {
  DRAFT = 'DRAFT',
  SUBMITTED = 'SUBMITTED',
  PENDING = 'PENDING',
  PAID = 'PAID',
  DENIED = 'DENIED',
}

registerEnumType(AnalyticsClaimPipelineFilter, {
  name: 'AnalyticsClaimPipelineFilter',
});

@ObjectType()
export class ClaimsPipelineAnalyticsType {
  @Field(() => Int)
  draftCount: number;

  @Field(() => Int)
  submittedCount: number;

  @Field(() => Int)
  pendingCount: number;

  @Field(() => Int)
  paidCount: number;

  @Field(() => Int)
  deniedCount: number;

  @Field(() => Int)
  priorDraftCount: number;

  @Field(() => Int)
  priorSubmittedCount: number;

  @Field(() => Int)
  priorPendingCount: number;

  @Field(() => Int)
  priorPaidCount: number;

  @Field(() => Int)
  priorDeniedCount: number;

  @Field(() => Float)
  paidAmountTotal: number;

  @Field(() => Float)
  priorPaidAmountTotal: number;
}

@ObjectType()
export class AnalyticsClaimSummaryType {
  @Field(() => ID)
  id: string;

  @Field()
  status: string;

  @Field()
  payerName: string;

  @Field(() => Float)
  billedAmount: number;

  @Field()
  serviceDate: Date;

  @Field({ nullable: true })
  childName?: string;

  @Field({ nullable: true })
  claimNumber?: string;
}

@ObjectType()
export class ClaimsPipelineDashboardType {
  @Field(() => ClaimsPipelineAnalyticsType)
  summary: ClaimsPipelineAnalyticsType;

  @Field(() => [AnalyticsClaimSummaryType])
  recentClaims: AnalyticsClaimSummaryType[];
}

@ObjectType()
export class ScreeningFunnelAnalyticsType {
  @Field(() => Int)
  completedCount: number;

  @Field(() => Int)
  lowRiskCount: number;

  @Field(() => Int)
  moderateRiskCount: number;

  @Field(() => Int)
  highRiskCount: number;

  @Field(() => Int)
  priorCompletedCount: number;

  @Field(() => Int)
  priorLowRiskCount: number;

  @Field(() => Int)
  priorModerateRiskCount: number;

  @Field(() => Int)
  priorHighRiskCount: number;
}

@ObjectType()
export class AnalyticsScreeningSummaryType {
  @Field(() => ID)
  id: string;

  @Field()
  completedAt: Date;

  @Field({ nullable: true })
  childName?: string;

  @Field({ nullable: true })
  templateName?: string;

  @Field(() => Float, { nullable: true })
  score?: number;

  @Field({ nullable: true })
  riskLevel?: string;

  @Field({ nullable: true })
  recommendationsJson?: string;
}

@ObjectType()
export class ScreeningFunnelDashboardType {
  @Field(() => ScreeningFunnelAnalyticsType)
  summary: ScreeningFunnelAnalyticsType;

  @Field(() => [AnalyticsScreeningSummaryType])
  recentScreenings: AnalyticsScreeningSummaryType[];
}

@ObjectType()
export class AnalyticsScreeningDetailType {
  @Field(() => ID)
  id: string;

  @Field()
  completedAt: Date;

  @Field({ nullable: true })
  childName?: string;

  @Field({ nullable: true })
  templateName?: string;

  @Field(() => Float, { nullable: true })
  score?: number;

  @Field({ nullable: true })
  riskLevel?: string;

  @Field({ nullable: true })
  responsesJson?: string;

  @Field({ nullable: true })
  recommendationsJson?: string;

  @Field({ nullable: true })
  consentGrantedAt?: Date;
}

@ObjectType()
export class DashboardActionItemType {
  @Field()
  id: string;

  @Field()
  title: string;

  @Field({ nullable: true })
  subtitle?: string;

  @Field()
  actionType: string;

  @Field(() => Int, { nullable: true })
  priority?: number;

  @Field({ nullable: true })
  threadId?: string;

  @Field({ nullable: true })
  appointmentId?: string;

  @Field({ nullable: true })
  sessionId?: string;

  @Field({ nullable: true })
  claimId?: string;
}
