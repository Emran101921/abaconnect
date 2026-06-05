import { Field, ID, ObjectType, registerEnumType } from '@nestjs/graphql';

export enum MessageDeliveryStatus {
  SENT = 'SENT',
  DELIVERED = 'DELIVERED',
  READ = 'READ',
}

registerEnumType(MessageDeliveryStatus, { name: 'MessageDeliveryStatus' });

@ObjectType()
export class MessageThreadType {
  @Field(() => ID)
  id: string;

  @Field({ nullable: true })
  subject?: string;

  @Field()
  otherParticipantName: string;

  @Field({ nullable: true })
  lastMessageBody?: string;

  @Field({ nullable: true })
  lastMessageAt?: Date;

  @Field()
  updatedAt: Date;

  @Field()
  hasUnread: boolean;
}

@ObjectType()
export class ParentContactType {
  @Field(() => ID)
  parentId: string;

  @Field()
  displayName: string;

  @Field({ nullable: true })
  childSummary?: string;
}

@ObjectType()
export class ChatMessageType {
  @Field(() => ID)
  id: string;

  @Field()
  body: string;

  @Field()
  sentAt: Date;

  @Field()
  senderName: string;

  @Field()
  isMine: boolean;

  @Field({ nullable: true })
  deliveredAt?: Date;

  @Field({ nullable: true })
  readAt?: Date;

  @Field(() => MessageDeliveryStatus, { nullable: true })
  status?: MessageDeliveryStatus;
}
