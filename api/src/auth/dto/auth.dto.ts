import {
  IsEmail,
  IsIn,
  IsOptional,
  IsString,
  MinLength,
} from 'class-validator';

export class RegisterDto {
  @IsEmail()
  email!: string;

  @MinLength(8)
  password!: string;

  @IsString()
  @MinLength(1)
  firstName!: string;

  @IsString()
  @MinLength(1)
  lastName!: string;

  @IsOptional()
  @IsIn(['PARENT', 'THERAPIST', 'AGENCY_ADMIN'])
  role?: 'PARENT' | 'THERAPIST' | 'AGENCY_ADMIN';

  @IsOptional()
  @IsString()
  tenantId?: string;

  /** Required when role is AGENCY_ADMIN */
  @IsOptional()
  @IsString()
  agencyName?: string;

  @IsOptional()
  @IsString()
  agencyEin?: string;

  @IsOptional()
  @IsString()
  agencyPhone?: string;

  @IsOptional()
  @IsString()
  agencyState?: string;

  @IsOptional()
  @IsString()
  agencyZipCode?: string;
}

export class LoginDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(1)
  password!: string;

  @IsOptional()
  @IsString()
  tenantId?: string;
}
