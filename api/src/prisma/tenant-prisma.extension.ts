import { Prisma } from '../../generated/prisma/client';
import { getTenantContext } from '../common/tenant/tenant-context';

const TENANT_SCOPED_MODELS = new Set([
  'Child',
  'Document',
  'ScreeningResponse',
  'ScreeningTemplate',
  'Session',
  'Appointment',
  'AuditLog',
  'Complaint',
  'Dispute',
  'InsuranceClaim',
  'TreatmentPlan',
  'Notification',
  'MessageThread',
  'Parent',
  'Therapist',
  'Agency',
]);

const READ_OPS = new Set([
  'findMany',
  'findFirst',
  'findUnique',
  'count',
  'aggregate',
  'groupBy',
]);

const WRITE_FILTER_OPS = new Set([
  'update',
  'updateMany',
  'delete',
  'deleteMany',
]);

type WhereArgs = { where?: Record<string, unknown> };

function mergeTenantWhere<T extends WhereArgs>(args: T, tenantId: string): T {
  return {
    ...args,
    where: { ...(args.where ?? {}), tenantId },
  };
}

export const tenantPrismaExtension = Prisma.defineExtension({
  query: {
    $allModels: {
      async $allOperations({ model, operation, args, query }) {
        const tenantId = getTenantContext()?.tenantId;
        if (!tenantId || !TENANT_SCOPED_MODELS.has(model)) {
          return query(args);
        }

        const mutableArgs = args as WhereArgs & {
          data?: Record<string, unknown> | Record<string, unknown>[];
          create?: Record<string, unknown>;
        };

        if (READ_OPS.has(operation)) {
          return query(mergeTenantWhere(mutableArgs, tenantId));
        }

        if (WRITE_FILTER_OPS.has(operation)) {
          return query(mergeTenantWhere(mutableArgs, tenantId));
        }

        if (operation === 'create' && mutableArgs.data) {
          const data = mutableArgs.data as Record<string, unknown>;
          if (data.tenantId == null) {
            data.tenantId = tenantId;
          }
        }

        if (operation === 'createMany' && Array.isArray(mutableArgs.data)) {
          mutableArgs.data = mutableArgs.data.map((row) =>
            (row as Record<string, unknown>).tenantId == null
              ? { ...row, tenantId }
              : row,
          ) as typeof mutableArgs.data;
        }

        if (operation === 'upsert' && mutableArgs.create) {
          const create = mutableArgs.create;
          if (create.tenantId == null) {
            create.tenantId = tenantId;
          }
        }

        return query(args);
      },
    },
  },
});
