import { InjectQueue } from '@nestjs/bull';
import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { Queue } from 'bull';
import { Prisma } from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import type { PushPayload } from '../push/push.service';

@Injectable()
export class NotificationsService {
  constructor(
    private readonly prisma: PrismaService,
    @InjectQueue('push') private readonly pushQueue: Queue<PushPayload>,
  ) {}

  async countUnread(userId: string) {
    return this.prisma.notification.count({
      where: { userId, readAt: null },
    });
  }

  async listForUser(userId: string, unreadOnly = false) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) return [];
    return this.prisma.notification.findMany({
      where: {
        userId,
        ...(unreadOnly ? { readAt: null } : {}),
      },
      orderBy: { sentAt: 'desc' },
      take: 50,
    });
  }

  async markAllRead(userId: string) {
    const result = await this.prisma.notification.updateMany({
      where: { userId, readAt: null },
      data: { readAt: new Date() },
    });
    return { updated: result.count };
  }

  async markRead(userId: string, notificationId: string) {
    const row = await this.prisma.notification.findFirst({
      where: { id: notificationId, userId },
    });
    if (!row) throw new NotFoundException('Notification not found');
    return this.prisma.notification.update({
      where: { id: notificationId },
      data: { readAt: new Date() },
    });
  }

  async createForUser(
    userId: string,
    data: { title: string; body: string; data?: Record<string, unknown> },
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new BadRequestException('User not found');
    const isSecureMessage =
      data.data?.type === 'MESSAGE' ||
      data.title.toLowerCase().includes('message');
    const storedTitle = isSecureMessage ? 'New secure message' : data.title;
    const storedBody = isSecureMessage
      ? 'You have a new secure message. Please log in to view it.'
      : data.body;

    const notification = await this.prisma.notification.create({
      data: {
        tenantId: user.tenantId,
        userId,
        title: storedTitle,
        body: storedBody,
        data: (data.data ?? {}) as Prisma.InputJsonValue,
      },
    });

    const safeTitle = 'BloomOra';
    const safeBody =
      'You have a new notification. Open the app to view details.';
    await this.pushQueue.add(
      'send',
      {
        userId,
        title: safeTitle,
        body: safeBody,
        data: data.data,
      },
      { removeOnComplete: true, attempts: 2 },
    );

    return notification;
  }

  async create(data: Record<string, unknown>) {
    void data;
    throw new BadRequestException('Use createForUser');
  }

  async findAll() {
    return this.prisma.notification.findMany({ take: 20 });
  }

  async findOne(id: string) {
    const row = await this.prisma.notification.findUnique({ where: { id } });
    if (!row) throw new NotFoundException('Notification not found');
    return row;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.notification.update({
      where: { id },
      data: data as Parameters<
        typeof this.prisma.notification.update
      >[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.notification.delete({ where: { id } });
    return { id, deleted: true };
  }
}
