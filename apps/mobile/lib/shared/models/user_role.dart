import 'package:equatable/equatable.dart';

enum UserRole {
  parent,
  therapist,
  agency,
  admin;

  String get displayName {
    switch (this) {
      case UserRole.parent:
        return 'Parent';
      case UserRole.therapist:
        return 'Therapist';
      case UserRole.agency:
        return 'Agency';
      case UserRole.admin:
        return 'Admin';
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
