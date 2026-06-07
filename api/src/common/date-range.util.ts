export const DEFAULT_ANALYTICS_WINDOW_DAYS = 30;

export type DateRangeFilter = {
  fromDate?: Date;
  toDate?: Date;
};

export type ResolvedDateBounds = {
  from: Date;
  to: Date;
};

export function startOfDay(date: Date): Date {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

export function endOfDay(date: Date): Date {
  const d = new Date(date);
  d.setHours(23, 59, 59, 999);
  return d;
}

/** Resolves explicit filters or defaults to the last 30 days (inclusive). */
export function resolveAnalyticsBounds(
  dateRange?: DateRangeFilter,
): ResolvedDateBounds {
  const today = startOfDay(new Date());
  const endOfToday = endOfDay(today);

  if (!dateRange?.fromDate && !dateRange?.toDate) {
    const from = new Date(today);
    from.setDate(from.getDate() - (DEFAULT_ANALYTICS_WINDOW_DAYS - 1));
    return { from, to: endOfToday };
  }

  const to = dateRange.toDate ? endOfDay(dateRange.toDate) : endOfToday;
  const from = dateRange.fromDate
    ? startOfDay(dateRange.fromDate)
    : (() => {
        const f = new Date(to);
        f.setDate(f.getDate() - (DEFAULT_ANALYTICS_WINDOW_DAYS - 1));
        return startOfDay(f);
      })();
  return { from, to };
}

/** Same-length window immediately before [from, to] (inclusive days). */
export function priorPeriodBounds(
  from: Date,
  to: Date,
): ResolvedDateBounds {
  const start = startOfDay(from);
  const end = endOfDay(to);
  const dayMs = 86_400_000;
  const inclusiveDays =
    Math.round((end.getTime() - start.getTime()) / dayMs) + 1;
  const priorEnd = endOfDay(new Date(start.getTime() - dayMs));
  const priorStart = startOfDay(
    new Date(priorEnd.getTime() - (inclusiveDays - 1) * dayMs),
  );
  return { from: priorStart, to: priorEnd };
}

export function prismaBoundsRange(
  field: string,
  bounds: ResolvedDateBounds,
): Record<string, { gte: Date; lte: Date }> {
  return { [field]: { gte: bounds.from, lte: bounds.to } };
}

export function prismaDateRange(
  field: string,
  { fromDate, toDate }: DateRangeFilter,
): Record<string, { gte?: Date; lte?: Date }> | Record<string, never> {
  if (!fromDate && !toDate) return {};

  const range: { gte?: Date; lte?: Date } = {};
  if (fromDate) {
    const start = new Date(fromDate);
    start.setHours(0, 0, 0, 0);
    range.gte = start;
  }
  if (toDate) {
    const end = new Date(toDate);
    end.setHours(23, 59, 59, 999);
    range.lte = end;
  }
  return { [field]: range };
}
