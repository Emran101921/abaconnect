import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/agency/presentation/agency_dashboard_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/matching/presentation/match_results_screen.dart';
import '../../features/messaging/presentation/message_thread_screen.dart';
import '../../features/messaging/presentation/messages_screen.dart';
import '../../features/parent/presentation/booking_screen.dart';
import '../../features/parent/presentation/children_list_screen.dart';
import '../../features/parent/presentation/parent_home_screen.dart';
import '../../features/parent/presentation/reviews_screen.dart';
import '../../features/parent/presentation/screening_screen.dart';
import '../../features/compliance/presentation/consent_screen.dart';
import '../../features/documents/presentation/documents_screen.dart';
import '../../features/insurance/presentation/insurance_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/payments/presentation/payments_screen.dart';
import '../../features/telehealth/presentation/telehealth_screen.dart';
import '../../features/therapist/presentation/session_notes_screen.dart';
import '../../features/therapist/presentation/therapist_appointments_screen.dart';
import '../../features/therapist/presentation/therapist_home_screen.dart';
import '../../features/therapist/presentation/therapist_profile_screen.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
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
            path: 'booking',
            name: 'parentBooking',
            builder: (context, state) => const BookingScreen(),
          ),
          GoRoute(
            path: 'screening',
            name: 'parentScreening',
            builder: (context, state) => const ScreeningScreen(),
          ),
          GoRoute(
            path: 'reviews',
            name: 'parentReviews',
            builder: (context, state) => const ReviewsScreen(),
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
        ],
      ),
      GoRoute(
        path: AppRoutes.agencyHome,
        name: 'agencyHome',
        builder: (context, state) => const AgencyDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminHome,
        name: 'adminHome',
        builder: (context, state) => const AdminDashboardScreen(),
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
        builder: (context, state) => const MatchResultsScreen(),
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
