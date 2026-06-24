type ChartChild = {
  id: string;
  firstName: string;
  lastName: string;
  dateOfBirth: Date;
  gender?: string | null;
  primaryLanguage?: string | null;
  guardianName?: string | null;
  pediatricianName?: string | null;
  insuranceType?: string | null;
};

type ChartAppointment = {
  childId: string;
  therapyType: string;
  scheduledStart: Date;
  status: string;
  child: ChartChild & {
    parent: { user: { firstName: string; lastName: string } };
  };
};

type ChartSession = {
  childId: string;
  status: string;
  checkInAt?: Date | null;
  checkOutAt?: Date | null;
};

export type CaseloadChartSeed = {
  child: ChartChild;
  parentName: string;
};

export type CaseloadChartRow = {
  childId: string;
  chartNumber: string;
  firstName: string;
  lastName: string;
  dateOfBirth: Date;
  gender?: string;
  primaryLanguage?: string;
  guardianName?: string;
  pediatricianName?: string;
  insuranceType?: string;
  parentName: string;
  therapyTypes: string[];
  upcomingAppointments: number;
  completedSessions: number;
  pendingDocumentation: number;
  lastVisitAt?: Date;
};

export function chartNumberForChild(childId: string): string {
  return `CH-${childId.replace(/-/g, '').slice(-8).toUpperCase()}`;
}

export function buildCaseloadCharts(
  appointments: ChartAppointment[],
  sessions: ChartSession[],
  seeds: CaseloadChartSeed[] = [],
): CaseloadChartRow[] {
  const now = new Date();
  const byChild = new Map<
    string,
    {
      child: ChartChild;
      parentName: string;
      therapyTypes: Set<string>;
      upcomingAppointments: number;
      completedSessions: number;
      pendingDocumentation: number;
      lastVisitAt?: Date;
    }
  >();

  for (const seed of seeds) {
    byChild.set(seed.child.id, {
      child: seed.child,
      parentName: seed.parentName,
      therapyTypes: new Set<string>(),
      upcomingAppointments: 0,
      completedSessions: 0,
      pendingDocumentation: 0,
      lastVisitAt: undefined,
    });
  }

  for (const row of appointments) {
    const key = row.childId;
    const parentName = `${row.child.parent.user.firstName} ${row.child.parent.user.lastName}`;
    const existing = byChild.get(key);
    if (existing) {
      existing.therapyTypes.add(row.therapyType);
      if (
        row.scheduledStart >= now &&
        !['COMPLETED', 'CANCELLED', 'NO_SHOW'].includes(row.status)
      ) {
        existing.upcomingAppointments += 1;
      }
    } else {
      byChild.set(key, {
        child: row.child,
        parentName,
        therapyTypes: new Set([row.therapyType]),
        upcomingAppointments:
          row.scheduledStart >= now &&
          !['COMPLETED', 'CANCELLED', 'NO_SHOW'].includes(row.status)
            ? 1
            : 0,
        completedSessions: 0,
        pendingDocumentation: 0,
        lastVisitAt: undefined,
      });
    }
  }

  for (const session of sessions) {
    const existing = byChild.get(session.childId);
    if (!existing) continue;
    if (session.status === 'COMPLETED') {
      existing.completedSessions += 1;
      const visitAt = session.checkOutAt ?? session.checkInAt;
      if (
        visitAt &&
        (!existing.lastVisitAt || visitAt > existing.lastVisitAt)
      ) {
        existing.lastVisitAt = visitAt;
      }
    }
    if (session.status === 'PENDING_DOCUMENTATION') {
      existing.pendingDocumentation += 1;
    }
  }

  return [...byChild.values()]
    .map((entry) => {
      const c = entry.child;
      return {
        childId: c.id,
        chartNumber: chartNumberForChild(c.id),
        firstName: c.firstName,
        lastName: c.lastName,
        dateOfBirth: c.dateOfBirth,
        gender: c.gender ?? undefined,
        primaryLanguage: c.primaryLanguage ?? undefined,
        guardianName: c.guardianName ?? undefined,
        pediatricianName: c.pediatricianName ?? undefined,
        insuranceType: c.insuranceType ?? undefined,
        parentName: entry.parentName,
        therapyTypes: [...entry.therapyTypes],
        upcomingAppointments: entry.upcomingAppointments,
        completedSessions: entry.completedSessions,
        pendingDocumentation: entry.pendingDocumentation,
        lastVisitAt: entry.lastVisitAt,
      };
    })
    .sort((a, b) =>
      `${a.lastName} ${a.firstName}`.localeCompare(
        `${b.lastName} ${b.firstName}`,
      ),
    );
}
