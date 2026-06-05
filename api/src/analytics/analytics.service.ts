import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  async getTenantMetrics(tenantId: string) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const [
      appointmentsThisWeek,
      sessionsCompleted,
      revenuePaid,
      activeChildren,
    ] = await Promise.all([
      this.prisma.appointment.count({
        where: {
          tenantId,
          scheduledStart: { gte: new Date(Date.now() - 7 * 86400000) },
        },
      }),
      this.prisma.session.count({
        where: { tenantId, status: 'COMPLETED' },
      }),
      this.prisma.payment.aggregate({
        where: { tenantId, status: 'SUCCEEDED' },
        _sum: { amount: true },
      }),
      this.prisma.child.count({ where: { tenantId } }),
    ]);

    const metrics = [
      { key: 'appointments_7d', value: appointmentsThisWeek },
      { key: 'sessions_completed', value: sessionsCompleted },
      { key: 'revenue_paid', value: Number(revenuePaid._sum.amount ?? 0) },
      { key: 'active_children', value: activeChildren },
    ];

    for (const m of metrics) {
      await this.prisma.analyticsSnapshot.upsert({
        where: {
          tenantId_snapshotDate_metricKey: {
            tenantId,
            snapshotDate: today,
            metricKey: m.key,
          },
        },
        update: { metricValue: m.value },
        create: {
          tenantId,
          snapshotDate: today,
          metricKey: m.key,
          metricValue: m.value,
        },
      });
    }

    return metrics.map((m) => ({ metricKey: m.key, metricValue: m.value }));
  }

  async create(data: Record<string, unknown>) {
    void data;
    return { id: 'analytics' };
  }

  async findAll() {
    return this.prisma.analyticsSnapshot.findMany({ take: 50 });
  }

  async findOne(id: string) {
    const row = await this.prisma.analyticsSnapshot.findUnique({
      where: { id },
    });
    if (!row) throw new NotFoundException('Snapshot not found');
    return row;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.analyticsSnapshot.update({
      where: { id },
      data: data as Parameters<
        typeof this.prisma.analyticsSnapshot.update
      >[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.analyticsSnapshot.delete({ where: { id } });
    return { id, deleted: true };
  }
}
