import {
  Field,
  ID,
  InputType,
  Int,
  ObjectType,
  registerEnumType,
} from '@nestjs/graphql';
import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

export enum GqlCallType {
  AUDIO = 'AUDIO',
  VIDEO = 'VIDEO',
}

export enum GqlCallSessionStatus {
  INITIATED = 'INITIATED',
  RINGING = 'RINGING',
  ACCEPTED = 'ACCEPTED',
  IN_PROGRESS = 'IN_PROGRESS',
  DECLINED = 'DECLINED',
  MISSED = 'MISSED',
  FAILED = 'FAILED',
  ENDED = 'ENDED',
  CANCELLED = 'CANCELLED',
}

registerEnumType(GqlCallType, { name: 'CallType' });
registerEnumType(GqlCallSessionStatus, { name: 'CallSessionStatus' });

@ObjectType()
export class CallParticipantType {
  @Field(() => ID)
  userId: string;

  @Field()
  displayName: string;

  @Field()
  role: string;

  @Field()
  joinStatus: string;
}

@ObjectType()
export class CallSessionType {
  @Field(() => ID)
  id: string;

  @Field(() => GqlCallType)
  callType: GqlCallType;

  @Field(() => GqlCallSessionStatus)
  status: GqlCallSessionStatus;

  @Field(() => ID, { nullable: true })
  childId?: string;

  @Field(() => ID, { nullable: true })
  agencyId?: string;

  @Field(() => ID)
  initiatedByUserId: string;

  @Field()
  initiatedByName: string;

  @Field()
  initiatedByRole: string;

  @Field(() => ID, { nullable: true })
  recipientUserId?: string;

  @Field({ nullable: true })
  recipientName?: string;

  @Field({ nullable: true })
  recipientRole?: string;

  @Field({ nullable: true })
  startedAt?: Date;

  @Field({ nullable: true })
  endedAt?: Date;

  @Field(() => Int, { nullable: true })
  durationSeconds?: number;

  @Field()
  providerName: string;

  @Field()
  createdAt: Date;

  @Field({ nullable: true })
  joinUrl?: string;

  @Field({ nullable: true })
  token?: string;

  @Field({ nullable: true })
  tokenExpiresAt?: Date;

  @Field(() => [CallParticipantType])
  participants: CallParticipantType[];
}

@ObjectType()
export class CallAuditLogType {
  @Field(() => ID)
  id: string;

  @Field(() => ID)
  callSessionId: string;

  @Field(() => ID, { nullable: true })
  agencyId?: string;

  @Field(() => ID, { nullable: true })
  childId?: string;

  @Field(() => ID)
  actorUserId: string;

  @Field()
  actorRole: string;

  @Field(() => ID, { nullable: true })
  targetUserId?: string;

  @Field({ nullable: true })
  targetRole?: string;

  @Field()
  eventType: string;

  @Field(() => GqlCallType, { nullable: true })
  callType?: GqlCallType;

  @Field(() => GqlCallSessionStatus, { nullable: true })
  callStatus?: GqlCallSessionStatus;

  @Field({ nullable: true })
  reason?: string;

  @Field()
  createdAt: Date;
}

@InputType()
export class InitiateCallInput {
  @Field(() => ID)
  @IsUUID()
  recipientUserId: string;

  @Field(() => GqlCallType)
  @IsEnum(GqlCallType)
  callType: GqlCallType;

  @Field(() => ID, { nullable: true })
  @IsOptional()
  @IsUUID()
  childId?: string;
}

@InputType()
export class CallHistoryFilterInput {
  @Field(() => ID, { nullable: true })
  @IsOptional()
  @IsUUID()
  childId?: string;

  @Field(() => ID, { nullable: true })
  @IsOptional()
  @IsUUID()
  userId?: string;

  @Field(() => GqlCallSessionStatus, { nullable: true })
  @IsOptional()
  @IsEnum(GqlCallSessionStatus)
  status?: GqlCallSessionStatus;

  @Field(() => GqlCallType, { nullable: true })
  @IsOptional()
  @IsEnum(GqlCallType)
  callType?: GqlCallType;

  @Field({ nullable: true })
  @IsOptional()
  from?: Date;

  @Field({ nullable: true })
  @IsOptional()
  to?: Date;

  @Field(() => Int, { nullable: true })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(200)
  limit?: number;
}

@InputType()
export class AgencyCallAuditFilterInput {
  @Field(() => ID, { nullable: true })
  @IsOptional()
  @IsUUID()
  childId?: string;

  @Field(() => ID, { nullable: true })
  @IsOptional()
  @IsUUID()
  userId?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  role?: string;

  @Field(() => GqlCallSessionStatus, { nullable: true })
  @IsOptional()
  @IsEnum(GqlCallSessionStatus)
  status?: GqlCallSessionStatus;

  @Field(() => GqlCallType, { nullable: true })
  @IsOptional()
  @IsEnum(GqlCallType)
  callType?: GqlCallType;

  @Field(() => ID, { nullable: true })
  @IsOptional()
  @IsUUID()
  callSessionId?: string;

  @Field({ nullable: true })
  @IsOptional()
  from?: Date;

  @Field({ nullable: true })
  @IsOptional()
  to?: Date;

  @Field(() => Int, { nullable: true })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(500)
  limit?: number;
}
