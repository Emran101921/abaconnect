import '../../../core/network/graphql_client.dart';
import '../../../shared/models/analytics_metric.dart';

export '../../../shared/models/analytics_metric.dart';

class ClaimsPipelineSummaryModel {
  const ClaimsPipelineSummaryModel({
    required this.draftCount,
    required this.submittedCount,
    required this.pendingCount,
    required this.paidCount,
    required this.deniedCount,
    required this.priorDraftCount,
    required this.priorSubmittedCount,
    required this.priorPendingCount,
    required this.priorPaidCount,
    required this.priorDeniedCount,
  });

  final int draftCount;
  final int submittedCount;
  final int pendingCount;
  final int paidCount;
  final int deniedCount;
  final int priorDraftCount;
  final int priorSubmittedCount;
  final int priorPendingCount;
  final int priorPaidCount;
  final int priorDeniedCount;
}

class AnalyticsClaimSummaryModel {
  const AnalyticsClaimSummaryModel({
    required this.id,
    required this.status,
    required this.payerName,
    required this.billedAmount,
    required this.serviceDate,
    this.childName,
    this.claimNumber,
  });

  final String id;
  final String status;
  final String payerName;
  final double billedAmount;
  final DateTime serviceDate;
  final String? childName;
  final String? claimNumber;
}

class ClaimsPipelineDashboardModel {
  const ClaimsPipelineDashboardModel({
    required this.summary,
    required this.recentClaims,
  });

  final ClaimsPipelineSummaryModel summary;
  final List<AnalyticsClaimSummaryModel> recentClaims;
}

class ScreeningFunnelSummaryModel {
  const ScreeningFunnelSummaryModel({
    required this.completedCount,
    required this.lowRiskCount,
    required this.moderateRiskCount,
    required this.highRiskCount,
    required this.priorCompletedCount,
    required this.priorLowRiskCount,
    required this.priorModerateRiskCount,
    required this.priorHighRiskCount,
  });

  final int completedCount;
  final int lowRiskCount;
  final int moderateRiskCount;
  final int highRiskCount;
  final int priorCompletedCount;
  final int priorLowRiskCount;
  final int priorModerateRiskCount;
  final int priorHighRiskCount;
}

class AnalyticsScreeningSummaryModel {
  const AnalyticsScreeningSummaryModel({
    required this.id,
    required this.completedAt,
    this.childName,
    this.templateName,
    this.score,
    this.riskLevel,
  });

  final String id;
  final DateTime completedAt;
  final String? childName;
  final String? templateName;
  final double? score;
  final String? riskLevel;
}

class AnalyticsScreeningDetailModel {
  const AnalyticsScreeningDetailModel({
    required this.id,
    required this.completedAt,
    this.childName,
    this.templateName,
    this.score,
    this.riskLevel,
    this.responsesJson,
  });

  final String id;
  final DateTime completedAt;
  final String? childName;
  final String? templateName;
  final double? score;
  final String? riskLevel;
  final String? responsesJson;
}

class ScreeningFunnelDashboardModel {
  const ScreeningFunnelDashboardModel({
    required this.summary,
    required this.recentScreenings,
  });

  final ScreeningFunnelSummaryModel summary;
  final List<AnalyticsScreeningSummaryModel> recentScreenings;
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
    this.claimNumber,
    this.sessionId,
    this.ediReady,
    this.clearinghouseStatus,
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
  final String? claimNumber;
  final String? sessionId;
  final bool? ediReady;
  final String? clearinghouseStatus;
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

  Future<List<AnalyticsMetricModel>> fetchAnalytics({
    String? fromDate,
    String? toDate,
  }) async {
    const query = r'''
      query TenantAnalytics($fromDate: DateTime, $toDate: DateTime) {
        tenantAnalytics(fromDate: $fromDate, toDate: $toDate) {
          metricKey metricValue priorPeriodValue
        }
      }
    ''';
    final result = await _graphql.query(
      query,
      variables: {'fromDate': fromDate, 'toDate': toDate},
    );
    final list = result['data']?['tenantAnalytics'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => AnalyticsMetricModel(
            metricKey: e['metricKey'] as String? ?? '',
            metricValue: (e['metricValue'] as num?)?.toDouble() ?? 0,
            priorPeriodValue: (e['priorPeriodValue'] as num?)?.toDouble(),
          ),
        )
        .toList();
  }

  Future<ClaimsPipelineDashboardModel> fetchClaimsPipeline({
    String? fromDate,
    String? toDate,
  }) async {
    const query = r'''
      query ClaimsPipeline($fromDate: DateTime, $toDate: DateTime) {
        adminClaimsPipeline(fromDate: $fromDate, toDate: $toDate) {
          summary {
            draftCount submittedCount pendingCount paidCount deniedCount
            priorDraftCount priorSubmittedCount priorPendingCount
            priorPaidCount priorDeniedCount
          }
          recentClaims {
            id status payerName billedAmount serviceDate childName claimNumber
          }
        }
      }
    ''';
    final result = await _graphql.query(
      query,
      variables: {'fromDate': fromDate, 'toDate': toDate},
    );
    final data =
        result['data']?['adminClaimsPipeline'] as Map<String, dynamic>? ?? {};
    return _mapClaimsPipeline(data);
  }

