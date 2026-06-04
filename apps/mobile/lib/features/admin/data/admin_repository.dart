import '../../../core/network/graphql_client.dart';

class AnalyticsMetricModel {
  const AnalyticsMetricModel({
    required this.metricKey,
    required this.metricValue,
  });

  final String metricKey;
  final double metricValue;
}

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

class AdminReviewModel {
  const AdminReviewModel({
    required this.id,
    required this.rating,
    required this.isPublished,
    required this.createdAt,
    this.title,
    this.comment,
    this.therapistName,
    this.authorEmail,
  });

  final String id;
  final int rating;
  final bool isPublished;
  final DateTime createdAt;
  final String? title;
  final String? comment;
  final String? therapistName;
  final String? authorEmail;
}

class AdminInsuranceClaimModel {
  const AdminInsuranceClaimModel({
    required this.id,
    required this.status,
    required this.payerName,
    required this.billedAmount,
    required this.serviceDate,
    this.approvedAmount,
    this.childName,
    this.parentEmail,
    this.denialReason,
  });

  final String id;
  final String status;
  final String payerName;
  final double billedAmount;
  final DateTime serviceDate;
  final double? approvedAmount;
  final String? childName;
  final String? parentEmail;
  final String? denialReason;
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

  Future<List<AnalyticsMetricModel>> fetchAnalytics() async {
    const query = r'''
      query {
        tenantAnalytics { metricKey metricValue }
      }
    ''';
    final result = await _graphql.query(query);
    final list = result['data']?['tenantAnalytics'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => AnalyticsMetricModel(
            metricKey: e['metricKey'] as String? ?? '',
            metricValue: (e['metricValue'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList();
  }

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

  Future<List<AdminReviewModel>> fetchReviews() async {
    const query = r'''
      query {
        adminReviews {
          id rating title comment isPublished createdAt therapistName authorEmail
        }
      }
    ''';
    final result = await _graphql.query(query);
    final list = result['data']?['adminReviews'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => AdminReviewModel(
            id: e['id'] as String,
            rating: e['rating'] as int? ?? 0,
            isPublished: e['isPublished'] as bool? ?? true,
            createdAt: DateTime.parse(e['createdAt'] as String),
            title: e['title'] as String?,
            comment: e['comment'] as String?,
            therapistName: e['therapistName'] as String?,
            authorEmail: e['authorEmail'] as String?,
          ),
        )
        .toList();
  }

  Future<void> moderateReview(String reviewId, bool publish) async {
    const mutation = r'''
      mutation Moderate($reviewId: ID!, $publish: Boolean!) {
        moderateReview(reviewId: $reviewId, publish: $publish) { id isPublished }
      }
    ''';
    await _graphql.query(
      mutation,
      variables: {'reviewId': reviewId, 'publish': publish},
    );
  }

  Future<void> setUserActive({
    required String userId,
    required bool isActive,
  }) async {
    const mutation = r'''
      mutation SetActive($input: SetUserActiveInput!) {
        setUserActive(input: $input) { id isActive }
      }
    ''';
    await _graphql.query(
      mutation,
      variables: {
        'input': {'userId': userId, 'isActive': isActive},
      },
    );
  }

  Future<void> verifyTherapist(String therapistId) async {
    const mutation = r'''
      mutation Verify($therapistId: ID!) {
        verifyTherapist(therapistId: $therapistId) { id isVerified }
      }
    ''';
    await _graphql.query(mutation, variables: {'therapistId': therapistId});
  }

  Future<List<AdminInsuranceClaimModel>> fetchInsuranceClaims() async {
    const query = r'''
      query {
        adminInsuranceClaims {
          id status payerName billedAmount approvedAmount serviceDate
          childName parentEmail denialReason
        }
      }
    ''';
    final result = await _graphql.query(query);
    final list =
        result['data']?['adminInsuranceClaims'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => AdminInsuranceClaimModel(
            id: e['id'] as String,
            status: e['status'] as String? ?? '',
            payerName: e['payerName'] as String? ?? '',
            billedAmount: (e['billedAmount'] as num?)?.toDouble() ?? 0,
            approvedAmount: (e['approvedAmount'] as num?)?.toDouble(),
            serviceDate: DateTime.parse(e['serviceDate'] as String),
            childName: e['childName'] as String?,
            parentEmail: e['parentEmail'] as String?,
            denialReason: e['denialReason'] as String?,
          ),
        )
        .toList();
  }

  Future<void> updateInsuranceClaim({
    required String claimId,
    required String status,
    String? denialReason,
    double? approvedAmount,
  }) async {
    const mutation = r'''
      mutation Update($input: UpdateInsuranceClaimInput!) {
        updateInsuranceClaim(input: $input) { id status }
      }
    ''';
    await _graphql.query(
      mutation,
      variables: {
        'input': {
          'claimId': claimId,
          'status': status,
          if (denialReason != null) 'denialReason': denialReason,
          if (approvedAmount != null) 'approvedAmount': approvedAmount,
        },
      },
    );
  }
}
