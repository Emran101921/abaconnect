import { Field, ID, InputType, Int } from '@nestjs/graphql';
import { TherapyType } from '../../../generated/prisma/client';

@InputType()
export class UpdateTherapistProfileInput {
  @Field({ nullable: true })
  bio?: string;

  @Field({ nullable: true })
  npi?: string;

  @Field({ nullable: true })
  licenseNumber?: string;

  @Field({ nullable: true })
  licenseState?: string;

  @Field(() => Int, { nullable: true })
  yearsExperience?: number;

  @Field(() => [TherapyType], { nullable: true })
  therapyTypes?: TherapyType[];
}

@InputType()
export class SaveSoapNoteInput {
  @Field(() => ID)
  sessionId: string;

  @Field({ nullable: true })
  subjective?: string;

  @Field({ nullable: true })
  objective?: string;

  @Field({ nullable: true })
  assessment?: string;

  @Field({ nullable: true })
  plan?: string;

  /** NYC EIP Individual Session Note form (JSON string). */
  @Field({ nullable: true })
  eipFormData?: string;
}
