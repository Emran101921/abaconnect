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
import '../../features/parent/presentation/parent_profile_screen.dart';
import '../../features/parent/presentation/progress_notes_screen.dart';
import '../../features/parent/presentation/session_history_screen.dart';
import '../../features/parent/presentation/complaints_screen.dart';
import '../../features/parent/presentation/reviews_screen.dart';
import '../../features/parent/presentation/screening_screen.dart';
import '../../features/parent/presentation/treatment_plans_screen.dart';
import '../../features/compliance/presentation/consent_screen.dart';
import '../../features/documents/presentation/documents_screen.dart';
import '../../features/insurance/presentation/insurance_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/payments/presentation/payments_screen.dart';
import '../../features/telehealth/presentation/telehealth_screen.dart';
import '../../features/therapist/presentation/session_notes_screen.dart';
import '../../features/therapist/presentation/therapist_appointments_screen.dart';
import '../../features/therapist/presentation/therapist_home_screen.dart';
import '../../features/therapist/presentation/therapist_payouts_screen.dart';
import '../../features/therapist/presentation/therapist_plans_screen.dart';
import '../../features/therapist/presentation/therapist_profile_screen.dart';

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
  static const therapistProfile = '/therapist/profile';
  static const therapistAppointments = '/therapist/appointments';
  static const therapistSessionNotes = '/therapist/session-notes';
  static const agencyHome = '/agency';
  static const adminHome = '/admin';
  static const telehealth = '/telehealth';
  static const messages = '/messages';
  static const payments = '/payments';
  static const matching = '/matching';
  static const notifications = '/notifications';
  static const documents = '/documents';
  static const insurance = '/insurance';
  static const consent = '/consent';
  static const security = '/security';
  static const parentAppointments = '/parent/appointments';
  static const parentProfile = '/parent/profile';
  static const sessionHistory = '/parent/session-history';
  static const treatmentPlans = '/treatment-plans';
  static const complaints = '/complaints';
  static const therapistPlans = '/therapist/plans';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
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
            builder: (context, state) => const ParentAppointmentsScreen(),
          ),
          GoRoute(
            path: 'booking',
            name: 'parentBooking',
            builder: (context, state) => const BookingScreen(),
          ),
          GoRoute(
            path: 'screening',
            name: 'parentScreening',
            builder: (context, state) => ScreeningScreen(
              childId: state.uri.queryParameters['childId'],
              autoStart: state.uri.queryParameters['autoStart'] == 'true',
            ),
          ),
          GoRoute(
            path: 'reviews',
            name: 'parentReviews',
            builder: (context, state) => const ReviewsScreen(),
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
            builder: (context, state) => const ProgressNotesScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.therapistHome,
        name: 'therapistHome',
        builder: (context, state) => const TherapistHomeScreen(),
        routes: [
          GoRoute(
            path: 'appointments',
            name: 'therapistAppointments',
            builder: (context, state) => const TherapistAppointmentsScreen(),
          ),
          GoRoute(
            path: 'profile',
            name: 'therapistProfile',
            builder: (context, state) => const TherapistProfileScreen(),
          ),
          GoRoute(
            path: 'session-notes',
            name: 'therapistSessionNotes',
            builder: (context, state) => const SessionNotesScreen(),
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
                  detailBasePath:
                      '${AppRoutes.agencyHome}/analytics/claims',
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
                  detailBasePath:
                      '${AppRoutes.adminHome}/analytics/screenings',
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
        builder: (context, state) => const MessagesScreen(),
        routes: [
          GoRoute(
            path: ':threadId',
            name: 'messageThread',
            builder: (context, state) => MessageThreadScreen(
              threadId: state.pathParameters['threadId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.payments,
        name: 'payments',
        builder: (context, state) => const PaymentsScreen(),
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
        builder: (context, state) => const DocumentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.insurance,
        name: 'insurance',
        builder: (context, state) => const InsuranceScreen(),
      ),
      GoRoute(
        path: AppRoutes.consent,
        name: 'consent',
        builder: (context, state) => const ConsentScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Text('No route defined for ${state.uri}'),
      ),
    ),
  );
});
