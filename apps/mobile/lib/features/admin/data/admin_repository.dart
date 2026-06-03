import '../../../core/network/graphql_client.dart';

class AdminDashboardModel {
  const AdminDashboardModel({
    required this.userCount,
    required this.parentCount,
    required this.therapistCount,
    required this.appointmentCount,
    required this.pendingTherapists,
    required this.openComplaints,
  });

  final int userCount;
  final int parentCount;
  final int therapistCount;
  final int appointmentCount;
  final int pendingTherapists;
  final int openComplaints;
}

class AdminUserModel {
  const AdminUserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  final String id;
  final String email;
  final String fullName;
  final String role;
  final bool isActive;
}

class PendingTherapistModel {
  const PendingTherapistModel({
    required this.id,
    required this.displayName,
    required this.email,
    this.licenseNumber,
    this.licenseState,
  });

  final String id;
  final String displayName;
  final String email;
  final String? licenseNumber;
  final String? licenseState;
}

class AdminComplaintModel {
  const AdminComplaintModel({
    required this.id,
    required this.status,
    required this.category,
    required this.subject,
    required this.description,
    this.reporterName,
  });

  final String id;
  final String status;
  final String category;
  final String subject;
  final String description;
  final String? reporterName;
}

class AuditLogModel {
  const AuditLogModel({
    required this.id,
    required this.action,
    required this.entityType,
    required this.createdAt,
    this.actorEmail,
  });

  final String id;
  final String action;
  final String entityType;
  final DateTime createdAt;
  final String? actorEmail;
}

class AdminRepository {
  AdminRepository(this._graphql);

  final GraphqlClient _graphql;

  Future<AdminDashboardModel> fetchDashboard() async {
    const query = r'''
      query {
        adminDashboard {
          userCount
          parentCount
          therapistCount
          appointmentCount
          pendingTherapists
          openComplaints
        }
      }
    ''';
    final result = await _graphql.query(query);
    final d = result['data']?['adminDashboard'] as Map<String, dynamic>;
    return AdminDashboardModel(
      userCount: d['userCount'] as int? ?? 0,
      parentCount: d['parentCount'] as int? ?? 0,
      therapistCount: d['therapistCount'] as int? ?? 0,
      appointmentCount: d['appointmentCount'] as int? ?? 0,
      pendingTherapists: d['pendingTherapists'] as int? ?? 0,
      openComplaints: d['openComplaints'] as int? ?? 0,
    );
  }

  Future<List<AdminUserModel>> fetchUsers() async {
    const query = r'''
      query {
        adminUsers {
          id
          email
          firstName
          lastName
          role
          isActive
        }
      }
    ''';
    final result = await _graphql.query(query);
    final list = result['data']?['adminUsers'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => AdminUserModel(
            id: e['id'] as String,
            email: e['email'] as String,
            fullName: '${e['firstName']} ${e['lastName']}',
            role: e['role'] as String? ?? '',
            isActive: e['isActive'] as bool? ?? true,
          ),
        )
        .toList();
  }

  Future<List<PendingTherapistModel>> fetchPendingTherapists() async {
    const query = r'''
      query {
        pendingTherapistVerifications {
          id
          licenseNumber
          licenseState
          user { firstName lastName email }
        }
      }
    ''';
    final result = await _graphql.query(query);
    final list =
        result['data']?['pendingTherapistVerifications'] as List<dynamic>? ??
            [];
    return list.map((e) {
      final user = e['user'] as Map<String, dynamic>;
      return PendingTherapistModel(
        id: e['id'] as String,
        displayName: '${user['firstName']} ${user['lastName']}',
        email: user['email'] as String,
        licenseNumber: e['licenseNumber'] as String?,
        licenseState: e['licenseState'] as String?,
      );
    }).toList();
  }

  Future<List<AuditLogModel>> fetchAuditLogs() async {
    const query = r'''
      query {
        adminRecentAuditLogs {
          id
          action
          entityType
          createdAt
          actorEmail
        }
      }
    ''';
    final result = await _graphql.query(query);
    final list = result['data']?['adminRecentAuditLogs'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => AuditLogModel(
            id: e['id'] as String,
            action: e['action'] as String? ?? '',
            entityType: e['entityType'] as String? ?? '',
            createdAt: DateTime.parse(e['createdAt'] as String),
            actorEmail: e['actorEmail'] as String?,
          ),
        )
        .toList();
  }

  Future<List<AdminComplaintModel>> fetchComplaints() async {
    const query = r'''
      query {
        adminComplaints {
          id status category subject description reporterName
        }
      }
    ''';
    final result = await _graphql.query(query);
    final list = result['data']?['adminComplaints'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => AdminComplaintModel(
            id: e['id'] as String,
            status: e['status'] as String? ?? '',
            category: e['category'] as String? ?? '',
            subject: e['subject'] as String? ?? '',
            description: e['description'] as String? ?? '',
            reporterName: e['reporterName'] as String?,
          ),
        )
        .toList();
  }

  Future<void> resolveComplaint(String id, String resolution) async {
    const mutation = r'''
      mutation Resolve($id: ID!, $resolution: String!) {
        resolveComplaint(complaintId: $id, resolution: $resolution) { id status }
      }
    ''';
    await _graphql.query(mutation, variables: {'id': id, 'resolution': resolution});
  }

  Future<void> verifyTherapist(String therapistId) async {
    const mutation = r'''
      mutation Verify($therapistId: ID!) {
        verifyTherapist(therapistId: $therapistId) { id isVerified }
      }
    ''';
    await _graphql.query(mutation, variables: {'therapistId': therapistId});
  }
}
