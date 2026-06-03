import { Field, Float, ID, InputType } from '@nestjs/graphql';
import { ClaimStatus } from '../../../generated/prisma/client';

@InputType()
export class UpdateInsuranceClaimInput {
  @Field(() => ID)
  claimId: string;

  @Field(() => ClaimStatus)
  status: ClaimStatus;

  @Field({ nullable: true })
  denialReason?: string;

  @Field(() => Float, { nullable: true })
  approvedAmount?: number;
}
