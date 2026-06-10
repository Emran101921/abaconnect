import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsObject,
  IsOptional,
  IsString,
  MinLength,
} from 'class-validator';
import {
  PrivacyRightsRequestStatus,
  PrivacyRightsRequestType,
} from '../../../generated/prisma/client';

export class AcknowledgeNoticeDto {
  @IsOptional()
  @IsString()
  appVersion?: string;

  @IsOptional()
  @IsString()
  platform?: string;

  @IsOptional()
  @IsString()
  deviceId?: string;
}

export class SubmitPrivacyRightsRequestDto {
  @IsEnum(PrivacyRightsRequestType)
  requestType!: PrivacyRightsRequestType;

  @IsObject()
  payload!: Record<string, unknown>;
}

export class CreateNoticeVersionDto {
  @IsString()
  @MinLength(1)
  versionNumber!: string;

  @IsOptional()
  @IsString()
  title?: string;

  @IsOptional()
  @IsString()
  fullNoticeText?: string;

  @IsOptional()
  @IsString()
  privacyPolicyText?: string;

  @IsOptional()
  @IsDateString()
  effectiveDate?: string;

  @IsOptional()
  @IsBoolean()
  publish?: boolean;
}

export class UpdatePrivacyRequestStatusDto {
  @IsEnum(PrivacyRightsRequestStatus)
  status!: PrivacyRightsRequestStatus;

  @IsOptional()
  @IsString()
  internalNotes?: string;
}
