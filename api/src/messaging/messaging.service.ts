import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class MessagingService {
  constructor(private readonly prisma: PrismaService) {}

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
      return {
        id: m.thread.id,
        subject: m.thread.subject ?? undefined,
        updatedAt: m.thread.updatedAt,
        otherParticipantName: others.length
          ? `${others[0].firstName} ${others[0].lastName}`
          : 'Conversation',
        lastMessageBody: last?.body ?? undefined,
        lastMessageAt: last?.sentAt ?? undefined,
      };
    })
      .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
  }

  async getThreadMessages(userId: string, threadId: string) {
    await this.assertParticipant(userId, threadId);
    return this.prisma.message.findMany({
      where: { threadId, deletedAt: null },
      include: { sender: true },
      orderBy: { sentAt: 'asc' },
      take: 200,
    });
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
        body: trimmed,
      },
      include: { sender: true },
    });

    await this.prisma.messageThread.update({
      where: { id: threadId },
      data: { updatedAt: new Date() },
    });

    return message;
  }

  async startConversationWithTherapist(parentUserId: string, therapistId: string) {
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
          create: [
            { userId: parentUserId },
            { userId: therapist.userId },
          ],
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
        const other = thread.participants.find((p) => p.userId === userA);
        const peer = thread.participants.find((p) => p.userId !== userA);
        const last = thread.messages[0];
        return {
          id: thread.id,
          subject: thread.subject ?? undefined,
          updatedAt: thread.updatedAt,
          otherParticipantName: peer
            ? `${peer.user.firstName} ${peer.user.lastName}`
            : 'Conversation',
          lastMessageBody: last?.body ?? undefined,
          lastMessageAt: last?.sentAt ?? undefined,
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
    const thread = await this.prisma.messageThread.findUnique({ where: { id } });
    if (!thread) {
      throw new NotFoundException('Thread not found');
    }
    return thread;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.messageThread.update({
      where: { id },
      data: data as Parameters<typeof this.prisma.messageThread.update>[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.messageThread.delete({ where: { id } });
    return { id, deleted: true };
  }
}
