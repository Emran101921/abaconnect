import { AsyncLocalStorage } from 'async_hooks';

export interface TenantContextStore {
  tenantId?: string;
  userId?: string;
}

export const tenantContextStorage = new AsyncLocalStorage<TenantContextStore>();

export function getTenantContext(): TenantContextStore | undefined {
  return tenantContextStorage.getStore();
}

export function requireTenantId(): string {
  const tenantId = tenantContextStorage.getStore()?.tenantId;
  if (!tenantId) {
    throw new Error('Tenant context is required for this operation');
  }
  return tenantId;
}
