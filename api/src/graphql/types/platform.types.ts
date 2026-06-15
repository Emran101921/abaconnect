import {
  Field,
  Float,
  ID,
  Int,
  ObjectType,
  registerEnumType,
} from '@nestjs/graphql';
import { ClaimStatus, DocumentType } from '../../../generated/prisma/client';

registerEnumType(DocumentType, { name: 'DocumentType' });
registerEnumType(ClaimStatus, { name: 'ClaimStatus' });

@ObjectType()
export class TelehealthRoomType {
  @Field(() => ID)
  id: string;

  @Field()
  roomId: string;

  @Field({ nullable: true })
  joinUrl?: string;

  @Field({ nullable: true })
  startedAt?: Date;

  @Field({ nullable: true })
  appointmentLabel?: string;

  @Field({ nullable: true })
  vendor?: string;
}

@ObjectType()
export class DocumentItemType {
  @Field(() => ID)
  id: string;

  @Field()
  title: string;

  @Field()
  fileName: string;

  @Field(() => DocumentType)
  type: DocumentType;

  @Field(() => Int)
  fileSize: number;

  @Field(() => ID, { nullable: true })
  childId?: string;

  @Field()
  uploadedAt: Date;
}

@ObjectType()
export class NotificationType {
  @Field(() => ID)
  id: string;

  @Field()
  title: string;

  @Field()
  body: string;

  @Field({ nullable: true })
  readAt?: Date;

  @Field()
  sentAt: Date;

  @Field({ nullable: true })
  actionType?: string;

  @Field({ nullable: true })
  threadId?: string;

  @Field({ nullable: true })
  appointmentId?: string;

  @Field({ nullable: true })
  sessionId?: string;

  @Field({ nullable: true })
  marketplaceRequestId?: string;

  @Field({ nullable: true })
  paymentId?: string;
}

@ObjectType()
export class InsuranceClaimType {
  @Field(() => ID)
  id: string;

  @Field()
  payerName: string;

  @Field(() => ClaimStatus)
  status: ClaimStatus;

  @Field(() => Float)
  billedAmount: number;

  @Field({ nullable: true })
  childName?: string;

  @Field()
  serviceDate: Date;

  @Field({ nullable: true })
  sessionId?: string;

  @Field({ nullable: true })
  claimNumber?: string;

  @Field({ nullable: true })
  ediReady?: boolean;

  @Field({ nullable: true })
  clearinghouseStatus?: string;
}

@ObjectType()
export class HipaaConsentType {
  @Field(() => ID)
  id: string;

  @Field()
  consentType: string;

  @Field()
  version: string;

  @Field()
  granted: boolean;

  @Field()
  grantedAt: Date;
}

@ObjectType()
export class AnalyticsMetricType {
  @Field()
  metricKey: string;

  @Field(() => Float)
  metricValue: number;

  @Field(() => Float, { nullable: true })
  priorPeriodValue?: number;
}

@ObjectType()
export class SoapSuggestionType {
  @Field()
  subjective: string;

  @Field()
  objective: string;

  @Field()
  assessment: string;

  @Field()
  plan: string;
}

@ObjectType()
export class ComplaintType {
  @Field(() => ID)
  id: string;

  @Field()
  status: string;

  @Field()
  category: string;

  @Field()
  subject: string;

  @Field()
  description: string;

  @Field({ nullable: true })
  reporterName?: string;
}
