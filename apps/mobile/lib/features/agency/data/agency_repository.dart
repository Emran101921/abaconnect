import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/graphql_client.dart';
import '../../../core/utils/document_upload.dart';
import '../../../core/utils/file_download.dart';
import '../../../shared/models/analytics_metric.dart';
import '../../therapist/models/eip_session_note_model.dart';
import '../../parent/data/parent_booking_repository.dart';

class AgencyDashboardModel {
  const AgencyDashboardModel({
    required this.therapistCount,
    required this.activeClients,
    required this.appointmentsToday,
    required this.pendingTherapists,
    required this.missingEvvCount,
    required this.draftClaimsCount,
    required this.cancellationsToday,
    required this.serviceCoordinatorCount,
    required this.activeScCaseload,
    required this.urgentScCases,
    required this.scFollowUpsDue,
    this.actionItems = const [],
  });

  final int therapistCount;
  final int activeClients;
  final int appointmentsToday;
  final int pendingTherapists;
  final int missingEvvCount;
  final int draftClaimsCount;
  final int cancellationsToday;
  final int serviceCoordinatorCount;
  final int activeScCaseload;
  final int urgentScCases;
  final int scFollowUpsDue;
  final List<Map<String, dynamic>> actionItems;
}

class AgencyAppointmentModel {
  const AgencyAppointmentModel({
    required this.id,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.therapyType,
    required this.status,
    required this.locationType,
    required this.childName,
    required this.therapistName,
  });

  final String id;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final String therapyType;
  final String status;
  final String locationType;
  final String childName;
  final String therapistName;
}

class StaffSessionNoteSummaryModel {
  const StaffSessionNoteSummaryModel({
    required this.sessionId,
    this.childId,
    required this.childName,
    required this.therapistName,
    this.sessionDate,
    required this.isFullySigned,
    this.hasServiceLog = false,
    this.awaitingParentSignature = false,
    this.therapistId,
  });

  final String sessionId;
  final String? childId;
  final String? therapistId;
  final String childName;
  final String therapistName;
  final String? sessionDate;
  final bool isFullySigned;
  final bool hasServiceLog;
  final bool awaitingParentSignature;
}

class AgencyTherapistModel {
  const AgencyTherapistModel({
    required this.id,
    required this.displayName,
    required this.isVerified,
    this.licenseNumber,
    this.rosterStatus,
    this.onboardingStatus,
    this.email,
  });

  final String id;
  final String displayName;
  final bool isVerified;
  final String? licenseNumber;
  final String? rosterStatus;
  final String? onboardingStatus;
  final String? email;

  bool get isPendingRoster =>
      rosterStatus == 'PENDING' || rosterStatus == null;
}

class AgencyProfileModel {
  const AgencyProfileModel({
    required this.id,
    required this.name,
    this.ein,
    this.phone,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.zipCode,
    this.email,
    this.website,
    required this.onboardingComplete,
    this.documents = const [],
  });

  final String id;
  final String name;
  final String? ein;
  final String? phone;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? email;
  final String? website;
  final bool onboardingComplete;
  final List<AgencyDocumentModel> documents;
}

class AgencyDocumentModel {
  const AgencyDocumentModel({
    required this.id,
    required this.type,
    required this.title,
    required this.fileName,
    required this.uploadedAt,
  });

  final String id;
  final String type;
  final String title;
  final String fileName;
  final DateTime uploadedAt;
}

class AgencyOnboardingStatusModel {
  const AgencyOnboardingStatusModel({
    required this.profileComplete,
    required this.documentsComplete,
    required this.onboardingComplete,
    required this.missingDocuments,
    required this.canComplete,
    required this.uploadedDocumentTypes,
  });

  final bool profileComplete;
  final bool documentsComplete;
  final bool onboardingComplete;
  final List<String> missingDocuments;
  final bool canComplete;
  final List<String> uploadedDocumentTypes;
}

