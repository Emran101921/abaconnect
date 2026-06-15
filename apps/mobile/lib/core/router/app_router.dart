import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_analytics_screen.dart';
import '../../shared/presentation/analytics_detail_screens.dart';
import '../../shared/presentation/analytics_list_screens.dart';
import '../../features/admin/presentation/admin_audit_screen.dart';
import '../../features/admin/presentation/admin_complaints_screen.dart';
import '../../features/admin/presentation/admin_disputes_screen.dart';
import '../../features/admin/presentation/admin_home_screen.dart';
import '../../features/admin/presentation/admin_insurance_screen.dart';
import '../../features/admin/presentation/admin_payouts_screen.dart';
import '../../features/admin/presentation/admin_reviews_screen.dart';
import '../../features/admin/presentation/admin_users_screen.dart';
import '../../features/admin/presentation/admin_verifications_screen.dart';
import '../../features/agency/presentation/agency_analytics_screen.dart';
import '../../features/agency/presentation/agency_appointments_screen.dart';
import '../../features/agency/presentation/agency_home_screen.dart';
import '../../features/agency/presentation/agency_invites_screen.dart';
import '../../features/agency/presentation/agency_roster_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/security_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/matching/presentation/match_results_screen.dart';
import '../../features/messaging/presentation/message_thread_screen.dart';
import '../../features/messaging/presentation/messages_screen.dart';
import '../../features/parent/presentation/booking_screen.dart';
import '../../features/parent/presentation/children_list_screen.dart';
import '../../features/parent/presentation/parent_appointments_screen.dart';
import '../../features/parent/presentation/parent_home_screen.dart';
import '../../features/parent/presentation/parent_operations_category_screen.dart';
import '../../features/parent/presentation/parent_profile_screen.dart';
import '../../features/parent/presentation/progress_notes_screen.dart';
import '../../features/parent/presentation/session_history_screen.dart';
import '../../features/parent/presentation/complaints_screen.dart';
import '../../features/parent/presentation/reviews_screen.dart';
import '../../features/parent/presentation/screening_screen.dart';
import '../../features/parent/presentation/treatment_plans_screen.dart';
import '../../features/compliance/presentation/admin_compliance_screen.dart';
import '../../features/compliance/presentation/admin_security_dashboard_screen.dart';
import '../../features/compliance/presentation/legal_documents_screen.dart';
import '../../features/compliance/presentation/hipaa_privacy_notice_screen.dart';
import '../../features/compliance/presentation/phi_access_report_screen.dart';
import '../../features/compliance/presentation/privacy_center_screen.dart';
import '../../features/compliance/presentation/privacy_document_screen.dart';
import '../../features/compliance/presentation/privacy_rights_request_screen.dart';
import '../security/secure_clinical_scope.dart';
import '../../features/documents/presentation/documents_screen.dart';
import '../../features/insurance/presentation/insurance_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/payments/presentation/payments_screen.dart';
import '../../features/telehealth/presentation/telehealth_screen.dart';
import '../../features/therapist/models/session_note_editor_mode.dart';
import '../../features/therapist/presentation/eip_session_note_screen.dart';
import '../../features/therapist/presentation/session_notes_screen.dart';
import '../../features/therapist/presentation/staff_session_notes_screen.dart';
import '../../features/therapist/presentation/therapist_appointments_screen.dart';
import '../../features/therapist/presentation/provider_onboarding_screen.dart';
import '../../features/therapist/presentation/therapist_home_screen.dart';
import '../../features/therapist/presentation/therapist_payouts_screen.dart';
import '../../features/therapist/presentation/therapist_plans_screen.dart';
import '../../features/therapist/presentation/therapist_profile_screen.dart';
import '../../features/marketplace/presentation/admin_marketplace_screen.dart';
import '../../features/marketplace/presentation/marketplace_opt_in_screen.dart';
import '../../features/marketplace/presentation/parent_consent_history_screen.dart';
import '../../features/marketplace/presentation/parent_consent_share_screen.dart';
import '../../features/marketplace/presentation/parent_marketplace_dashboard_screen.dart';
import '../../features/marketplace/presentation/parent_provider_compare_screen.dart';
import '../../features/marketplace/presentation/provider_authorized_child_screen.dart';
import '../../features/marketplace/presentation/provider_marketplace_screen.dart';
import '../providers/app_providers.dart';
import '../providers/consent_gate_provider.dart';
import 'app_router_redirect.dart';
import 'router_refresh_notifier.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const register = '/register';
  static const parentHome = '/parent';
  static const parentChildren = '/parent/children';
  static const parentBooking = '/parent/booking';
  static const parentScreening = '/parent/screening';
  static const parentReviews = '/parent/reviews';
  static const therapistHome = '/therapist';
  static const providerOnboarding = '/therapist/onboarding';
  static const therapistProfile = '/therapist/profile';
  static const therapistAppointments = '/therapist/appointments';
  static const therapistSessionNotes = '/therapist/session-notes';
  static const agencyHome = '/agency';
  static const agencyMarketplace = '/agency/marketplace';
  static const adminHome = '/admin';
  static const telehealth = '/telehealth';
  static const messages = '/messages';
  static const payments = '/payments';
  static const matching = '/matching';
  static const notifications = '/notifications';
  static const documents = '/documents';
  static const insurance = '/insurance';
  static const consent = '/consent';
  static const signupPrivacyNotice = '/signup/privacy-notice';
  static const privacyNoticeOfPractices = '/privacy/notice-of-privacy-practices';
  static const privacyPolicy = '/privacy/privacy-policy';
  static const settingsPrivacy = '/settings/privacy';
  static const privacyRecordsRequest = '/settings/privacy/records-request';
  static const privacyCorrectionRequest = '/settings/privacy/correction-request';
  static const privacyRestrictionRequest = '/settings/privacy/restriction-request';
  static const privacyConfidentialCommunication =
      '/settings/privacy/confidential-communication';
  static const privacyAccountingOfDisclosures =
      '/settings/privacy/accounting-of-disclosures';
  static const privacyContactOfficer = '/settings/privacy/contact-officer';
  static const privacyDataDeletion = '/settings/privacy/data-deletion';
  static const adminCompliance = '/admin/compliance';
  static const adminComplianceNoticeVersions =
      '/admin/compliance/notice-versions';
  static const adminComplianceAcknowledgments =
      '/admin/compliance/acknowledgments';
  static const adminCompliancePrivacyRequests =
      '/admin/compliance/privacy-requests';
  static const adminComplianceAuditLogs = '/admin/compliance/audit-logs';
  static const adminSecurityDashboard = '/admin/compliance/security-dashboard';
  static const legalDocuments = '/legal-documents';
  static const legalDocumentDetail = '/legal-documents/detail';
  static const phiAccessReport = '/phi-access-report';
  static const security = '/security';
  static const parentAppointments = '/parent/appointments';
  static const parentProfile = '/parent/profile';
  static const sessionHistory = '/parent/session-history';
  static const treatmentPlans = '/treatment-plans';
  static const complaints = '/complaints';
  static const therapistPlans = '/therapist/plans';
  static const parentMarketplace = '/parent/marketplace';
  static const parentMarketplaceOptIn = '/parent/marketplace/opt-in';
  static const therapistMarketplace = '/therapist/marketplace';
  static const adminMarketplace = '/admin/marketplace';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(routerRefreshNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final hipaaConsentGranted = ref.read(hipaaConsentGrantedProvider);
      final mfaEnabled = ref.read(mfaEnabledProvider);
      final providerPhiAccessApproved =
          ref.read(providerPhiAccessApprovedProvider);
      return resolveAuthRedirect(
        auth: auth,
        matchedLocation: state.matchedLocation,
        hipaaConsentGranted: hipaaConsentGranted,
        mfaEnabled: mfaEnabled,
        providerPhiAccessApproved: providerPhiAccessApproved,
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        name: 'resetPassword',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return ResetPasswordScreen(token: token);
        },
      ),
      GoRoute(
        path: AppRoutes.security,
        name: 'security',
        builder: (context, state) => const SecurityScreen(),
      ),
      GoRoute(
        path: AppRoutes.parentHome,
        name: 'parentHome',
        builder: (context, state) => const ParentHomeScreen(),
        routes: [
          GoRoute(
            path: 'children',
            name: 'parentChildren',
            builder: (context, state) => const ChildrenListScreen(),
          ),
          GoRoute(
            path: 'appointments',
            name: 'parentAppointments',
            builder: (context, state) => ParentAppointmentsScreen(
              highlightAppointmentId: state.uri.queryParameters['id'],
            ),
          ),
          GoRoute(
            path: 'booking',
            name: 'parentBooking',
            builder: (context, state) => const BookingScreen(),
          ),
          GoRoute(
            path: 'screening',
            name: 'parentScreening',
            builder: (context, state) => SecureClinicalScope(
              child: ScreeningScreen(
                childId: state.uri.queryParameters['childId'],
                autoStart: state.uri.queryParameters['autoStart'] == 'true',
              ),
            ),
          ),
          GoRoute(
            path: 'reviews',
            name: 'parentReviews',
            builder: (context, state) => ReviewsScreen(
              initialTherapistId: state.uri.queryParameters['therapistId'],
              autoOpenSubmit: state.uri.queryParameters['submit'] == 'true',
            ),
          ),
          GoRoute(
            path: 'treatment-plans',
            name: 'parentTreatmentPlans',
            builder: (context, state) => const TreatmentPlansScreen(),
          ),
          GoRoute(
            path: 'complaints',
            name: 'parentComplaints',
            builder: (context, state) => const ComplaintsScreen(),
          ),
          GoRoute(
            path: 'profile',
            name: 'parentProfile',
            builder: (context, state) => const ParentProfileScreen(),
          ),
          GoRoute(
            path: 'session-history',
            name: 'sessionHistory',
            builder: (context, state) => const SessionHistoryScreen(),
          ),
          GoRoute(
            path: 'progress-notes',
            name: 'parentProgressNotes',
            builder: (context, state) => SecureClinicalScope(
              child: ProgressNotesScreen(
                sessionId: state.uri.queryParameters['sessionId'],
              ),
            ),
          ),
          GoRoute(
            path: 'operations/:category',
            name: 'parentOperationsCategory',
            builder: (context, state) => ParentOperationsCategoryScreen(
              categoryId: state.pathParameters['category']!,
            ),
          ),
          GoRoute(
            path: 'marketplace',
            name: 'parentMarketplace',
            builder: (context, state) =>
                const ParentMarketplaceDashboardScreen(),
            routes: [
              GoRoute(
                path: 'opt-in',
                name: 'parentMarketplaceOptIn',
                builder: (context, state) => MarketplaceOptInScreen(
                  childId: state.uri.queryParameters['childId'] ?? '',
                  screeningResponseId:
                      state.uri.queryParameters['screeningResponseId'],
                  languagePreference:
                      state.uri.queryParameters['languagePreference'],
                ),
              ),
              GoRoute(
                path: ':requestId/interests',
                name: 'parentMarketplaceInterests',
                builder: (context, state) => ParentProviderCompareScreen(
                  marketplaceRequestId: state.pathParameters['requestId']!,
                ),
              ),
              GoRoute(
                path: ':requestId/consent/:providerId',
                name: 'parentMarketplaceConsent',
                builder: (context, state) => ParentConsentShareScreen(
                  marketplaceRequestId: state.pathParameters['requestId']!,
                  providerProfileId: state.pathParameters['providerId']!,
                  providerName:
                      state.uri.queryParameters['name'] ?? 'Provider',
                ),
              ),
              GoRoute(
                path: ':requestId/consents',
                name: 'parentMarketplaceConsentHistory',
                builder: (context, state) => ParentConsentHistoryScreen(
                  marketplaceRequestId: state.pathParameters['requestId']!,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.providerOnboarding,
        name: 'providerOnboarding',
        builder: (context, state) => const ProviderOnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.therapistHome,
        name: 'therapistHome',
        builder: (context, state) => const TherapistHomeScreen(),
        routes: [
          GoRoute(
            path: 'appointments',
            name: 'therapistAppointments',
            builder: (context, state) => TherapistAppointmentsScreen(
              highlightAppointmentId: state.uri.queryParameters['id'],
            ),
          ),
          GoRoute(
            path: 'profile',
            name: 'therapistProfile',
            builder: (context, state) => const TherapistProfileScreen(),
          ),
          GoRoute(
            path: 'marketplace',
            name: 'therapistMarketplace',
            builder: (context, state) => const ProviderMarketplaceScreen(),
            routes: [
              GoRoute(
                path: ':requestId/authorized-child',
                name: 'therapistMarketplaceAuthorizedChild',
                builder: (context, state) => ProviderAuthorizedChildScreen(
                  marketplaceRequestId: state.pathParameters['requestId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'session-notes',
            name: 'therapistSessionNotes',
            builder: (context, state) => const SecureClinicalScope(
              child: SessionNotesScreen(),
            ),
            routes: [
              GoRoute(
                path: ':sessionId/form',
                name: 'therapistEipSessionNote',
                builder: (context, state) => SecureClinicalScope(
                  child: EipSessionNoteScreen(
                    sessionId: state.pathParameters['sessionId']!,
                    editorMode: SessionNoteEditorMode.therapist,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'plans',
            name: 'therapistPlans',
            builder: (context, state) => const TherapistPlansScreen(),
          ),
          GoRoute(
            path: 'payouts',
            name: 'therapistPayouts',
            builder: (context, state) => const TherapistPayoutsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.agencyHome,
        name: 'agencyHome',
        builder: (context, state) => const AgencyHomeScreen(),
        routes: [
          GoRoute(
            path: 'roster',
            name: 'agencyRoster',
            builder: (context, state) => const AgencyRosterScreen(),
          ),
          GoRoute(
            path: 'invites',
            name: 'agencyInvites',
            builder: (context, state) => const AgencyInvitesScreen(),
          ),
          GoRoute(
            path: 'analytics',
            name: 'agencyAnalytics',
            builder: (context, state) => const AgencyAnalyticsScreen(),
            routes: [
              GoRoute(
                path: 'claims/filter/:statusFilter',
                name: 'agencyAnalyticsClaimsList',
                builder: (context, state) => AgencyAnalyticsClaimsListScreen(
                  statusFilter: state.pathParameters['statusFilter']!,
                  detailBasePath: '${AppRoutes.agencyHome}/analytics/claims',
                ),
              ),
              GoRoute(
                path: 'claims/:claimId',
                name: 'agencyAnalyticsClaimDetail',
                builder: (context, state) => AgencyAnalyticsClaimDetailScreen(
                  claimId: state.pathParameters['claimId']!,
                ),
              ),
              GoRoute(
                path: 'screenings/filter/:riskFilter',
                name: 'agencyAnalyticsScreeningsList',
                builder: (context, state) =>
                    AgencyAnalyticsScreeningsListScreen(
                      riskFilter: state.pathParameters['riskFilter']!,
                      detailBasePath:
                          '${AppRoutes.agencyHome}/analytics/screenings',
                    ),
              ),
              GoRoute(
                path: 'screenings/:screeningId',
                name: 'agencyAnalyticsScreeningDetail',
                builder: (context, state) =>
                    AgencyAnalyticsScreeningDetailScreen(
                      screeningId: state.pathParameters['screeningId']!,
                    ),
              ),
            ],
          ),
          GoRoute(
            path: 'appointments',
            name: 'agencyAppointments',
            builder: (context, state) => const AgencyAppointmentsScreen(),
          ),
          GoRoute(
            path: 'marketplace',
            name: 'agencyMarketplace',
            builder: (context, state) => const ProviderMarketplaceScreen(
              shell: MarketplaceProviderShell.agency,
            ),
            routes: [
              GoRoute(
                path: ':requestId/authorized-child',
                name: 'agencyMarketplaceAuthorizedChild',
                builder: (context, state) => ProviderAuthorizedChildScreen(
                  marketplaceRequestId: state.pathParameters['requestId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'session-notes',
            name: 'agencySessionNotes',
            builder: (context, state) => SecureClinicalScope(
              child: StaffSessionNotesScreen(
                editorMode: SessionNoteEditorMode.agency,
                formRoutePrefix: '${AppRoutes.agencyHome}/session-notes',
              ),
            ),
            routes: [
              GoRoute(
                path: ':sessionId/form',
                name: 'agencyEipSessionNote',
                builder: (context, state) => SecureClinicalScope(
                  child: EipSessionNoteScreen(
                    sessionId: state.pathParameters['sessionId']!,
                    editorMode: SessionNoteEditorMode.agency,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.adminHome,
        name: 'adminHome',
        builder: (context, state) => const AdminHomeScreen(),
        routes: [
          GoRoute(
            path: 'verifications',
            name: 'adminVerifications',
            builder: (context, state) => const AdminVerificationsScreen(),
          ),
          GoRoute(
            path: 'complaints',
            name: 'adminComplaints',
            builder: (context, state) => const AdminComplaintsScreen(),
          ),
          GoRoute(
            path: 'disputes',
            name: 'adminDisputes',
            builder: (context, state) => const AdminDisputesScreen(),
          ),
          GoRoute(
            path: 'payouts',
            name: 'adminPayouts',
            builder: (context, state) => const AdminPayoutsScreen(),
          ),
          GoRoute(
            path: 'insurance',
            name: 'adminInsurance',
            builder: (context, state) => const AdminInsuranceScreen(),
          ),
          GoRoute(
            path: 'reviews',
            name: 'adminReviews',
            builder: (context, state) => const AdminReviewsScreen(),
          ),
          GoRoute(
            path: 'analytics',
            name: 'adminAnalytics',
            builder: (context, state) => const AdminAnalyticsScreen(),
            routes: [
              GoRoute(
                path: 'claims/filter/:statusFilter',
                name: 'adminAnalyticsClaimsList',
                builder: (context, state) => AdminAnalyticsClaimsListScreen(
                  statusFilter: state.pathParameters['statusFilter']!,
                  detailBasePath: '${AppRoutes.adminHome}/analytics/claims',
                ),
              ),
              GoRoute(
                path: 'claims/:claimId',
                name: 'adminAnalyticsClaimDetail',
                builder: (context, state) => AdminAnalyticsClaimDetailScreen(
                  claimId: state.pathParameters['claimId']!,
                ),
              ),
              GoRoute(
                path: 'screenings/filter/:riskFilter',
                name: 'adminAnalyticsScreeningsList',
                builder: (context, state) => AdminAnalyticsScreeningsListScreen(
                  riskFilter: state.pathParameters['riskFilter']!,
                  detailBasePath: '${AppRoutes.adminHome}/analytics/screenings',
                ),
              ),
              GoRoute(
                path: 'screenings/:screeningId',
                name: 'adminAnalyticsScreeningDetail',
                builder: (context, state) =>
                    AdminAnalyticsScreeningDetailScreen(
                      screeningId: state.pathParameters['screeningId']!,
                    ),
              ),
            ],
          ),
          GoRoute(
            path: 'users',
            name: 'adminUsers',
            builder: (context, state) => const AdminUsersScreen(),
          ),
          GoRoute(
            path: 'audit',
            name: 'adminAudit',
            builder: (context, state) => const AdminAuditScreen(),
          ),
          GoRoute(
            path: 'marketplace',
            name: 'adminMarketplace',
            builder: (context, state) => const AdminMarketplaceScreen(),
          ),
          GoRoute(
            path: 'compliance',
            name: 'adminCompliance',
            builder: (context, state) => const AdminComplianceScreen(),
            routes: [
              GoRoute(
                path: 'acknowledgments',
                name: 'adminComplianceAcknowledgments',
                builder: (context, state) =>
                    const AdminComplianceAcknowledgmentsScreen(),
              ),
              GoRoute(
                path: 'notice-versions',
                name: 'adminComplianceNoticeVersions',
                builder: (context, state) =>
                    const AdminComplianceNoticeVersionsScreen(),
              ),
              GoRoute(
                path: 'privacy-requests',
                name: 'adminCompliancePrivacyRequests',
                builder: (context, state) =>
                    const AdminCompliancePrivacyRequestsScreen(),
              ),
              GoRoute(
                path: 'audit-logs',
                name: 'adminComplianceAuditLogs',
                builder: (context, state) =>
                    const AdminComplianceAuditLogsScreen(),
              ),
              GoRoute(
                path: 'security-dashboard',
                name: 'adminSecurityDashboard',
                builder: (context, state) =>
                    const AdminSecurityDashboardScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'session-notes',
            name: 'adminSessionNotes',
            builder: (context, state) => SecureClinicalScope(
              child: StaffSessionNotesScreen(
                editorMode: SessionNoteEditorMode.admin,
                formRoutePrefix: '${AppRoutes.adminHome}/session-notes',
              ),
            ),
            routes: [
              GoRoute(
                path: ':sessionId/form',
                name: 'adminEipSessionNote',
                builder: (context, state) => SecureClinicalScope(
                  child: EipSessionNoteScreen(
                    sessionId: state.pathParameters['sessionId']!,
                    editorMode: SessionNoteEditorMode.admin,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.telehealth,
        name: 'telehealth',
        builder: (context, state) => const TelehealthScreen(),
      ),
      GoRoute(
        path: AppRoutes.messages,
        name: 'messages',
        builder: (context, state) => const SecureClinicalScope(
          child: MessagesScreen(),
        ),
        routes: [
          GoRoute(
            path: ':threadId',
            name: 'messageThread',
            builder: (context, state) => SecureClinicalScope(
              child: MessageThreadScreen(
                threadId: state.pathParameters['threadId']!,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.payments,
        name: 'payments',
        builder: (context, state) => PaymentsScreen(
          initialPaymentId: state.uri.queryParameters['paymentId'],
        ),
      ),
      GoRoute(
        path: AppRoutes.matching,
        name: 'matching',
        builder: (context, state) {
          final therapyTypes = state.uri.queryParameters['therapyTypes']
              ?.split(',')
              .where((value) => value.isNotEmpty)
              .toList();
          return MatchResultsScreen(therapyTypes: therapyTypes);
        },
      ),
      GoRoute(
        path: AppRoutes.notifications,
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.documents,
        name: 'documents',
        builder: (context, state) => const SecureClinicalScope(
          child: DocumentsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.insurance,
        name: 'insurance',
        builder: (context, state) => const InsuranceScreen(),
      ),
      GoRoute(
        path: AppRoutes.consent,
        name: 'consent',
        builder: (context, state) => const HipaaPrivacyNoticeScreen(),
      ),
      GoRoute(
        path: AppRoutes.signupPrivacyNotice,
        name: 'signupPrivacyNotice',
        builder: (context, state) => const HipaaPrivacyNoticeScreen(
          onboardingMode: false,
        ),
      ),
      GoRoute(
        path: AppRoutes.privacyNoticeOfPractices,
        name: 'privacyNoticeOfPractices',
        builder: (context, state) => const PrivacyDocumentScreen(
          kind: PrivacyDocumentKind.noticeOfPractices,
        ),
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        name: 'privacyPolicy',
        builder: (context, state) => const PrivacyDocumentScreen(
          kind: PrivacyDocumentKind.privacyPolicy,
        ),
      ),
      GoRoute(
        path: AppRoutes.legalDocuments,
        name: 'legalDocuments',
        builder: (context, state) => const LegalDocumentsScreen(),
        routes: [
          GoRoute(
            path: 'detail',
            name: 'legalDocumentDetail',
            builder: (context, state) => LegalDocumentDetailScreen(
              documentId: state.uri.queryParameters['id'] ?? '',
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.settingsPrivacy,
        name: 'settingsPrivacy',
        builder: (context, state) => const PrivacyCenterScreen(),
        routes: [
          GoRoute(
            path: 'records-request',
            name: 'privacyRecordsRequest',
            builder: (context, state) => const PrivacyRightsRequestScreen(
              formType: PrivacyRightsFormType.recordAccess,
            ),
          ),
          GoRoute(
            path: 'correction-request',
            name: 'privacyCorrectionRequest',
            builder: (context, state) => const PrivacyRightsRequestScreen(
              formType: PrivacyRightsFormType.correction,
            ),
          ),
          GoRoute(
            path: 'restriction-request',
            name: 'privacyRestrictionRequest',
            builder: (context, state) => const PrivacyRightsRequestScreen(
              formType: PrivacyRightsFormType.restriction,
            ),
          ),
          GoRoute(
            path: 'confidential-communication',
            name: 'privacyConfidentialCommunication',
            builder: (context, state) => const PrivacyRightsRequestScreen(
              formType: PrivacyRightsFormType.confidentialCommunication,
            ),
          ),
          GoRoute(
            path: 'accounting-of-disclosures',
            name: 'privacyAccountingOfDisclosures',
            builder: (context, state) => const PrivacyRightsRequestScreen(
              formType: PrivacyRightsFormType.accountingOfDisclosures,
            ),
          ),
          GoRoute(
            path: 'contact-officer',
            name: 'privacyContactOfficer',
            builder: (context, state) => const PrivacyRightsRequestScreen(
              formType: PrivacyRightsFormType.contactPrivacyOfficer,
            ),
          ),
          GoRoute(
            path: 'data-deletion',
            name: 'privacyDataDeletion',
            builder: (context, state) => const PrivacyRightsRequestScreen(
              formType: PrivacyRightsFormType.dataDeletion,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.phiAccessReport,
        name: 'phiAccessReport',
        builder: (context, state) => const PhiAccessReportScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: const Center(child: Text('Page not found')),
    ),
  );
});
