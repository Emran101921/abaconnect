/// BloomOra agency platform module keys — must match API `AGENCY_PLATFORM_MODULE_KEYS`.
class AgencyPlatformModules {
  AgencyPlatformModules._();

  static const dashboard = 'dashboard';
  static const clients = 'clients';
  static const providers = 'providers';
  static const agencies = 'agencies';
  static const serviceCoordination = 'service_coordination';
  static const scheduling = 'scheduling';
  static const sessionNotes = 'session_notes';
  static const documents = 'documents';
  static const billing = 'billing';
  static const payroll = 'payroll';
  static const referrals = 'referrals';
  static const outreach = 'outreach';
  static const reports = 'reports';
  static const integrations = 'integrations';
  static const adminSettings = 'admin_settings';
  static const auditLogs = 'audit_logs';

  static const all = [
    dashboard,
    clients,
    providers,
    agencies,
    serviceCoordination,
    scheduling,
    sessionNotes,
    documents,
    billing,
    payroll,
    referrals,
    outreach,
    reports,
    integrations,
    adminSettings,
    auditLogs,
  ];

  static const labels = <String, String>{
    dashboard: 'Dashboard',
    clients: 'Clients',
    providers: 'Providers',
    agencies: 'Agencies',
    serviceCoordination: 'Service Coordination',
    scheduling: 'Scheduling',
    sessionNotes: 'Session Notes',
    documents: 'Documents',
    billing: 'Billing',
    payroll: 'Payroll',
    referrals: 'Referrals',
    outreach: 'Outreach',
    reports: 'Reports',
    integrations: 'Integrations',
    adminSettings: 'Admin Settings',
    auditLogs: 'Audit Logs',
  };
}

/// Full client profile tabs for Phase 1 shell (content fills in over later phases).
class ClientProfileTabs {
  ClientProfileTabs._();

  static const overview = 'Overview';
  static const family = 'Family / Contacts';
  static const program = 'Program';
  static const services = 'Services';
  static const authorizations = 'Authorizations';
  static const assignedProviders = 'Providers';
  static const insurance = 'Insurance';
  static const medical = 'Medical';
  static const diagnosis = 'Diagnosis';
  static const prescriptions = 'Prescriptions / Referrals';
  static const attendance = 'Attendance';
  static const sessions = 'Sessions';
  static const documents = 'Documents';
  static const goals = 'Goals';
  static const progressReports = 'Progress Reports';
  static const meetings = 'Meetings / Reviews';
  static const billing = 'Billing';
  static const notes = 'Notes';
  static const auditLog = 'Audit Log';

  static const all = [
    overview,
    family,
    program,
    services,
    authorizations,
    assignedProviders,
    insurance,
    medical,
    diagnosis,
    prescriptions,
    attendance,
    sessions,
    documents,
    goals,
    progressReports,
    meetings,
    billing,
    notes,
    auditLog,
  ];
}

/// Provider profile tabs for Phase 1 shell.
class ProviderProfileTabs {
  ProviderProfileTabs._();

  static const overview = 'Overview';
  static const credentials = 'Credentials';
  static const compliance = 'Compliance';
  static const caseload = 'Caseload';
  static const services = 'Services';
  static const availability = 'Availability';
  static const payroll = 'Payroll';
  static const documents = 'Documents';
  static const portalAccess = 'Portal Access';
  static const auditLog = 'Audit Log';

  static const all = [
    overview,
    credentials,
    compliance,
    caseload,
    services,
    availability,
    payroll,
    documents,
    portalAccess,
    auditLog,
  ];
}

const bloomoraComplianceDisclaimer =
    'BloomOra is a technology and care-navigation platform. It does not provide '
    'medical diagnosis, determine program eligibility, or replace professional '
    'evaluation. Final decisions must follow applicable laws, payer rules, '
    'agency policies, and professional standards.';
