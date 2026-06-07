import { Args, ID, Int, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { MessagingService } from '../messaging/messaging.service';
import { SendMessageInput } from './inputs/messaging-payments.input';
import {
  ChatMessageType,
  MessageDeliveryStatus,
  MessageThreadType,
  ParentContactType,
} from './types/messaging.types';

type MessageRow = {
  id: string;
  body: string;
  sentAt: Date;
  deliveredAt: Date | null;
  readAt: Date | null;
  senderId: string;
  sender: { firstName: string; lastName: string };
};

function toChatMessage(m: MessageRow, userId: string): ChatMessageType {
  const isMine = m.senderId === userId;
  return {
    id: m.id,
    body: m.body,
    sentAt: m.sentAt,
    senderName: `${m.sender.firstName} ${m.sender.lastName}`,
    isMine,
    deliveredAt: m.deliveredAt ?? undefined,
    readAt: m.readAt ?? undefined,
    status: isMine ? deliveryStatus(m) : undefined,
  };
}

function deliveryStatus(m: {
  deliveredAt: Date | null;
  readAt: Date | null;
}): MessageDeliveryStatus {
  if (m.readAt) {
    return MessageDeliveryStatus.READ;
  }
  if (m.deliveredAt) {
    return MessageDeliveryStatus.DELIVERED;
  }
  return MessageDeliveryStatus.SENT;
}

@Resolver()
@Roles('PARENT', 'THERAPIST')
export class MessagingResolver {
  constructor(private readonly messagingService: MessagingService) {}

  @Query(() => [MessageThreadType], { name: 'myMessageThreads' })
  async myMessageThreads(
    @CurrentUser() user: AuthUser,
  ): Promise<MessageThreadType[]> {
    return this.messagingService.listThreadsForUser(user.id);
  }

  @Query(() => Int, { name: 'unreadMessageThreadCount' })
  async unreadMessageThreadCount(
    @CurrentUser() user: AuthUser,
  ): Promise<number> {
    return this.messagingService.countUnreadThreadsForUser(user.id);
  }

  @Query(() => [ChatMessageType], { name: 'threadMessages' })
  async threadMessages(
    @CurrentUser() user: AuthUser,
    @Args('threadId', { type: () => ID }) threadId: string,
  ): Promise<ChatMessageType[]> {
    const rows = await this.messagingService.getThreadMessages(
      user.id,
      threadId,
    );
    return rows.map((m) => toChatMessage(m, user.id));
  }

  @Mutation(() => ChatMessageType, { name: 'sendMessage' })
  async sendMessage(
    @CurrentUser() user: AuthUser,
    @Args('input') input: SendMessageInput,
  ): Promise<ChatMessageType> {
    const m = await this.messagingService.sendMessage(
      user.id,
      input.threadId,
      input.body,
    );
    return toChatMessage(m, user.id);
  }

  @Mutation(() => Boolean, { name: 'markMessageThreadRead' })
  async markMessageThreadRead(
    @CurrentUser() user: AuthUser,
    @Args('threadId', { type: () => ID }) threadId: string,
  ): Promise<boolean> {
    return this.messagingService.markThreadRead(user.id, threadId);
  }

  @Query(() => [ParentContactType], { name: 'myTherapistParentContacts' })
  @Roles('THERAPIST')
  async myTherapistParentContacts(
    @CurrentUser() user: AuthUser,
  ): Promise<ParentContactType[]> {
    return this.messagingService.listParentContactsForTherapist(user.id);
  }

  @Mutation(() => MessageThreadType, { name: 'startTherapistConversation' })
  @Roles('PARENT')
  async startTherapistConversation(
    @CurrentUser() user: AuthUser,
    @Args('therapistId', { type: () => ID }) therapistId: string,
  ): Promise<MessageThreadType> {
    return this.messagingService.startConversationWithTherapist(
      user.id,
      therapistId,
    );
  }

  @Mutation(() => MessageThreadType, { name: 'startParentConversation' })
  @Roles('THERAPIST')
  async startParentConversation(
    @CurrentUser() user: AuthUser,
    @Args('parentId', { type: () => ID }) parentId: string,
  ): Promise<MessageThreadType> {
    return this.messagingService.startConversationWithParent(user.id, parentId);
  }
}