  Future<AdminInsuranceClaimModel> fetchAnalyticsClaimDetail(String claimId) async {
    const query = r'''
      query ClaimDetail($claimId: ID!) {
        adminAnalyticsClaimDetail(claimId: $claimId) {
          id status payerName billedAmount approvedAmount serviceDate
          childName parentEmail denialReason claimNumber sessionId
          ediReady clearinghouseStatus
        }
      }
    ''';
    final result = await _graphql.query(
      query,
      variables: {'claimId': claimId},
    );
    final e = result['data']?['adminAnalyticsClaimDetail'] as Map<String, dynamic>?;
    if (e == null) throw Exception('Claim not found');
    return AdminInsuranceClaimModel(
      id: e['id'] as String,
      status: e['status'] as String? ?? '',
      payerName: e['payerName'] as String? ?? '',
      billedAmount: (e['billedAmount'] as num?)?.toDouble() ?? 0,
      approvedAmount: (e['approvedAmount'] as num?)?.toDouble(),
      serviceDate: DateTime.parse(e['serviceDate'] as String),
      childName: e['childName'] as String?,
      parentEmail: e['parentEmail'] as String?,
      denialReason: e['denialReason'] as String?,
      claimNumber: e['claimNumber'] as String?,
      sessionId: e['sessionId'] as String?,
      ediReady: e['ediReady'] as bool?,
      clearinghouseStatus: e['clearinghouseStatus'] as String?,
    );
  }

  Future<AnalyticsScreeningDetailModel> fetchAnalyticsScreeningDetail(
    String screeningId,
  ) async {
    const query = r'''
      query ScreeningDetail($screeningId: ID!) {
        adminAnalyticsScreeningDetail(screeningId: $screeningId) {
          id completedAt childName templateName score riskLevel responsesJson
        }
      }
    ''';
    final result = await _graphql.query(
      query,
      variables: {'screeningId': screeningId},
    );
    final e =
        result['data']?['adminAnalyticsScreeningDetail'] as Map<String, dynamic>?;
    if (e == null) throw Exception('Screening not found');
    return AnalyticsScreeningDetailModel(
      id: e['id'] as String,
      completedAt: DateTime.parse(e['completedAt'] as String),
      childName: e['childName'] as String?,
      templateName: e['templateName'] as String?,
      score: (e['score'] as num?)?.toDouble(),
      riskLevel: e['riskLevel'] as String?,
      responsesJson: e['responsesJson'] as String?,
    );
  }

  Future<List<AnalyticsClaimSummaryModel>> fetchAnalyticsClaimsList(
    String statusFilter, {
    int limit = 50,
    String? fromDate,
    String? toDate,
  }) async {
    const query = r'''
      query ClaimsList($statusFilter: AnalyticsClaimPipelineFilter!, $limit: Int, $fromDate: DateTime, $toDate: DateTime) {
        adminAnalyticsClaims(statusFilter: $statusFilter, limit: $limit, fromDate: $fromDate, toDate: $toDate) {
          id status payerName billedAmount serviceDate childName claimNumber
        }
      }
    ''';
    final result = await _graphql.query(
      query,
      variables: {
        'statusFilter': statusFilter,
        'limit': limit,
        'fromDate': fromDate,
        'toDate': toDate,
      },
    );
    final list = result['data']?['adminAnalyticsClaims'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => AnalyticsClaimSummaryModel(
            id: e['id'] as String,
            status: e['status'] as String? ?? '',
            payerName: e['payerName'] as String? ?? '',
            billedAmount: (e['billedAmount'] as num?)?.toDouble() ?? 0,
            serviceDate: DateTime.parse(e['serviceDate'] as String),
            childName: e['childName'] as String?,
            claimNumber: e['claimNumber'] as String?,
          ),
        )
        .toList();
  }

  Future<List<AnalyticsScreeningSummaryModel>> fetchAnalyticsScreeningsList({
    String? riskLevel,
    int limit = 50,
    String? fromDate,
    String? toDate,
  }) async {
    const query = r'''
      query ScreeningsList($riskLevel: String, $limit: Int, $fromDate: DateTime, $toDate: DateTime) {
        adminAnalyticsScreenings(riskLevel: $riskLevel, limit: $limit, fromDate: $fromDate, toDate: $toDate) {
          id completedAt childName templateName score riskLevel
        }
      }
    ''';
    final result = await _graphql.query(
      query,
      variables: {
        'riskLevel': riskLevel,
        'limit': limit,
        'fromDate': fromDate,
        'toDate': toDate,
      },
    );
    final list =
        result['data']?['adminAnalyticsScreenings'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => AnalyticsScreeningSummaryModel(
            id: e['id'] as String,
            completedAt: DateTime.parse(e['completedAt'] as String),
            childName: e['childName'] as String?,
            templateName: e['templateName'] as String?,
            score: (e['score'] as num?)?.toDouble(),
            riskLevel: e['riskLevel'] as String?,
          ),
        )
        .toList();
  }

