import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PhiAuditService } from '../audit/phi-audit.service';
import { decryptField, encryptField } from '../common/crypto/field-crypto.util';
import { MessageDeliveryStatus } from '../graphql/types/messaging.types';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';

function messageDeliveryStatus(m: {
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

@Injectable()
export class MessagingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly phiAudit: PhiAuditService,
  ) {}

  async listThreadsForUser(userId: string) {
    const memberships = await this.prisma.messageParticipant.findMany({
      where: { userId },
      include: {
        thread: {
          include: {
            messages: {
              where: { deletedAt: null },
              orderBy: { sentAt: 'desc' },
              take: 1,
              include: { sender: true },
            },
            participants: { include: { user: true } },
          },
        },
      },
    });

    return memberships
      .map((m) => {
        const others = m.thread.participants
          .filter((p) => p.userId !== userId)
          .map((p) => p.user);
        const last = m.thread.messages[0];
        const lastMessageIsMine = last?.senderId === userId;
        return {
          id: m.thread.id,
          subject: m.thread.subject ?? undefined,
          updatedAt: m.thread.updatedAt,
          otherParticipantName: others.length
            ? `${others[0].firstName} ${others[0].lastName}`
            : 'Conversation',
          lastMessageBody: last?.body ? this.decryptBody(last.body) : undefined,
          lastMessageAt: last?.sentAt ?? undefined,
          hasUnread: this.isThreadUnread(last, m.lastReadAt, userId),
          lastMessageIsMine,
          lastMessageStatus:
            last && lastMessageIsMine ? messageDeliveryStatus(last) : undefined,
        };
      })
      .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
  }

  async countUnreadThreadsForUser(userId: string) {
    const memberships = await this.prisma.messageParticipant.findMany({
      where: { userId },
      include: {
        thread: {
          include: {
            messages: {
              where: { deletedAt: null },
              orderBy: { sentAt: 'desc' },
              take: 1,
            },
          },
        },
      },
    });

    return memberships.filter((m) =>
      this.isThreadUnread(m.thread.messages[0], m.lastReadAt, userId),
    ).length;
  }

  async markThreadRead(userId: string, threadId: string) {
    await this.assertParticipant(userId, threadId);
    const now = new Date();
    await this.prisma.messageParticipant.update({
      where: { threadId_userId: { threadId, userId } },
      data: { lastReadAt: now },
    });
    await this.prisma.message.updateMany({
      where: {
        threadId,
        senderId: { not: userId },
        deletedAt: null,
        readAt: null,
      },
      data: { readAt: now },
    });
    return true;
  }

  private async markMessagesDelivered(userId: string, threadId: string) {
    await this.prisma.message.updateMany({
      where: {
        threadId,
        senderId: { not: userId },
        deletedAt: null,
        deliveredAt: null,
      },
      data: { deliveredAt: new Date() },
    });
  }

  private isThreadUnread(
    lastMessage: { senderId: string; sentAt: Date } | undefined,
    lastReadAt: Date | null,
    userId: string,
  ) {
    if (!lastMessage || lastMessage.senderId === userId) {
      return false;
    }
    if (!lastReadAt) {
      return true;
    }
    return lastMessage.sentAt > lastReadAt;
  }

  async getThreadMessages(userId: string, threadId: string) {
    await this.assertParticipant(userId, threadId);
    await this.markMessagesDelivered(userId, threadId);
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (user) {
      await this.phiAudit.logPhiAccess({
        tenantId: user.tenantId,
        actorId: userId,
        action: 'READ',
        resourceType: 'message_thread',
        resourceId: threadId,
      });
    }
    const messages = await this.prisma.message.findMany({
      where: { threadId, deletedAt: null },
      include: { sender: true },
      orderBy: { sentAt: 'asc' },
      take: 200,
    });
    return messages.map((message) => ({
      ...message,
      body: this.decryptBody(message.body),
    }));
  }

  async sendMessage(userId: string, threadId: string, body: string) {
    const trimmed = body.trim();
    if (!trimmed) {
      throw new BadRequestException('Message body is required');
    }
    await this.assertParticipant(userId, threadId);

    const message = await this.prisma.message.create({
      data: {
        threadId,
        senderId: userId,
        body: this.encryptBody(trimmed),
        sentAt: new Date(),
      },
      include: { sender: true },
    });

    await this.prisma.messageThread.update({
      where: { id: threadId },
      data: { updatedAt: new Date() },
    });

    const recipients = await this.prisma.messageParticipant.findMany({
      where: { threadId, userId: { not: userId } },
      select: { userId: true },
    });
    const preview =
      trimmed.length > 120 ? `${trimmed.slice(0, 117)}...` : trimmed;
    const senderName = `${message.sender.firstName} ${message.sender.lastName}`;
    await Promise.all(
      recipients.map((r) =>
        this.notifications.createForUser(r.userId, {
          title: `Message from ${senderName}`,
          body: preview,
          data: { threadId, type: 'MESSAGE' },
        }),
      ),
    );

    return { ...message, body: trimmed };
  }

  private encryptionKey(): string | undefined {
    const key = process.env.PHI_ENCRYPTION_KEY?.trim();
    return key || undefined;
  }

  private encryptBody(body: string): string {
    const key = this.encryptionKey();
    if (!key) return body;
    return `enc:${encryptField(body, key)}`;
  }

  private decryptBody(body: string): string {
    if (!body.startsWith('enc:')) return body;
    const key = this.encryptionKey();
    if (!key) return body;
    try {
      return decryptField(body.slice(4), key);
    } catch {
      return body;
    }
  }

  async listParentContactsForTherapist(therapistUserId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId: therapistUserId },
    });
    if (!therapist) {
      return [];
    }

    const appointments = await this.prisma.appointment.findMany({
      where: {
        therapistId: therapist.id,
        status: { notIn: ['CANCELLED'] },
      },
      include: {
        parent: { include: { user: true } },
        child: true,
      },
      orderBy: { scheduledStart: 'desc' },
      take: 100,
    });

    const byParent = new Map<
      string,
      { parentId: string; displayName: string; children: Set<string> }
    >();
    for (const row of appointments) {
      const key = row.parentId;
      const existing = byParent.get(key);
      const childName = `${row.child.firstName} ${row.child.lastName}`;
      if (existing) {
        existing.children.add(childName);
      } else {
        byParent.set(key, {
          parentId: row.parentId,
          displayName: `${row.parent.user.firstName} ${row.parent.user.lastName}`,
          children: new Set([childName]),
        });
      }
    }

    return [...byParent.values()].map((p) => ({
      parentId: p.parentId,
      displayName: p.displayName,
      childSummary: [...p.children].slice(0, 3).join(', '),
    }));
  }

  async startConversationWithParent(therapistUserId: string, parentId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId: therapistUserId },
      include: { user: true },
    });
    if (!therapist) {
      throw new BadRequestException('Therapist profile not found');
    }

    const parent = await this.prisma.parent.findFirst({
      where: { id: parentId, tenantId: therapist.tenantId },
      include: { user: true },
    });
    if (!parent) {
      throw new NotFoundException('Parent not found');
    }

    const existing = await this.findThreadBetweenUsers(
      therapistUserId,
      parent.userId,
      therapist.tenantId,
    );
    if (existing) {
      return existing;
    }

    const thread = await this.prisma.messageThread.create({
      data: {
        tenantId: therapist.tenantId,
        subject: `Care team — ${parent.user.firstName} ${parent.user.lastName}`,
        participants: {
          create: [{ userId: therapistUserId }, { userId: parent.userId }],
        },
      },
      include: {
        participants: { include: { user: true } },
        messages: { take: 0 },
      },
    });

    return {
      id: thread.id,
      subject: thread.subject ?? undefined,
      updatedAt: thread.updatedAt,
      otherParticipantName: `${parent.user.firstName} ${parent.user.lastName}`,
      hasUnread: false,
    };
  }

  async startConversationWithTherapist(
    parentUserId: string,
    therapistId: string,
  ) {
    const parent = await this.prisma.parent.findUnique({
      where: { userId: parentUserId },
    });
    if (!parent) {
      throw new BadRequestException('Parent profile not found');
    }

    const therapist = await this.prisma.therapist.findFirst({
      where: { id: therapistId, tenantId: parent.tenantId },
      include: { user: true },
    });
    if (!therapist) {
      throw new NotFoundException('Therapist not found');
    }

    const existing = await this.findThreadBetweenUsers(
      parentUserId,
      therapist.userId,
      parent.tenantId,
    );
    if (existing) {
      return existing;
    }

    const thread = await this.prisma.messageThread.create({
      data: {
        tenantId: parent.tenantId,
        subject: `Care team — ${therapist.user.firstName} ${therapist.user.lastName}`,
        participants: {
          create: [{ userId: parentUserId }, { userId: therapist.userId }],
        },
      },
      include: {
        participants: { include: { user: true } },
        messages: { take: 0 },
      },
    });

    return {
      id: thread.id,
      subject: thread.subject ?? undefined,
      updatedAt: thread.updatedAt,
      otherParticipantName: `${therapist.user.firstName} ${therapist.user.lastName}`,
      hasUnread: false,
    };
  }

  private async findThreadBetweenUsers(
    userA: string,
    userB: string,
    tenantId: string,
  ) {
    const threads = await this.prisma.messageThread.findMany({
      where: {
        tenantId,
        participants: { some: { userId: userA } },
      },
      include: {
        participants: { include: { user: true } },
        messages: {
          where: { deletedAt: null },
          orderBy: { sentAt: 'desc' },
          take: 1,
        },
      },
    });

    for (const thread of threads) {
      const ids = new Set(thread.participants.map((p) => p.userId));
      if (ids.has(userA) && ids.has(userB) && ids.size === 2) {
        const peer = thread.participants.find((p) => p.userId !== userA);
        const last = thread.messages[0];
        return {
          id: thread.id,
          subject: thread.subject ?? undefined,
          updatedAt: thread.updatedAt,
          otherParticipantName: peer
            ? `${peer.user.firstName} ${peer.user.lastName}`
            : 'Conversation',
          lastMessageBody: last?.body ? this.decryptBody(last.body) : undefined,
          lastMessageAt: last?.sentAt ?? undefined,
          hasUnread: false,
        };
      }
    }
    return null;
  }

  private async assertParticipant(userId: string, threadId: string) {
    const row = await this.prisma.messageParticipant.findUnique({
      where: { threadId_userId: { threadId, userId } },
    });
    if (!row) {
      throw new ForbiddenException('Not a participant in this thread');
    }
  }

  async create(data: Record<string, unknown>) {
    void data;
    throw new BadRequestException('Use GraphQL messaging operations');
  }

  async findAll() {
    return this.prisma.messageThread.findMany({ take: 20 });
  }

  async findOne(id: string) {
    const thread = await this.prisma.messageThread.findUnique({
      where: { id },
    });
    if (!thread) {
      throw new NotFoundException('Thread not found');
    }
    return thread;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.messageThread.update({
      where: { id },
      data: data as Parameters<
        typeof this.prisma.messageThread.update
      >[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.messageThread.delete({ where: { id } });
    return { id, deleted: true };
  }
}
