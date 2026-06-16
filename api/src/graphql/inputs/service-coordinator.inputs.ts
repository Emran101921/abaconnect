import { Field, InputType } from '@nestjs/graphql';
import { AgencyRosterStatus } from '../../../generated/prisma/client';

@InputType()
export class CreateServiceCoordinatorInput {
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

  @Field(() => [String], { nullable: true })
  languages?: string[];

  @Field({ nullable: true })
  notes?: string;
}

@InputType()
export class UpdateServiceCoordinatorInput {
  @Field({ nullable: true })
  firstName?: string;

  @Field({ nullable: true })
  lastName?: string;

  @Field({ nullable: true })
  phone?: string;

  @Field(() => [String], { nullable: true })
  languages?: string[];

  @Field({ nullable: true })
  notes?: string;

  @Field(() => AgencyRosterStatus, { nullable: true })
  status?: AgencyRosterStatus;
}

@InputType()
export class UpsertEiScreeningInput {
  @Field({ nullable: true })
  answersJson?: string;

  @Field({ nullable: true })
  notes?: string;

  @Field({ nullable: true })
  followUpRequired?: boolean;

  @Field({ nullable: true })
  followUpDueDate?: Date;

  @Field({ nullable: true })
  submit?: boolean;

  @Field({ nullable: true })
  progressSummary?: string;

  @Field({ nullable: true })
  newConcerns?: string;
}

@InputType()
export class CreateScNoteInput {
  @Field()
  noteType!: string;

  @Field()
  noteText!: string;

  @Field({ nullable: true })
  actionRequired?: boolean;

  @Field({ nullable: true })
  actionDueDate?: Date;
}
