import { Field, Int, ObjectType } from '@nestjs/graphql';

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