  Future<ScreeningFunnelDashboardModel> fetchScreeningFunnel({
    String? fromDate,
    String? toDate,
  }) async {
    const query = r'''
      query ScreeningFunnel($fromDate: DateTime, $toDate: DateTime) {
        adminScreeningFunnel(fromDate: $fromDate, toDate: $toDate) {
          summary {
            completedCount lowRiskCount moderateRiskCount highRiskCount
            priorCompletedCount priorLowRiskCount priorModerateRiskCount
            priorHighRiskCount
          }
          recentScreenings {
            id completedAt childName templateName score riskLevel
          }
        }
      }
    ''';
    final result = await _graphql.query(
      query,
      variables: {'fromDate': fromDate, 'toDate': toDate},
    );
    final data =
        result['data']?['adminScreeningFunnel'] as Map<String, dynamic>? ?? {};
    return _mapScreeningFunnel(data);
  }

  ClaimsPipelineDashboardModel _mapClaimsPipeline(Map<String, dynamic> data) {
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final claims = data['recentClaims'] as List<dynamic>? ?? [];
    return ClaimsPipelineDashboardModel(
      summary: ClaimsPipelineSummaryModel(
        draftCount: summary['draftCount'] as int? ?? 0,
        submittedCount: summary['submittedCount'] as int? ?? 0,
        pendingCount: summary['pendingCount'] as int? ?? 0,
        paidCount: summary['paidCount'] as int? ?? 0,
        deniedCount: summary['deniedCount'] as int? ?? 0,
        priorDraftCount: summary['priorDraftCount'] as int? ?? 0,
        priorSubmittedCount: summary['priorSubmittedCount'] as int? ?? 0,
        priorPendingCount: summary['priorPendingCount'] as int? ?? 0,
        priorPaidCount: summary['priorPaidCount'] as int? ?? 0,
        priorDeniedCount: summary['priorDeniedCount'] as int? ?? 0,
      ),
      recentClaims: claims
          .map(
            (e) => AnalyticsClaimSummaryModel(
              id: e['id'] as String,
              status: e['status'] as String? ?? '',
              payerName: e['payerName'] as String? ?? '',
              billedAmount: (e['billedAmount'] as num?)?.toDouble() ?? 0,
              serviceDate: DateTime.parse(e['serviceDate'] as String),
              childName: e['childName'] as String?,
              claimNumber: e['claimNumber'] as String?,
            ),
          )
          .toList(),
    );
  }

  ScreeningFunnelDashboardModel _mapScreeningFunnel(Map<String, dynamic> data) {
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final screenings = data['recentScreenings'] as List<dynamic>? ?? [];
    return ScreeningFunnelDashboardModel(
      summary: ScreeningFunnelSummaryModel(
        completedCount: summary['completedCount'] as int? ?? 0,
        lowRiskCount: summary['lowRiskCount'] as int? ?? 0,
        moderateRiskCount: summary['moderateRiskCount'] as int? ?? 0,
        highRiskCount: summary['highRiskCount'] as int? ?? 0,
        priorCompletedCount: summary['priorCompletedCount'] as int? ?? 0,
        priorLowRiskCount: summary['priorLowRiskCount'] as int? ?? 0,
        priorModerateRiskCount: summary['priorModerateRiskCount'] as int? ?? 0,
        priorHighRiskCount: summary['priorHighRiskCount'] as int? ?? 0,
      ),
      recentScreenings: screenings
          .map(
            (e) => AnalyticsScreeningSummaryModel(
              id: e['id'] as String,
              completedAt: DateTime.parse(e['completedAt'] as String),
              childName: e['childName'] as String?,
              templateName: e['templateName'] as String?,
              score: (e['score'] as num?)?.toDouble(),
              riskLevel: e['riskLevel'] as String?,
            ),
          )
          .toList(),
    );
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
          claimNumber sessionId ediReady clearinghouseStatus
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
            claimNumber: e['claimNumber'] as String?,
            sessionId: e['sessionId'] as String?,
            ediReady: e['ediReady'] as bool?,
            clearinghouseStatus: e['clearinghouseStatus'] as String?,
          ),
        )
        .toList();
  }

  Future<void> submitClaimToClearinghouse(String claimId) async {
    const mutation = r'''
      mutation Submit($claimId: String!) {
        submitInsuranceClaimToClearinghouse(claimId: $claimId) { id status }
      }
    ''';
    await _graphql.query(mutation, variables: {'claimId': claimId});
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
