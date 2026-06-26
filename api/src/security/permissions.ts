import { UserRole } from '../../generated/prisma/client';

/**
 * Fine-grained permissions mapped to HIPAA minimum-necessary access.
 * Super Admin = PLATFORM_ADMIN; Provider = THERAPIST.
 */
export enum Permission {
  ADMIN_ALL = 'admin:all',
  AUDIT_READ = 'audit:read',
  AUDIT_SEARCH = 'audit:search',
  PHI_READ_OWN = 'phi:read:own',
  PHI_READ_ASSIGNED = 'phi:read:assigned',
  PHI_READ_TENANT = 'phi:read:tenant',
  PHI_WRITE_ASSIGNED = 'phi:write:assigned',
  PHI_WRITE_TENANT = 'phi:write:tenant',
  BILLING_READ = 'billing:read',
  BILLING_WRITE = 'billing:write',
  BILLING_SUBMIT = 'billing:submit',
  BILLING_EXPORT = 'billing:export',
  USER_MANAGE = 'user:manage',
  USER_DISABLE = 'user:disable',
  COMPLIANCE_MANAGE = 'compliance:manage',
  COMPLIANCE_READ = 'compliance:read',
  MESSAGING_SEND = 'messaging:send',
  MESSAGING_READ = 'messaging:read',
  SUPPORT_READ_LIMITED = 'support:read:limited',
  AGENCY_SETTINGS_READ = 'agency:settings:read',
  AGENCY_SETTINGS_WRITE = 'agency:settings:write',
}

const ROLE_PERMISSIONS: Record<UserRole, Permission[]> = {
  [UserRole.PLATFORM_ADMIN]: Object.values(Permission),
  [UserRole.AGENCY_ADMIN]: [
    Permission.PHI_READ_TENANT,
    Permission.PHI_WRITE_TENANT,
    Permission.BILLING_READ,
    Permission.BILLING_WRITE,
    Permission.BILLING_SUBMIT,
    Permission.BILLING_EXPORT,
    Permission.USER_MANAGE,
    Permission.USER_DISABLE,
    Permission.COMPLIANCE_READ,
    Permission.MESSAGING_READ,
    Permission.MESSAGING_SEND,
    Permission.AUDIT_READ,
    Permission.AGENCY_SETTINGS_READ,
    Permission.AGENCY_SETTINGS_WRITE,
  ],
  [UserRole.DEPARTMENT_ADMIN]: [
    Permission.PHI_READ_TENANT,
    Permission.PHI_WRITE_ASSIGNED,
    Permission.MESSAGING_READ,
    Permission.MESSAGING_SEND,
    Permission.AUDIT_READ,
    Permission.AGENCY_SETTINGS_READ,
  ],
  [UserRole.PAYROLL_STAFF]: [
    Permission.BILLING_READ,
    Permission.PHI_READ_TENANT,
    Permission.AUDIT_READ,
  ],
  [UserRole.BILLING_STAFF]: [
    Permission.BILLING_READ,
    Permission.BILLING_WRITE,
    Permission.BILLING_SUBMIT,
    Permission.BILLING_EXPORT,
    Permission.PHI_READ_TENANT,
    Permission.AUDIT_READ,
  ],
  [UserRole.THERAPIST]: [
    Permission.PHI_READ_ASSIGNED,
    Permission.PHI_WRITE_ASSIGNED,
    Permission.MESSAGING_READ,
    Permission.MESSAGING_SEND,
    Permission.BILLING_READ,
  ],
  [UserRole.SERVICE_COORDINATOR]: [
    Permission.PHI_READ_ASSIGNED,
    Permission.PHI_WRITE_ASSIGNED,
    Permission.MESSAGING_READ,
    Permission.MESSAGING_SEND,
  ],
  [UserRole.PARENT]: [
    Permission.PHI_READ_OWN,
    Permission.MESSAGING_READ,
    Permission.MESSAGING_SEND,
    Permission.BILLING_READ,
  ],
  [UserRole.COMPLIANCE_AUDITOR]: [
    Permission.AUDIT_READ,
    Permission.AUDIT_SEARCH,
    Permission.COMPLIANCE_READ,
    Permission.BILLING_READ,
  ],
  [UserRole.SUPPORT_STAFF]: [
    Permission.SUPPORT_READ_LIMITED,
    Permission.MESSAGING_READ,
  ],
};

export function permissionsForRole(role: UserRole | string): Permission[] {
  return ROLE_PERMISSIONS[role as UserRole] ?? [];
}

export function roleHasPermission(
  role: UserRole | string,
  permission: Permission,
): boolean {
  const perms = permissionsForRole(role);
  return perms.includes(Permission.ADMIN_ALL) || perms.includes(permission);
}

export function roleDisplayName(role: UserRole | string): string {
  const map: Record<string, string> = {
    PLATFORM_ADMIN: 'Super Admin',
    AGENCY_ADMIN: 'Agency Admin',
    DEPARTMENT_ADMIN: 'Department Admin',
    PAYROLL_STAFF: 'Payroll Staff',
    BILLING_STAFF: 'Billing Staff',
    THERAPIST: 'Provider / Therapist',
    PARENT: 'Parent / Patient',
    COMPLIANCE_AUDITOR: 'Compliance Auditor',
    SUPPORT_STAFF: 'Support Staff',
  };
  return map[role] ?? String(role);
}
