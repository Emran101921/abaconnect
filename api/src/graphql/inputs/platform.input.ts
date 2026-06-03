import { Field, Float, ID, InputType, Int } from '@nestjs/graphql';
import { DocumentType, TherapyType } from '../../../generated/prisma/client';

@InputType()
export class RegisterDocumentInput {
  @Field()
  title: string;

  @Field()
  fileName: string;

  @Field()
  mimeType: string;

  @Field(() => Int)
  fileSize: number;

  @Field(() => DocumentType)
  type: DocumentType;

  @Field(() => ID, { nullable: true })
  childId?: string;
}

@InputType()
export class SubmitInsuranceClaimInput {
  @Field(() => ID)
  childId: string;

  @Field()
  payerName: string;

  @Field(() => Float)
  billedAmount: number;

  @Field()
  serviceDate: Date;
}

@InputType()
export class GrantConsentInput {
  @Field()
  consentType: string;

  @Field()
  version: string;
}

@InputType()
export class RecordEvvInput {
  @Field(() => ID)
  sessionId: string;

  @Field(() => Float)
  latitude: number;

  @Field(() => Float)
  longitude: number;

  @Field()
  eventType: string;
}

@InputType()
export class FileComplaintInput {
  @Field()
  category: string;

  @Field()
  subject: string;

  @Field()
  description: string;

  @Field(() => ID, { nullable: true })
  therapistId?: string;
}

@InputType()
export class SoapAssistInput {
  @Field({ nullable: true })
  childName?: string;

  @Field(() => TherapyType, { nullable: true })
  therapyType?: TherapyType;
}
