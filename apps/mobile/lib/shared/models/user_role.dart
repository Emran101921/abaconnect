import 'package:equatable/equatable.dart';

enum UserRole {
  parent,
  therapist,
  agency,
  serviceCoordinator,
  admin,
  billing,
  complianceAuditor,
  support;

  String get displayName {
    switch (this) {
      case UserRole.parent:
        return 'Parent / Patient';
      case UserRole.therapist:
        return 'Provider / Therapist';
      case UserRole.agency:
        return 'Agency Admin';
      case UserRole.serviceCoordinator:
        return 'Service Coordinator';
      case UserRole.admin:
        return 'Super Admin';
      case UserRole.billing:
        return 'Billing Staff';
      case UserRole.complianceAuditor:
        return 'Compliance Auditor';
      case UserRole.support:
        return 'Support Staff';
    }
  }

  String get homeRoute {
    switch (this) {
      case UserRole.parent:
        return '/parent';
      case UserRole.therapist:
        return '/therapist';
      case UserRole.agency:
        return '/agency';
      case UserRole.serviceCoordinator:
        return '/service-coordinator';
      case UserRole.billing:
        return '/admin/ei-billing';
      case UserRole.complianceAuditor:
        return '/admin/compliance';
      case UserRole.support:
        return '/admin/complaints';
      case UserRole.admin:
        return '/admin';
    }
  }
}

class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
    this.fullName,
  });

  final String id;
  final String email;
  final UserRole role;
  final String? fullName;

  @override
  List<Object?> get props => [id, email, role, fullName];
}
