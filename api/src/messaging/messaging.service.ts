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
          otherParticipantUserId: others[0]?.id,
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
    await Promise.all(
      recipients.map((r) =>
        this.notifications.createForUser(r.userId, {
          title: 'New secure message',
          body: 'You have a new secure message. Please log in to view it.',
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

  async listContactsForServiceCoordinator(coordinatorUserId: string) {
    const coordinator = await this.prisma.user.findFirst({
      where: { id: coordinatorUserId, role: 'SERVICE_COORDINATOR' },
    });
    if (!coordinator?.agencyId) {
      return [];
    }

    const roster = await this.prisma.agencyRoster.findFirst({
      where: {
        userId: coordinatorUserId,
        agencyId: coordinator.agencyId,
        role: 'SERVICE_COORDINATOR',
        status: 'ACTIVE',
        removedAt: null,
      },
    });
    if (!roster || !coordinator.isActive) {
      throw new ForbiddenException('Service coordinator access suspended');
    }

    const assignments = await this.prisma.childServiceCoordinatorAssignment.findMany({
      where: {
        serviceCoordinatorId: coordinatorUserId,
        agencyId: coordinator.agencyId,
        status: 'ACTIVE',
        removedAt: null,
      },
      include: {
        child: {
          include: {
            parent: { include: { user: true } },
          },
        },
      },
    });

    const childIds = assignments.map((a) => a.childId);
    const appointments =
      childIds.length > 0
        ? await this.prisma.appointment.findMany({
            where: {
              childId: { in: childIds },
              agencyId: coordinator.agencyId,
              status: { notIn: ['CANCELLED'] },
            },
            include: {
              child: true,
              therapist: { include: { user: true } },
            },
            orderBy: { scheduledStart: 'desc' },
            take: 200,
          })
        : [];

    const contacts = new Map<
      string,
      { userId: string; displayName: string; roleLabel: string; children: Set<string> }
    >();

    for (const assignment of assignments) {
      const parentUser = assignment.child.parent.user;
      const parentKey = parentUser.id;
      const childName = `${assignment.child.firstName} ${assignment.child.lastName}`;
      const existingParent = contacts.get(parentKey);
      if (existingParent) {
        existingParent.children.add(childName);
      } else {
        contacts.set(parentKey, {
          userId: parentUser.id,
          displayName: `${parentUser.firstName} ${parentUser.lastName}`,
          roleLabel: 'Parent',
          children: new Set([childName]),
        });
      }
    }

    for (const apt of appointments) {
      const therapistUser = apt.therapist.user;
      const key = therapistUser.id;
      const childName = `${apt.child.firstName} ${apt.child.lastName}`;
      const existing = contacts.get(key);
      if (existing) {
        existing.children.add(childName);
      } else {
        contacts.set(key, {
          userId: therapistUser.id,
          displayName: `${therapistUser.firstName} ${therapistUser.lastName}`,
          roleLabel: 'Provider',
          children: new Set([childName]),
        });
      }
    }

    const agencyAdmins = await this.prisma.user.findMany({
      where: {
        agencyId: coordinator.agencyId,
        role: 'AGENCY_ADMIN',
        isActive: true,
      },
      take: 3,
    });
    for (const admin of agencyAdmins) {
      if (admin.id === coordinatorUserId) continue;
      contacts.set(admin.id, {
        userId: admin.id,
        displayName: `${admin.firstName} ${admin.lastName}`,
        roleLabel: 'Agency admin',
        children: new Set(['Agency support']),
      });
    }

    return [...contacts.values()].map((c) => ({
      userId: c.userId,
      displayName: c.displayName,
      roleLabel: c.roleLabel,
      childSummary: [...c.children].slice(0, 3).join(', '),
    }));
  }

  async startConversationAsServiceCoordinator(
    coordinatorUserId: string,
    targetUserId: string,
  ) {
    await this.assertServiceCoordinatorCanMessage(coordinatorUserId, targetUserId);

    const coordinator = await this.prisma.user.findUniqueOrThrow({
      where: { id: coordinatorUserId },
    });
    const target = await this.prisma.user.findFirst({
      where: { id: targetUserId, tenantId: coordinator.tenantId },
    });
    if (!target) {
      throw new NotFoundException('Contact not found');
    }

    const existing = await this.findThreadBetweenUsers(
      coordinatorUserId,
      targetUserId,
      coordinator.tenantId,
    );
    if (existing) {
      return existing;
    }

    const thread = await this.prisma.messageThread.create({
      data: {
        tenantId: coordinator.tenantId,
        subject: `Care coordination — ${target.firstName} ${target.lastName}`,
        participants: {
          create: [{ userId: coordinatorUserId }, { userId: targetUserId }],
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
      otherParticipantName: `${target.firstName} ${target.lastName}`,
      hasUnread: false,
    };
  }

  private async assertServiceCoordinatorCanMessage(
    coordinatorUserId: string,
    targetUserId: string,
  ) {
    const allowed = await this.listContactsForServiceCoordinator(coordinatorUserId);
    if (!allowed.some((c) => c.userId === targetUserId)) {
      throw new ForbiddenException('Not authorized to message this contact');
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
