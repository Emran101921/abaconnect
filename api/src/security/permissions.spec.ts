import { UserRole } from '../../generated/prisma/client';
import {
  Permission,
  permissionsForRole,
  roleHasPermission,
} from './permissions';

describe('permissions', () => {
  it('grants platform admin all permissions', () => {
    expect(
      roleHasPermission(UserRole.PLATFORM_ADMIN, Permission.USER_DISABLE),
    ).toBe(true);
    expect(
      roleHasPermission(UserRole.PLATFORM_ADMIN, Permission.BILLING_EXPORT),
    ).toBe(true);
  });

  it('restricts parent to own PHI and messaging', () => {
    const perms = permissionsForRole(UserRole.PARENT);
    expect(perms).toContain(Permission.PHI_READ_OWN);
    expect(perms).not.toContain(Permission.PHI_READ_TENANT);
    expect(perms).not.toContain(Permission.USER_DISABLE);
  });

  it('allows billing staff billing operations without user disable', () => {
    expect(
      roleHasPermission(UserRole.BILLING_STAFF, Permission.BILLING_SUBMIT),
    ).toBe(true);
    expect(
      roleHasPermission(UserRole.BILLING_STAFF, Permission.USER_DISABLE),
    ).toBe(false);
  });

  it('allows compliance auditor audit search only', () => {
    expect(
      roleHasPermission(UserRole.COMPLIANCE_AUDITOR, Permission.AUDIT_SEARCH),
    ).toBe(true);
    expect(
      roleHasPermission(UserRole.COMPLIANCE_AUDITOR, Permission.BILLING_WRITE),
    ).toBe(false);
  });

  it('limits support staff to support read', () => {
    expect(
      roleHasPermission(
        UserRole.SUPPORT_STAFF,
        Permission.SUPPORT_READ_LIMITED,
      ),
    ).toBe(true);
    expect(
      roleHasPermission(UserRole.SUPPORT_STAFF, Permission.PHI_READ_OWN),
    ).toBe(false);
  });
});
