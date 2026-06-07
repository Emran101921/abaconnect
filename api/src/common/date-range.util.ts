export type DateRangeFilter = {
  fromDate?: Date;
  toDate?: Date;
};

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