class AgencyClaimsPipelineSummaryModel {
  const AgencyClaimsPipelineSummaryModel({
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
    required this.paidAmountTotal,
    required this.priorPaidAmountTotal,
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
  final double paidAmountTotal;
  final double priorPaidAmountTotal;
}

class AgencyClaimSummaryModel {
  const AgencyClaimSummaryModel({
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

class AgencyClaimsPipelineModel {
  const AgencyClaimsPipelineModel({
    required this.summary,
    required this.recentClaims,
  });

  final AgencyClaimsPipelineSummaryModel summary;
  final List<AgencyClaimSummaryModel> recentClaims;
}

class AgencyScreeningFunnelSummaryModel {
  const AgencyScreeningFunnelSummaryModel({
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

class AgencyScreeningSummaryModel {
  const AgencyScreeningSummaryModel({
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

class AgencyClaimDetailModel {
  const AgencyClaimDetailModel({
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

class AgencyScreeningDetailModel {
  const AgencyScreeningDetailModel({
    required this.id,
    required this.completedAt,
    this.childName,
    this.templateName,
    this.score,
    this.riskLevel,
    this.responsesJson,
    this.recommendationsJson,
    this.consentGrantedAt,
    this.evaluationRequestedAt,
    this.childProfileSummaryJson,
    this.sectionAnswersJson,
  });

  final String id;
  final DateTime completedAt;
  final String? childName;
  final String? templateName;
  final double? score;
  final String? riskLevel;
  final String? responsesJson;
  final String? recommendationsJson;
  final DateTime? consentGrantedAt;
  final DateTime? evaluationRequestedAt;
  final String? childProfileSummaryJson;
  final String? sectionAnswersJson;
}

class AgencyScreeningFunnelModel {
  const AgencyScreeningFunnelModel({
    required this.summary,
    required this.recentScreenings,
  });

  final AgencyScreeningFunnelSummaryModel summary;
  final List<AgencyScreeningSummaryModel> recentScreenings;
}

class AgencyRepository {
  AgencyRepository(this._graphql, this._api);

  final GraphqlClient _graphql;
  final ApiClient _api;

  static const _dashboardQuery = r'''
    query AgencyDashboard {
      agencyDashboard {
        therapistCount
        activeClients
        appointmentsToday
        pendingTherapists
        missingEvvCount
        draftClaimsCount
        cancellationsToday
        serviceCoordinatorCount
        activeScCaseload
        urgentScCases
        scFollowUpsDue
        actionItems {
          id title subtitle actionType priority
          threadId appointmentId sessionId claimId
        }
      }
    }
  ''';

  static const _therapistsQuery = r'''
    query AgencyTherapists {
      agencyTherapists {
        id
        isVerified
        licenseNumber
        rosterStatus
        onboardingStatus
        user { firstName lastName email }
      }
    }
  ''';

  Future<AgencyDashboardModel> fetchDashboard() async {
    final result = await _graphql.query(_dashboardQuery);
    final data = result['data']?['agencyDashboard'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Failed to load agency dashboard');
    }
    return AgencyDashboardModel(
      therapistCount: data['therapistCount'] as int? ?? 0,
      activeClients: data['activeClients'] as int? ?? 0,
      appointmentsToday: data['appointmentsToday'] as int? ?? 0,
      pendingTherapists: data['pendingTherapists'] as int? ?? 0,
      missingEvvCount: data['missingEvvCount'] as int? ?? 0,
      draftClaimsCount: data['draftClaimsCount'] as int? ?? 0,
      cancellationsToday: data['cancellationsToday'] as int? ?? 0,
      serviceCoordinatorCount: data['serviceCoordinatorCount'] as int? ?? 0,
      activeScCaseload: data['activeScCaseload'] as int? ?? 0,
      urgentScCases: data['urgentScCases'] as int? ?? 0,
      scFollowUpsDue: data['scFollowUpsDue'] as int? ?? 0,
      actionItems: (data['actionItems'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>(),
    );
  }

  static const _availableInviteQuery = r'''
    query AvailableInvite {
      agencyTherapistsAvailableToInvite {
        id
        isVerified
        licenseNumber
        user { firstName lastName }
      }
    }
  ''';

  static const _inviteMutation = r'''
    mutation Invite($therapistId: ID!) {
      inviteAgencyTherapist(therapistId: $therapistId) {
        id
        isVerified
      }
    }
  ''';

  Future<List<AgencyTherapistModel>> fetchAvailableToInvite() async {
    final result = await _graphql.query(_availableInviteQuery);
    final list =
        result['data']?['agencyTherapistsAvailableToInvite']
            as List<dynamic>? ??
        [];
    return list.map(_mapTherapist).toList();
  }

  Future<void> removeTherapist(String therapistId) async {
    await _graphql.query(
      r'''
      mutation Remove($therapistId: ID!) {
        removeAgencyTherapist(therapistId: $therapistId)
      }
    ''',
      variables: {'therapistId': therapistId},
    );
  }

  Future<void> inviteTherapist(String therapistId) async {
    await _graphql.query(
      _inviteMutation,
      variables: {'therapistId': therapistId},
    );
  }

  static const _upcomingAppointmentsQuery = r'''
    query AgencyUpcoming {
      agencyUpcomingAppointments {
        id
        scheduledStart
        scheduledEnd
        therapyType
        status
        locationType
        childName
        therapistName
      }
    }
  ''';

  Future<List<AgencyAppointmentModel>> fetchUpcomingAppointments() async {
    final result = await _graphql.query(_upcomingAppointmentsQuery);
    final list =
        result['data']?['agencyUpcomingAppointments'] as List<dynamic>? ?? [];
    return list.map((e) {
      return AgencyAppointmentModel(
        id: e['id'] as String,
        scheduledStart: DateTime.parse(e['scheduledStart'] as String),
        scheduledEnd: DateTime.parse(e['scheduledEnd'] as String),
        therapyType: e['therapyType'] as String? ?? '',
        status: e['status'] as String? ?? '',
        locationType: e['locationType'] as String? ?? '',
        childName: e['childName'] as String? ?? '',
        therapistName: e['therapistName'] as String? ?? '',
      );
    }).toList();
  }

  Future<List<AgencyTherapistModel>> fetchTherapists() async {
    final result = await _graphql.query(_therapistsQuery);
    final list = result['data']?['agencyTherapists'] as List<dynamic>? ?? [];
    return list.map(_mapTherapist).toList();
  }

  AgencyTherapistModel _mapTherapist(dynamic e) {
    final user = e['user'] as Map<String, dynamic>?;
    final name = user != null
        ? '${user['firstName']} ${user['lastName']}'
        : 'Therapist';
    return AgencyTherapistModel(
      id: e['id'] as String,
      displayName: name,
      isVerified: e['isVerified'] as bool? ?? false,
      licenseNumber: e['licenseNumber'] as String?,
      rosterStatus: e['rosterStatus'] as String?,
      onboardingStatus: e['onboardingStatus'] as String?,
      email: user?['email'] as String?,
    );
  }

  Future<AgencyProfileModel> fetchAgencyProfile() async {
    const query = r'''
      query AgencyProfile {
        agencyProfile {
          id name ein phone addressLine1 addressLine2 city state zipCode
          email website onboardingComplete
          documents { id type title fileName uploadedAt }
        }
      }
    ''';
    final result = await _graphql.query(query);
    final data = result['data']?['agencyProfile'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Failed to load agency profile');
    return _mapAgencyProfile(data);
  }

  Future<AgencyProfileModel> updateAgencyProfile({
    required String name,
    String? ein,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? zipCode,
    String? email,
    String? website,
  }) async {
    const mutation = r'''
      mutation UpdateProfile($input: UpdateAgencyProfileInput!) {
        updateAgencyProfile(input: $input) {
          id name ein phone addressLine1 addressLine2 city state zipCode
          email website onboardingComplete
          documents { id type title fileName uploadedAt }
        }
      }
    ''';
    final result = await _graphql.query(
      mutation,
      variables: {
        'input': {
          'name': name,
          'ein': ein,
          'phone': phone,
          'addressLine1': addressLine1,
          'addressLine2': addressLine2,
          'city': city,
          'state': state,
          'zipCode': zipCode,
          'email': email,
          'website': website,
        },
      },
    );
    final data =
        result['data']?['updateAgencyProfile'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Failed to update agency profile');
    return _mapAgencyProfile(data);
  }

  Future<AgencyOnboardingStatusModel> fetchOnboardingStatus() async {
    const query = r'''
      query AgencyOnboardingStatus {
        agencyOnboardingStatus {
          profileComplete documentsComplete onboardingComplete
          missingDocuments canComplete uploadedDocumentTypes
        }
      }
    ''';
    final result = await _graphql.query(query);
    final data =
        result['data']?['agencyOnboardingStatus'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Failed to load onboarding status');
    return AgencyOnboardingStatusModel(
      profileComplete: data['profileComplete'] as bool? ?? false,
      documentsComplete: data['documentsComplete'] as bool? ?? false,
      onboardingComplete: data['onboardingComplete'] as bool? ?? false,
      missingDocuments: (data['missingDocuments'] as List<dynamic>? ?? [])
          .cast<String>(),
      canComplete: data['canComplete'] as bool? ?? false,
      uploadedDocumentTypes:
          (data['uploadedDocumentTypes'] as List<dynamic>? ?? [])
              .cast<String>(),
    );
  }

  Future<AgencyOnboardingStatusModel> completeAgencyOnboarding() async {
    const mutation = r'''
      mutation CompleteAgencyOnboarding {
        completeAgencyOnboarding {
          profileComplete documentsComplete onboardingComplete
          missingDocuments canComplete uploadedDocumentTypes
        }
      }
    ''';
    final result = await _graphql.query(mutation);
    final data =
        result['data']?['completeAgencyOnboarding'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Failed to complete onboarding');
    return AgencyOnboardingStatusModel(
      profileComplete: data['profileComplete'] as bool? ?? false,
      documentsComplete: data['documentsComplete'] as bool? ?? false,
      onboardingComplete: data['onboardingComplete'] as bool? ?? false,
      missingDocuments: (data['missingDocuments'] as List<dynamic>? ?? [])
          .cast<String>(),
      canComplete: data['canComplete'] as bool? ?? false,
      uploadedDocumentTypes:
          (data['uploadedDocumentTypes'] as List<dynamic>? ?? [])
              .cast<String>(),
    );
  }

  Future<void> uploadAgencyDocument({
    required String type,
    required String title,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final ext = fileName.contains('.') ? fileName.split('.').last : null;
    final validationError = validateDocumentUpload(
      extension: ext,
      mimeType: mimeType,
    );
    if (validationError != null) {
      throw Exception(validationError);
    }

    try {
      await _api.dio.post(
        '/agencies/documents/upload',
        data: FormData.fromMap({
          'type': type,
          'title': title,
          'file': MultipartFile.fromBytes(
            bytes,
            filename: fileName,
            contentType: DioMediaType.parse(mimeType),
          ),
        }),
        options: Options(contentType: 'multipart/form-data'),
      );
    } catch (e) {
      throw Exception(formatUploadError(e));
    }
  }

  Future<void> createAgencyStaff({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    String? licenseNumber,
    String? licenseState,
    String? npi,
  }) async {
    const mutation = r'''
      mutation CreateStaff($input: CreateAgencyStaffInput!) {
        createAgencyStaff(input: $input) { id email firstName lastName }
      }
    ''';
    await _graphql.query(
      mutation,
      variables: {
        'input': {
          'email': email,
          'password': password,
          'firstName': firstName,
          'lastName': lastName,
          'phone': phone,
          'licenseNumber': licenseNumber,
          'licenseState': licenseState,
          'npi': npi,
        },
      },
    );
  }

  Future<void> approveAgencyStaff(String therapistId) async {
    const mutation = r'''
      mutation Approve($therapistId: ID!) {
        approveAgencyStaff(therapistId: $therapistId) { id rosterStatus }
      }
    ''';
    await _graphql.query(mutation, variables: {'therapistId': therapistId});
  }

  AgencyProfileModel _mapAgencyProfile(Map<String, dynamic> data) {
    final docs = data['documents'] as List<dynamic>? ?? [];
    return AgencyProfileModel(
      id: data['id'] as String,
      name: data['name'] as String? ?? '',
      ein: data['ein'] as String?,
      phone: data['phone'] as String?,
      addressLine1: data['addressLine1'] as String?,
      addressLine2: data['addressLine2'] as String?,
      city: data['city'] as String?,
      state: data['state'] as String?,
      zipCode: data['zipCode'] as String?,
      email: data['email'] as String?,
      website: data['website'] as String?,
      onboardingComplete: data['onboardingComplete'] as bool? ?? false,
      documents: docs
          .map(
            (d) => AgencyDocumentModel(
              id: d['id'] as String,
              type: d['type'] as String? ?? 'OTHER',
              title: d['title'] as String? ?? '',
              fileName: d['fileName'] as String? ?? '',
              uploadedAt: DateTime.parse(d['uploadedAt'] as String),
            ),
          )
          .toList(),
    );
  }

  Future<List<AnalyticsMetricModel>> fetchTenantAnalytics({
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

  Future<AgencyClaimsPipelineModel> fetchClaimsPipeline({
    String? fromDate,
    String? toDate,
  }) async {
    const query = r'''
      query ClaimsPipeline($fromDate: DateTime, $toDate: DateTime) {
        agencyClaimsPipeline(fromDate: $fromDate, toDate: $toDate) {
          summary {
            draftCount submittedCount pendingCount paidCount deniedCount
            priorDraftCount priorSubmittedCount priorPendingCount
            priorPaidCount priorDeniedCount
            paidAmountTotal priorPaidAmountTotal
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
        result['data']?['agencyClaimsPipeline'] as Map<String, dynamic>? ?? {};
    return _mapClaimsPipeline(data);
  }

  Future<AgencyClaimDetailModel> fetchAnalyticsClaimDetail(
    String claimId,
  ) async {
    const query = r'''
      query ClaimDetail($claimId: ID!) {
        agencyAnalyticsClaimDetail(claimId: $claimId) {
          id status payerName billedAmount approvedAmount serviceDate
          childName parentEmail denialReason claimNumber sessionId
          ediReady clearinghouseStatus
        }
      }
    ''';
    final result = await _graphql.query(query, variables: {'claimId': claimId});
    final e =
        result['data']?['agencyAnalyticsClaimDetail'] as Map<String, dynamic>?;
    if (e == null) throw Exception('Claim not found');
    return AgencyClaimDetailModel(
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

  Future<AgencyScreeningDetailModel> fetchAnalyticsScreeningDetail(
    String screeningId,
  ) async {
    const query = r'''
      query ScreeningDetail($screeningId: ID!) {
        agencyAnalyticsScreeningDetail(screeningId: $screeningId) {
          id completedAt childName templateName score riskLevel responsesJson
          recommendationsJson consentGrantedAt evaluationRequestedAt
          childProfileSummaryJson sectionAnswersJson
        }
      }
    ''';
    final result = await _graphql.query(
      query,
      variables: {'screeningId': screeningId},
    );
    final e =
        result['data']?['agencyAnalyticsScreeningDetail']
            as Map<String, dynamic>?;
    if (e == null) throw Exception('Screening not found');
    return AgencyScreeningDetailModel(
      id: e['id'] as String,
      completedAt: DateTime.parse(e['completedAt'] as String),
      childName: e['childName'] as String?,
      templateName: e['templateName'] as String?,
      score: (e['score'] as num?)?.toDouble(),
      riskLevel: e['riskLevel'] as String?,
      responsesJson: e['responsesJson'] as String?,
      recommendationsJson: e['recommendationsJson'] as String?,
      consentGrantedAt: e['consentGrantedAt'] != null
          ? DateTime.parse(e['consentGrantedAt'] as String)
          : null,
      evaluationRequestedAt: e['evaluationRequestedAt'] != null
          ? DateTime.parse(e['evaluationRequestedAt'] as String)
          : null,
      childProfileSummaryJson: e['childProfileSummaryJson'] as String?,
      sectionAnswersJson: e['sectionAnswersJson'] as String?,
    );
  }

  Future<List<AgencyClaimSummaryModel>> fetchAnalyticsClaimsList(
    String statusFilter, {
    int limit = 50,
    String? fromDate,
    String? toDate,
  }) async {
    const query = r'''
      query ClaimsList($statusFilter: AnalyticsClaimPipelineFilter!, $limit: Int, $fromDate: DateTime, $toDate: DateTime) {
        agencyAnalyticsClaims(statusFilter: $statusFilter, limit: $limit, fromDate: $fromDate, toDate: $toDate) {
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
    final list =
        result['data']?['agencyAnalyticsClaims'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => AgencyClaimSummaryModel(
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

  Future<List<AgencyScreeningSummaryModel>> fetchAnalyticsScreeningsList({
    String? riskLevel,
    int limit = 50,
    String? fromDate,
    String? toDate,
  }) async {
    const query = r'''
      query ScreeningsList($riskLevel: String, $limit: Int, $fromDate: DateTime, $toDate: DateTime) {
        agencyAnalyticsScreenings(riskLevel: $riskLevel, limit: $limit, fromDate: $fromDate, toDate: $toDate) {
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
        result['data']?['agencyAnalyticsScreenings'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => AgencyScreeningSummaryModel(
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

  Future<AgencyScreeningFunnelModel> fetchScreeningFunnel({
    String? fromDate,
    String? toDate,
  }) async {
    const query = r'''
      query ScreeningFunnel($fromDate: DateTime, $toDate: DateTime) {
        agencyScreeningFunnel(fromDate: $fromDate, toDate: $toDate) {
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
        result['data']?['agencyScreeningFunnel'] as Map<String, dynamic>? ?? {};
    return _mapScreeningFunnel(data);
  }

  AgencyClaimsPipelineModel _mapClaimsPipeline(Map<String, dynamic> data) {
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final claims = data['recentClaims'] as List<dynamic>? ?? [];
    return AgencyClaimsPipelineModel(
      summary: AgencyClaimsPipelineSummaryModel(
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
        paidAmountTotal: (summary['paidAmountTotal'] as num?)?.toDouble() ?? 0,
        priorPaidAmountTotal:
            (summary['priorPaidAmountTotal'] as num?)?.toDouble() ?? 0,
      ),
      recentClaims: claims
          .map(
            (e) => AgencyClaimSummaryModel(
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

  AgencyScreeningFunnelModel _mapScreeningFunnel(Map<String, dynamic> data) {
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final screenings = data['recentScreenings'] as List<dynamic>? ?? [];
    return AgencyScreeningFunnelModel(
      summary: AgencyScreeningFunnelSummaryModel(
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
            (e) => AgencyScreeningSummaryModel(
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

  Future<void> updateInsuranceClaim({
    required String claimId,
    required String status,
    String? denialReason,
    double? approvedAmount,
  }) async {
    const mutation = r'''
      mutation Update($input: UpdateInsuranceClaimInput!) {
        agencyUpdateInsuranceClaim(input: $input) { id status }
      }
    ''';
    await _graphql.query(
      mutation,
      variables: {
        'input': {
          'claimId': claimId,
          'status': status,
          'denialReason': ?denialReason,
          'approvedAmount': ?approvedAmount,
        },
      },
    );
  }

  Future<void> processClaimRemittance835(String claimId) async {
    const mutation = r'''
      mutation Remit($claimId: ID!) {
        agencyProcessClaimRemittance835(claimId: $claimId) { id status }
      }
    ''';
    await _graphql.query(mutation, variables: {'claimId': claimId});
  }

  Future<List<StaffSessionNoteSummaryModel>> fetchSessionNotes() async {
    const query = r'''
      query {
        agencySessionNotes {
          sessionId           childId therapistId childName therapistName sessionDate
          isFullySigned hasServiceLog awaitingParentSignature
        }
      }
    ''';
    final result = await _graphql.query(query);
    final list = result['data']?['agencySessionNotes'] as List<dynamic>? ?? [];
    return list.map(_mapSessionNote).toList();
  }

  Future<List<StaffSessionNoteSummaryModel>> fetchSessionNotesForChild(
    String childId,
  ) async {
    final result = await _graphql.query('''
      query(\$childId: ID!) {
        agencySessionNotesForChild(childId: \$childId) {
          sessionId           childId therapistId childName therapistName sessionDate
          isFullySigned hasServiceLog awaitingParentSignature
        }
      }
    ''', variables: {'childId': childId});
    final list =
        result['data']?['agencySessionNotesForChild'] as List<dynamic>? ?? [];
    return list.map(_mapSessionNote).toList();
  }

  StaffSessionNoteSummaryModel _mapSessionNote(dynamic e) {
    return StaffSessionNoteSummaryModel(
      sessionId: e['sessionId'] as String,
      childId: e['childId'] as String?,
      therapistId: e['therapistId'] as String?,
      childName: e['childName'] as String? ?? '',
      therapistName: e['therapistName'] as String? ?? '',
      sessionDate: e['sessionDate'] as String?,
      isFullySigned: e['isFullySigned'] as bool? ?? false,
      hasServiceLog: e['hasServiceLog'] as bool? ?? false,
      awaitingParentSignature:
          e['awaitingParentSignature'] as bool? ?? false,
    );
  }

  Future<String> downloadServiceLogPdf(String sessionId) async {
    final response = await _api.dio.get<List<int>>(
      '/service-logs/agency/$sessionId/pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(response.data ?? []);
    return downloadBytes(bytes, 'service-log-$sessionId.pdf');
  }

  Future<Map<String, dynamic>> fetchSessionNoteFormContext(
    String sessionId,
  ) async {
    final result = await _graphql.query(
      r'''
      query Context($sessionId: ID!) {
        agencySessionNoteFormContext(sessionId: $sessionId) {
          sessionId childName childDob childSex eiNumber
          interventionistName credentials npi licenseNumber licenseState
          serviceType
          sessionDate ifspServiceLocation timeFrom timeTo
          sessionDelivered icd10Code existingEipFormData isFullySigned
        }
      }
    ''',
      variables: {'sessionId': sessionId},
    );
    final data = result['data']?['agencySessionNoteFormContext'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Could not load session note context');
    }
    return data;
  }

  Future<void> saveEipSessionNote(EipSessionNoteModel form) async {
    const mutation = r'''
      mutation Save($input: SaveSoapNoteInput!) {
        agencySaveSoapNote(input: $input) { id }
      }
    ''';
    await _graphql.query(
      mutation,
      variables: {
        'input': {
          'sessionId': form.sessionId,
          'subjective': form.toSoapSubjective(),
          'objective': form.toSoapObjective(),
          'assessment': form.toSoapAssessment(),
          'plan': form.toSoapPlan(),
          'eipFormData': jsonEncode(form.toJson()),
        },
      },
    );
  }

  Future<ChildModel> addAgencyCaseloadChild({
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    String? gender,
    String? primaryLanguage,
    String? guardianName,
    String? guardianPhone,
    String? guardianEmail,
    String? addressLine1,
    String? zipCode,
    String? pediatricianName,
    String? insuranceType,
    bool? hadEarlyIntervention,
  }) async {
    const mutation = r'''
      mutation AddAgencyCaseloadChild($input: AddAgencyCaseloadChildInput!) {
        addAgencyCaseloadChild(input: $input) {
          id firstName lastName dateOfBirth gender primaryLanguage
          guardianName guardianPhone guardianEmail addressLine1 zipCode
          pediatricianName insuranceType hadEarlyIntervention
        }
      }
    ''';
    final result = await _graphql.query(
      mutation,
      variables: {
        'input': {
          'firstName': firstName,
          'lastName': lastName,
          'dateOfBirth': _dateOnlyIso(dateOfBirth),
          'gender': ?gender,
          'primaryLanguage': ?primaryLanguage,
          'guardianName': ?guardianName,
          'guardianPhone': ?guardianPhone,
          'guardianEmail': ?guardianEmail,
          'addressLine1': ?addressLine1,
          'zipCode': ?zipCode,
          'pediatricianName': ?pediatricianName,
          'insuranceType': ?insuranceType,
          'hadEarlyIntervention': ?hadEarlyIntervention,
        },
      },
    );
    final e =
        result['data']?['addAgencyCaseloadChild'] as Map<String, dynamic>?;
    if (e == null) {
      throw Exception('Failed to add child to agency caseload');
    }
    return _mapCaseloadChild(e);
  }

  Future<List<ChildModel>> fetchAgencyManagedChildren() async {
    const query = r'''
      query AgencyManagedCaseloadChildren {
        agencyManagedCaseloadChildren {
          id firstName lastName dateOfBirth gender primaryLanguage
          guardianName guardianPhone guardianEmail addressLine1 zipCode
          pediatricianName insuranceType hadEarlyIntervention
        }
      }
    ''';
    final result = await _graphql.query(query);
    final list =
        result['data']?['agencyManagedCaseloadChildren'] as List<dynamic>? ??
            [];
    return list
        .map((e) => _mapCaseloadChild(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChildModel> fetchAgencyManagedChild(String childId) async {
    const query = r'''
      query AgencyManagedCaseloadChild($childId: ID!) {
        agencyManagedCaseloadChild(childId: $childId) {
          id firstName lastName dateOfBirth gender primaryLanguage
          guardianName guardianPhone guardianEmail addressLine1 zipCode
          pediatricianName insuranceType hadEarlyIntervention
        }
      }
    ''';
    final result = await _graphql.query(
      query,
      variables: {'childId': childId},
    );
    final e = result['data']?['agencyManagedCaseloadChild']
        as Map<String, dynamic>?;
    if (e == null) {
      throw Exception('Child not found on agency caseload');
    }
    return _mapCaseloadChild(e);
  }

  Future<ChildModel> updateAgencyCaseloadChild({
    required String childId,
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    String? gender,
    String? primaryLanguage,
    String? guardianName,
    String? guardianPhone,
    String? guardianEmail,
    String? addressLine1,
    String? zipCode,
    String? pediatricianName,
    String? insuranceType,
    bool? hadEarlyIntervention,
  }) async {
    const mutation = r'''
      mutation UpdateAgencyCaseloadChild($input: UpdateAgencyCaseloadChildInput!) {
        updateAgencyCaseloadChild(input: $input) {
          id firstName lastName dateOfBirth gender primaryLanguage
          guardianName guardianPhone guardianEmail addressLine1 zipCode
          pediatricianName insuranceType hadEarlyIntervention
        }
      }
    ''';
    final result = await _graphql.query(
      mutation,
      variables: {
        'input': {
          'childId': childId,
          'firstName': ?firstName,
          'lastName': ?lastName,
          if (dateOfBirth != null) 'dateOfBirth': _dateOnlyIso(dateOfBirth),
          'gender': ?gender,
          'primaryLanguage': ?primaryLanguage,
          'guardianName': ?guardianName,
          'guardianPhone': ?guardianPhone,
          'guardianEmail': ?guardianEmail,
          'addressLine1': ?addressLine1,
          'zipCode': ?zipCode,
          'pediatricianName': ?pediatricianName,
          'insuranceType': ?insuranceType,
          'hadEarlyIntervention': ?hadEarlyIntervention,
        },
      },
    );
    final e =
        result['data']?['updateAgencyCaseloadChild'] as Map<String, dynamic>?;
    if (e == null) {
      throw Exception('Failed to update child profile');
    }
    return _mapCaseloadChild(e);
  }

  static String _dateOnlyIso(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  ChildModel _mapCaseloadChild(Map<String, dynamic> e) {
    return ChildModel(
      id: e['id'] as String,
      firstName: e['firstName'] as String,
      lastName: e['lastName'] as String,
      dateOfBirth: DateTime.parse(e['dateOfBirth'] as String),
      gender: e['gender'] as String?,
      primaryLanguage: e['primaryLanguage'] as String?,
      guardianName: e['guardianName'] as String?,
      guardianPhone: e['guardianPhone'] as String?,
      guardianEmail: e['guardianEmail'] as String?,
      addressLine1: e['addressLine1'] as String?,
      zipCode: e['zipCode'] as String?,
      pediatricianName: e['pediatricianName'] as String?,
      insuranceType: e['insuranceType'] as String?,
      hadEarlyIntervention: e['hadEarlyIntervention'] as bool?,
    );
  }
}
