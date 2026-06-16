import { Field, InputType } from '@nestjs/graphql';
import { AgencyDocumentType } from '../../../generated/prisma/client';

@InputType()
export class UpdateAgencyProfileInput {
  @Field({ nullable: true })
  name?: string;

  @Field({ nullable: true })
  ein?: string;

  @Field({ nullable: true })
  phone?: string;

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
  email?: string;

  @Field({ nullable: true })
  website?: string;
}

@InputType()
export class CreateAgencyStaffInput {
  @Field()
  email!: string;

  @Field()
  password!: string;

  @Field()
  firstName!: string;

  @Field()
  lastName!: string;

  @Field({ nullable: true })
  phone?: string;

  @Field({ nullable: true })
  licenseNumber?: string;

  @Field({ nullable: true })
  licenseState?: string;

  @Field({ nullable: true })
  npi?: string;
}

export { AgencyDocumentType };
