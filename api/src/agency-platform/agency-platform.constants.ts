export const AGENCY_PLATFORM_MODULE_KEYS = [
  'dashboard',
  'clients',
  'providers',
  'agencies',
  'service_coordination',
  'scheduling',
  'session_notes',
  'documents',
  'billing',
  'payroll',
  'referrals',
  'outreach',
  'reports',
  'integrations',
  'admin_settings',
  'audit_logs',
] as const;

export type AgencyPlatformModuleKey =
  (typeof AGENCY_PLATFORM_MODULE_KEYS)[number];

export const AGENCY_PLATFORM_MODULE_LABELS: Record<
  AgencyPlatformModuleKey,
  string
> = {
  dashboard: 'Dashboard',
  clients: 'Clients',
  providers: 'Providers',
  agencies: 'Agencies',
  service_coordination: 'Service Coordination',
  scheduling: 'Scheduling',
  session_notes: 'Session Notes',
  documents: 'Documents',
  billing: 'Billing',
  payroll: 'Payroll',
  referrals: 'Referrals',
  outreach: 'Outreach',
  reports: 'Reports',
  integrations: 'Integrations',
  admin_settings: 'Admin Settings',
  audit_logs: 'Audit Logs',
};

export const DEFAULT_ENABLED_MODULES: Record<
  AgencyPlatformModuleKey,
  boolean
> = {
  dashboard: true,
  clients: true,
  providers: true,
  agencies: true,
  service_coordination: true,
  scheduling: true,
  session_notes: true,
  documents: true,
  billing: true,
  payroll: false,
  referrals: true,
  outreach: false,
  reports: true,
  integrations: false,
  admin_settings: true,
  audit_logs: true,
};

export const PERMISSION_SCOPE_TYPES = [
  'ROLE',
  'DEPARTMENT',
  'PROGRAM',
  'USER',
] as const;

export type PermissionScopeType = (typeof PERMISSION_SCOPE_TYPES)[number];

export const BLOOMORA_COMPLIANCE_DISCLAIMER =
  'BloomOra is a technology and care-navigation platform. It does not provide medical diagnosis, determine program eligibility, or replace professional evaluation. Final decisions must follow applicable laws, payer rules, agency policies, and professional standards.';

export const INTEGRATION_CATALOG = [
  {
    key: 'edi_837',
    label: '837 Professional Claims',
    category: 'clearinghouse',
    description: 'Generate and submit professional billing files.',
  },
  {
    key: 'edi_835',
    label: '835 Remittance',
    category: 'clearinghouse',
    description: 'Process payer remittance and payment files.',
  },
  {
    key: 'edi_278',
    label: '278 Authorization',
    category: 'clearinghouse',
    description: 'Authorization request and response workflows.',
  },
  {
    key: 'ny_eis',
    label: 'NY EIS / EI-Hub',
    category: 'municipality',
    description: 'New York Early Intervention state systems.',
  },
  {
    key: 'promise',
    label: 'PROMISe (PA)',
    category: 'municipality',
    description: 'Pennsylvania PROMISe fiscal agent workflows.',
  },
  {
    key: 'tkids',
    label: 'TKIDS',
    category: 'municipality',
    description: 'Texas ECI TKIDS-compatible exports.',
  },
  {
    key: 'payroll_export',
    label: 'Payroll company export',
    category: 'payroll',
    description: 'CSV/API exports for external payroll vendors.',
  },
] as const;
