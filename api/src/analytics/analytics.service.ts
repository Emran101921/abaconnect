import { Injectable, NotFoundException } from '@nestjs/common';
import {
  DateRangeFilter,
  priorPeriodBounds,
  resolveAnalyticsBounds,
  startOfDay,
} from '../common/date-range.util';
import { PrismaService } from '../prisma/prisma.service';

type MetricCounts = {
  appointments: number;
  sessionsCompleted: number;
  revenuePaid: number;
  activeChildren: number;
  claimsPaidTotal: number;
};

@Injectable()
export class AnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  async getTenantMetrics(tenantId: string, dateRange?: DateRangeFilter) {
    const today = startOfDay(new Date());
    const hasExplicitRange = Boolean(dateRange?.fromDate || dateRange?.toDate);
    const currentBounds = resolveAnalyticsBounds(dateRange);
    const priorBounds = priorPeriodBounds(currentBounds.from, currentBounds.to);

    const [current, prior] = await Promise.all([
      this.queryMetricCounts(tenantId, currentBounds),
      this.queryMetricCounts(tenantId, priorBounds),
    ]);

    const revenueMismatch =
      Math.abs(current.revenuePaid - current.claimsPaidTotal) > 0.01 ? 1 : 0;

    const metrics = [
      { key: 'appointments_7d', value: current.appointments },
      { key: 'sessions_completed', value: current.sessionsCompleted },
      { key: 'revenue_paid', value: current.revenuePaid },
      { key: 'claims_paid_total', value: current.claimsPaidTotal },
      { key: 'revenue_mismatch', value: revenueMismatch },
      { key: 'active_children', value: current.activeChildren },
    ];

    const priorByKey: Record<string, number> = {
      appointments_7d: prior.appointments,
      sessions_completed: prior.sessionsCompleted,
      revenue_paid: prior.revenuePaid,
      claims_paid_total: prior.claimsPaidTotal,
      revenue_mismatch: 0,
      active_children: prior.activeChildren,
    };

    if (!hasExplicitRange) {
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
    }

    return metrics.map((m) => ({
      metricKey: m.key,
      metricValue: m.value,
      priorPeriodValue: priorByKey[m.key] ?? 0,
    }));
  }

  private async queryMetricCounts(
    tenantId: string,
    bounds: { from: Date; to: Date },
  ): Promise<MetricCounts> {
    const appointmentWhere = {
      tenantId,
      scheduledStart: { gte: bounds.from, lte: bounds.to },
    };

    const sessionWhere = {
      tenantId,
      status: 'COMPLETED' as const,
      checkOutAt: { gte: bounds.from, lte: bounds.to },
    };

    const paymentWhere = {
      tenantId,
      status: 'SUCCEEDED' as const,
      paidAt: { gte: bounds.from, lte: bounds.to },
    };

    const paidClaimsWhere = {
      tenantId,
      status: 'PAID' as const,
      serviceDate: { gte: bounds.from, lte: bounds.to },
    };

    const [
      appointmentsCount,
      sessionsCompleted,
      revenuePaid,
      activeChildren,
      paidClaims,
    ] = await Promise.all([
      this.prisma.appointment.count({ where: appointmentWhere }),
      this.prisma.session.count({ where: sessionWhere }),
      this.prisma.payment.aggregate({
        where: paymentWhere,
        _sum: { amount: true },
      }),
      this.prisma.appointment
        .findMany({
          where: appointmentWhere,
          select: { childId: true },
          distinct: ['childId'],
        })
        .then((rows) => rows.length),
      this.prisma.insuranceClaim.findMany({
        where: paidClaimsWhere,
        select: { paidAmount: true, approvedAmount: true, billedAmount: true },
      }),
    ]);

    const claimsPaidTotal = paidClaims.reduce((sum, claim) => {
      const amount =
        claim.paidAmount ?? claim.approvedAmount ?? claim.billedAmount;
      return sum + Number(amount ?? 0);
    }, 0);

    return {
      appointments: appointmentsCount,
      sessionsCompleted,
      revenuePaid: Number(revenuePaid._sum.amount ?? 0),
      activeChildren,
      claimsPaidTotal,
    };
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
