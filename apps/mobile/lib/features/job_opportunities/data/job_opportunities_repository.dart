import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/network/graphql_client.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/file_download.dart';
import '../../../core/utils/json_parse.dart';
import 'job_opportunities_graphql.dart';

class JobOpportunityModel {
  const JobOpportunityModel({
    required this.id,
    required this.title,
    required this.serviceType,
    required this.serviceTypeLabel,
    required this.status,
    required this.locationAreaLabel,
    required this.zipCode,
    required this.locationModality,
    required this.disclaimer,
    required this.createdAt,
    this.publicDescription,
    this.borough,
    this.county,
    this.serviceRadiusMiles,
    this.distanceMiles,
    this.languageRequirement,
    this.employmentType,
    this.payRateDisplay,
    this.requiredExperience,
    this.agencyName,
    this.applicationCount,
    this.pendingActionCount,
    this.publishedAt,
    this.isSaved,
    this.myApplicationId,
    this.myApplicationStatus,
  });

  final String id;
  final String title;
  final String serviceType;
  final String serviceTypeLabel;
  final String status;
  final String locationAreaLabel;
  final String zipCode;
  final String locationModality;
  final String disclaimer;
  final DateTime createdAt;
  final String? publicDescription;
  final String? borough;
  final String? county;
  final int? serviceRadiusMiles;
  final double? distanceMiles;
  final String? languageRequirement;
  final String? employmentType;
  final String? payRateDisplay;
  final String? requiredExperience;
  final String? agencyName;
  final int? applicationCount;
  final int? pendingActionCount;
  final DateTime? publishedAt;
  final bool? isSaved;
  final String? myApplicationId;
  final String? myApplicationStatus;

  bool get hasActiveApplication =>
      myApplicationStatus != null && myApplicationStatus != 'WITHDRAWN';

  factory JobOpportunityModel.fromJson(Map<String, dynamic> json) {
    return JobOpportunityModel(
      id: jsonRequiredId(json['id'], 'job id'),
      title: jsonString(json['title']),
      serviceType: jsonString(json['serviceType'], fallback: 'OTHER'),
      serviceTypeLabel: jsonString(json['serviceTypeLabel']),
      status: jsonString(json['status'], fallback: 'DRAFT'),
      locationAreaLabel: jsonString(json['locationAreaLabel']),
      zipCode: jsonString(json['zipCode']),
      locationModality: jsonString(json['locationModality'], fallback: 'IN_PERSON'),
      disclaimer: jsonString(json['disclaimer']),
      createdAt: jsonDateTime(json['createdAt']),
      publicDescription: jsonString(json['publicDescription']).isEmpty
          ? null
          : jsonString(json['publicDescription']),
      borough: jsonOptionalString(json['borough']),
      county: jsonOptionalString(json['county']),
      serviceRadiusMiles: (json['serviceRadiusMiles'] as num?)?.toInt(),
      distanceMiles: (json['distanceMiles'] as num?)?.toDouble(),
      languageRequirement: jsonOptionalString(json['languageRequirement']),
      employmentType: jsonOptionalString(json['employmentType']),
      payRateDisplay: jsonOptionalString(json['payRateDisplay']),
      requiredExperience: jsonOptionalString(json['requiredExperience']),
      agencyName: jsonOptionalString(json['agencyName']),
      applicationCount: (json['applicationCount'] as num?)?.toInt(),
      pendingActionCount: (json['pendingActionCount'] as num?)?.toInt(),
      publishedAt: jsonDateTimeOrNull(json['publishedAt']),
      isSaved: json['isSaved'] as bool?,
      myApplicationId: jsonOptionalString(json['myApplicationId']),
      myApplicationStatus: jsonOptionalString(json['myApplicationStatus']),
    );
  }
}

List<T> _parseList<T>(
  List<dynamic>? raw,
  T Function(Map<String, dynamic> row) parse, {
  String label = 'row',
}) {
  if (raw == null) return const [];
  final parsed = <T>[];
  for (final entry in raw) {
    if (entry is! Map<String, dynamic>) continue;
    try {
      parsed.add(parse(entry));
    } catch (error, stackTrace) {
      debugPrint('Skipping invalid job marketplace $label: $error\n$stackTrace');
    }
  }
  return parsed;
}

class ChildServiceNeedModel {
  const ChildServiceNeedModel({
    required this.id,
    required this.serviceType,
    required this.status,
    required this.childDisplayName,
    required this.createdAt,
    this.internalNotes,
    this.jobOpportunityId,
    this.jobOpportunityTitle,
    this.jobOpportunityStatus,
    this.childId,
  });

  final String id;
  final String serviceType;
  final String status;
  final String childDisplayName;
  final DateTime createdAt;
  final String? internalNotes;
  final String? jobOpportunityId;
  final String? jobOpportunityTitle;
  final String? jobOpportunityStatus;
  final String? childId;

  factory ChildServiceNeedModel.fromJson(Map<String, dynamic> json) {
    return ChildServiceNeedModel(
      id: jsonRequiredId(json['id'], 'service need id'),
      serviceType: jsonString(json['serviceType'], fallback: 'OTHER'),
      status: jsonString(json['status'], fallback: 'OPEN'),
      childDisplayName: jsonString(json['childDisplayName'], fallback: 'Child'),
      createdAt: jsonDateTime(json['createdAt']),
      internalNotes: jsonOptionalString(json['internalNotes']),
      jobOpportunityId: jsonOptionalString(json['jobOpportunityId']),
      jobOpportunityTitle: jsonOptionalString(json['jobOpportunityTitle']),
      jobOpportunityStatus: jsonOptionalString(json['jobOpportunityStatus']),
      childId: jsonOptionalString(json['childId']),
    );
  }
}

class JobApplicationStatusHistoryModel {
  const JobApplicationStatusHistoryModel({
    required this.toStatus,
    required this.changedByName,
    required this.createdAt,
    this.fromStatus,
    this.note,
  });

  final String? fromStatus;
  final String toStatus;
  final String? note;
  final String changedByName;
  final DateTime createdAt;

  factory JobApplicationStatusHistoryModel.fromJson(Map<String, dynamic> json) {
    return JobApplicationStatusHistoryModel(
      fromStatus: jsonOptionalString(json['fromStatus']),
      toStatus: jsonString(json['toStatus'], fallback: 'NEW_APPLICANT'),
      note: jsonOptionalString(json['note']),
      changedByName: jsonString(json['changedByName'], fallback: 'System'),
      createdAt: jsonDateTime(json['createdAt']),
    );
  }
}

class AgencyHiringPipelineSummaryModel {
  const AgencyHiringPipelineSummaryModel({
    required this.newApplicants,
    required this.credentialReview,
    required this.credentialsSubmitted,
    required this.offersPending,
    required this.readyToHire,
    required this.totalPendingActions,
  });

  final int newApplicants;
  final int credentialReview;
  final int credentialsSubmitted;
  final int offersPending;
  final int readyToHire;
  final int totalPendingActions;

  factory AgencyHiringPipelineSummaryModel.fromJson(Map<String, dynamic> json) {
    return AgencyHiringPipelineSummaryModel(
      newApplicants: json['newApplicants'] as int? ?? 0,
      credentialReview: json['credentialReview'] as int? ?? 0,
      credentialsSubmitted: json['credentialsSubmitted'] as int? ?? 0,
      offersPending: json['offersPending'] as int? ?? 0,
      readyToHire: json['readyToHire'] as int? ?? 0,
      totalPendingActions: json['totalPendingActions'] as int? ?? 0,
    );
  }
}

class JobCredentialDocumentModel {
  const JobCredentialDocumentModel({
    required this.id,
    required this.title,
    required this.fileName,
    required this.type,
    required this.uploadedAt,
  });

  final String id;
  final String title;
  final String fileName;
  final String type;
  final DateTime uploadedAt;

  factory JobCredentialDocumentModel.fromJson(Map<String, dynamic> json) {
    return JobCredentialDocumentModel(
      id: jsonRequiredId(json['id'], 'credential document id'),
      title: jsonString(json['title']),
      fileName: jsonString(json['fileName'], fallback: jsonString(json['title'])),
      type: jsonString(json['type'], fallback: 'OTHER'),
      uploadedAt: jsonDateTime(json['uploadedAt']),
    );
  }
}

class JobApplicationModel {
  const JobApplicationModel({
    required this.id,
    required this.status,
    required this.therapistName,
    required this.jobOpportunityId,
    required this.jobTitle,
    required this.createdAt,
    required this.updatedAt,
    this.message,
    this.therapistEmail,
    this.credentialDocuments = const [],
    this.recentStatusHistory = const [],
  });

  final String id;
  final String status;
  final String therapistName;
  final String jobOpportunityId;
  final String jobTitle;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? message;
  final String? therapistEmail;
  final List<JobCredentialDocumentModel> credentialDocuments;
  final List<JobApplicationStatusHistoryModel> recentStatusHistory;

  factory JobApplicationModel.fromJson(Map<String, dynamic> json) {
    final docs = json['credentialDocuments'] as List<dynamic>? ?? [];
    final history = json['recentStatusHistory'] as List<dynamic>? ?? [];
    return JobApplicationModel(
      id: jsonRequiredId(json['id'], 'application id'),
      status: jsonString(json['status'], fallback: 'NEW_APPLICANT'),
      therapistName: jsonString(json['therapistName']),
      jobOpportunityId: jsonString(json['jobOpportunityId']),
      jobTitle: jsonString(json['jobTitle']),
      createdAt: jsonDateTime(json['createdAt']),
      updatedAt: jsonDateTime(json['updatedAt']),
      message: jsonOptionalString(json['message']),
      therapistEmail: jsonOptionalString(json['therapistEmail']),
      credentialDocuments: docs
          .map(
            (e) => JobCredentialDocumentModel.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      recentStatusHistory: history
          .map(
            (e) => JobApplicationStatusHistoryModel.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class JobOpportunityInviteModel {
  const JobOpportunityInviteModel({
    required this.id,
    required this.jobOpportunityId,
    required this.jobTitle,
    required this.agencyName,
    required this.invitedAt,
  });

  final String id;
  final String jobOpportunityId;
  final String jobTitle;
  final String agencyName;
  final DateTime invitedAt;

  factory JobOpportunityInviteModel.fromJson(Map<String, dynamic> json) {
    return JobOpportunityInviteModel(
      id: jsonRequiredId(json['id'], 'invite id'),
      jobOpportunityId: jsonString(json['jobOpportunityId']),
      jobTitle: jsonString(json['jobTitle']),
      agencyName: jsonString(json['agencyName']),
      invitedAt: jsonDateTime(json['invitedAt']),
    );
  }
}

class JobInterviewModel {
  const JobInterviewModel({
    required this.id,
    required this.applicationId,
    required this.jobOpportunityId,
    required this.jobTitle,
    required this.therapistName,
    required this.agencyName,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.status,
    required this.recordingRequested,
    required this.agencyRecordingConsent,
    required this.therapistRecordingConsent,
    required this.recordingEnabled,
    this.therapistEmail,
    this.notes,
    this.callSessionId,
  });

  final String id;
  final String applicationId;
  final String jobOpportunityId;
  final String jobTitle;
  final String therapistName;
  final String agencyName;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String status;
  final bool recordingRequested;
  final bool agencyRecordingConsent;
  final bool therapistRecordingConsent;
  final bool recordingEnabled;
  final String? therapistEmail;
  final String? notes;
  final String? callSessionId;

  factory JobInterviewModel.fromJson(Map<String, dynamic> json) {
    return JobInterviewModel(
      id: jsonRequiredId(json['id'], 'interview id'),
      applicationId: jsonString(json['applicationId']),
      jobOpportunityId: jsonString(json['jobOpportunityId']),
      jobTitle: jsonString(json['jobTitle']),
      therapistName: jsonString(json['therapistName']),
      agencyName: jsonString(json['agencyName']),
      scheduledAt: jsonDateTime(json['scheduledAt']),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 30,
      status: jsonString(json['status'], fallback: 'SCHEDULED'),
      recordingRequested: json['recordingRequested'] == true,
      agencyRecordingConsent: json['agencyRecordingConsent'] == true,
      therapistRecordingConsent: json['therapistRecordingConsent'] == true,
      recordingEnabled: json['recordingEnabled'] == true,
      therapistEmail: jsonOptionalString(json['therapistEmail']),
      notes: jsonOptionalString(json['notes']),
      callSessionId: jsonOptionalString(json['callSessionId']),
    );
  }
}

class JobInterviewJoinModel {
  const JobInterviewJoinModel({
    required this.interviewId,
    required this.recordingEnabled,
    required this.jobTitle,
    required this.therapistName,
    required this.agencyName,
    required this.callSessionId,
    required this.token,
    required this.tokenExpiresAt,
    this.joinUrl,
  });

  final String interviewId;
  final bool recordingEnabled;
  final String jobTitle;
  final String therapistName;
  final String agencyName;
  final String callSessionId;
  final String token;
  final DateTime tokenExpiresAt;
  final String? joinUrl;

  factory JobInterviewJoinModel.fromJson(Map<String, dynamic> json) {
    return JobInterviewJoinModel(
      interviewId: jsonRequiredId(json['interviewId'], 'interview id'),
      recordingEnabled: json['recordingEnabled'] == true,
      jobTitle: jsonString(json['jobTitle']),
      therapistName: jsonString(json['therapistName']),
      agencyName: jsonString(json['agencyName']),
      callSessionId: jsonRequiredId(json['callSessionId'], 'call session id'),
      token: jsonString(json['token']),
      tokenExpiresAt: jsonDateTime(json['tokenExpiresAt']),
      joinUrl: jsonOptionalString(json['joinUrl']),
    );
  }
}

class JobMarketplaceAuditLogModel {
  const JobMarketplaceAuditLogModel({
    required this.id,
    required this.eventType,
    required this.entityType,
    required this.entityId,
    required this.metadataJson,
    required this.createdAt,
    this.actorName,
  });

  final String id;
  final String eventType;
  final String entityType;
  final String entityId;
  final String metadataJson;
  final DateTime createdAt;
  final String? actorName;

  factory JobMarketplaceAuditLogModel.fromJson(Map<String, dynamic> json) {
    return JobMarketplaceAuditLogModel(
      id: jsonRequiredId(json['id'], 'audit log id'),
      eventType: jsonString(json['eventType']),
      entityType: jsonString(json['entityType']),
      entityId: jsonString(json['entityId']),
      metadataJson: jsonString(json['metadataJson'], fallback: '{}'),
      createdAt: jsonDateTime(json['createdAt']),
      actorName: jsonOptionalString(json['actorName']),
    );
  }
}

class HireOnboardingStepModel {
  const HireOnboardingStepModel({
    required this.key,
    required this.label,
    required this.complete,
    required this.therapistCanComplete,
    this.completedAt,
  });

  final String key;
  final String label;
  final bool complete;
  final bool therapistCanComplete;
  final DateTime? completedAt;

  factory HireOnboardingStepModel.fromJson(Map<String, dynamic> json) {
    return HireOnboardingStepModel(
      key: jsonString(json['key']),
      label: jsonString(json['label']),
      complete: json['complete'] == true,
      therapistCanComplete: json['therapistCanComplete'] == true,
      completedAt: json['completedAt'] == null
          ? null
          : jsonDateTime(json['completedAt']),
    );
  }
}

class HireOnboardingModel {
  const HireOnboardingModel({
    required this.agencyTherapistLinkId,
    required this.therapistId,
    required this.therapistName,
    required this.agencyId,
    required this.agencyName,
    required this.steps,
    required this.completedCount,
    required this.totalCount,
    required this.isComplete,
  });

  final String agencyTherapistLinkId;
  final String therapistId;
  final String therapistName;
  final String agencyId;
  final String agencyName;
  final List<HireOnboardingStepModel> steps;
  final int completedCount;
  final int totalCount;
  final bool isComplete;

  factory HireOnboardingModel.fromJson(Map<String, dynamic> json) {
    final steps = json['steps'] as List<dynamic>? ?? [];
    return HireOnboardingModel(
      agencyTherapistLinkId: jsonRequiredId(
        json['agencyTherapistLinkId'],
        'agency therapist link id',
      ),
      therapistId: jsonRequiredId(json['therapistId'], 'therapist id'),
      therapistName: jsonString(json['therapistName']),
      agencyId: jsonRequiredId(json['agencyId'], 'agency id'),
      agencyName: jsonString(json['agencyName']),
      steps: steps
          .map(
            (e) => HireOnboardingStepModel.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      completedCount: json['completedCount'] as int? ?? 0,
      totalCount: json['totalCount'] as int? ?? 0,
      isComplete: json['isComplete'] == true,
    );
  }
}

class JobOpportunitiesRepository {
  JobOpportunitiesRepository(this._client, this._api);

  final GraphqlClient _client;
  final ApiClient _api;

  Map<String, dynamic> _data(Map<String, dynamic> result) =>
      result['data'] as Map<String, dynamic>? ?? {};

  Map<String, dynamic> _requireMutationRow(
    Map<String, dynamic> data,
    String field,
  ) {
    final row = data[field];
    if (row is Map<String, dynamic>) return row;
    throw Exception('Job opportunity request failed ($field)');
  }

  Future<List<ChildServiceNeedModel>> fetchChildServiceNeeds() async {
    final query = r'''
      query MyChildServiceNeeds {
        myChildServiceNeeds {
          id serviceType status childDisplayName childId internalNotes
          jobOpportunityId jobOpportunityTitle jobOpportunityStatus createdAt
        }
      }
    ''';
    final data = _data(await _client.query(query));
    final list = data['myChildServiceNeeds'] as List<dynamic>? ?? [];
    return list
        .map((e) => ChildServiceNeedModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<JobOpportunityModel>> fetchAgencyOpportunities() async {
    final query = r'''
      query MyAgencyJobOpportunities {
        myAgencyJobOpportunities {
          id title serviceType serviceTypeLabel status locationAreaLabel zipCode
          locationModality disclaimer publicDescription applicationCount
          pendingActionCount payRateDisplay publishedAt createdAt
        }
      }
    ''';
    final data = _data(await _client.query(query));
    final list = data['myAgencyJobOpportunities'] as List<dynamic>? ?? [];
    return _parseList(
      list,
      JobOpportunityModel.fromJson,
      label: 'job opportunity',
    );
  }

  Future<JobOpportunityModel?> fetchAgencyOpportunityById(
    String jobOpportunityId,
  ) async {
    final jobs = await fetchAgencyOpportunities();
    for (final job in jobs) {
      if (job.id == jobOpportunityId) return job;
    }
    return null;
  }

  Future<List<JobApplicationModel>> fetchAgencyApplications({
    String? jobOpportunityId,
  }) async {
    final query = agencyJobApplicationsDocument();
    final data = _data(
      await _client.query(
        query,
        variables: {'jobOpportunityId': jobOpportunityId},
      ),
    );
    final list = data['agencyJobApplications'] as List<dynamic>? ?? [];
    return list
        .map((e) => JobApplicationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<JobOpportunityModel>> browseJobOpportunities({
    String? zipCode,
    double? radiusMiles,
    String? serviceType,
    String? employmentType,
    String? locationModality,
    String? language,
  }) async {
    final query = r'''
      query BrowseJobOpportunities($input: BrowseJobOpportunitiesInput) {
        browseJobOpportunities(input: $input) {
          items {
            id title serviceType serviceTypeLabel status locationAreaLabel zipCode
            distanceMiles locationModality disclaimer publicDescription
            payRateDisplay agencyName applicationCount publishedAt createdAt
          }
        }
      }
    ''';
    final data = _data(
      await _client.query(
        query,
        variables: {
          'input': {
            if (zipCode != null && zipCode.isNotEmpty) 'zipCode': zipCode,
            if (radiusMiles != null) 'radiusMiles': radiusMiles,
            if (serviceType != null) 'serviceType': serviceType,
            if (employmentType != null) 'employmentType': employmentType,
            if (locationModality != null) 'locationModality': locationModality,
            if (language != null && language.isNotEmpty) 'language': language,
          },
        },
      ),
    );
    final items =
        (data['browseJobOpportunities']?['items'] as List<dynamic>?) ?? [];
    return items
        .map((e) => JobOpportunityModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<JobOpportunityModel?> fetchJobOpportunity(String jobOpportunityId) async {
    final query = r'''
      query JobOpportunity($jobOpportunityId: ID!) {
        jobOpportunity(jobOpportunityId: $jobOpportunityId) {
          id title serviceType serviceTypeLabel status locationAreaLabel zipCode
          distanceMiles locationModality disclaimer publicDescription
          payRateDisplay agencyName applicationCount publishedAt createdAt
          languageRequirement employmentType requiredExperience borough county
          isSaved myApplicationId myApplicationStatus
        }
      }
    ''';
    final data = _data(
      await _client.query(
        query,
        variables: {'jobOpportunityId': jobOpportunityId},
      ),
    );
    final row = data['jobOpportunity'];
    if (row == null) return null;
    return JobOpportunityModel.fromJson(row as Map<String, dynamic>);
  }

  Future<List<JobOpportunityModel>> fetchSavedJobOpportunities() async {
    final query = r'''
      query SavedJobOpportunities {
        savedJobOpportunities {
          id title serviceType serviceTypeLabel status locationAreaLabel zipCode
          distanceMiles locationModality disclaimer publicDescription
          payRateDisplay agencyName applicationCount publishedAt createdAt
        }
      }
    ''';
    final data = _data(await _client.query(query));
    final list = data['savedJobOpportunities'] as List<dynamic>? ?? [];
    return list
        .map((e) => JobOpportunityModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<JobApplicationModel>> fetchMyApplications() async {
    final query = myJobApplicationsDocument();
    final data = _data(await _client.query(query));
    final list = data['myJobApplications'] as List<dynamic>? ?? [];
    return list
        .map((e) => JobApplicationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChildServiceNeedModel> createChildServiceNeed({
    required String childId,
    required String serviceType,
    String? internalNotes,
  }) async {
    final mutation = r'''
      mutation CreateChildServiceNeed($input: CreateChildServiceNeedInput!) {
        createChildServiceNeed(input: $input) {
          id serviceType status childDisplayName createdAt
        }
      }
    ''';
    final data = _data(
      await _client.query(
        mutation,
        variables: {
          'input': {
            'childId': childId,
            'serviceType': serviceType,
            if (internalNotes != null) 'internalNotes': internalNotes,
          },
        },
      ),
    );
    return ChildServiceNeedModel.fromJson(
      _requireMutationRow(data, 'createChildServiceNeed'),
    );
  }

  Future<String> generateJobOpportunity(String childServiceNeedId) async {
    final mutation = r'''
      mutation GenerateJobOpportunity($id: ID!) {
        generateJobOpportunity(childServiceNeedId: $id) {
          id
        }
      }
    ''';
    final data = _data(
      await _client.query(
        mutation,
        variables: {'id': childServiceNeedId},
      ),
    );
    final row = _requireMutationRow(data, 'generateJobOpportunity');
    return jsonRequiredId(row['id'], 'job id');
  }

  Future<void> updateJobOpportunity({
    required String jobOpportunityId,
    String? title,
    String? publicDescription,
    String? borough,
    String? county,
    String? payRateDisplay,
  }) async {
    final mutation = r'''
      mutation UpdateJobOpportunity($input: UpdateJobOpportunityInput!) {
        updateJobOpportunity(input: $input) {
          id
        }
      }
    ''';
    final data = _data(
      await _client.query(
        mutation,
        variables: {
          'input': {
            'jobOpportunityId': jobOpportunityId,
            if (title != null) 'title': title,
            if (publicDescription != null) 'publicDescription': publicDescription,
            if (borough != null) 'borough': borough,
            if (county != null) 'county': county,
            if (payRateDisplay != null) 'payRateDisplay': payRateDisplay,
          },
        },
      ),
    );
    _requireMutationRow(data, 'updateJobOpportunity');
  }

  Future<void> publishJobOpportunity(String jobOpportunityId) async {
    final mutation = r'''
      mutation PublishJobOpportunity($id: ID!) {
        publishJobOpportunity(jobOpportunityId: $id) {
          id
          status
        }
      }
    ''';
    final data = _data(
      await _client.query(
        mutation,
        variables: {'id': jobOpportunityId},
      ),
    );
    final row = _requireMutationRow(data, 'publishJobOpportunity');
    final status = jsonString(row['status']);
    if (status != 'PUBLISHED') {
      throw Exception('Publish failed (status: ${status.isEmpty ? 'unknown' : status})');
    }
  }

  Future<JobApplicationModel> applyToJobOpportunity({
    required String jobOpportunityId,
    String? message,
  }) async {
    final mutation = r'''
      mutation ApplyToJobOpportunity($input: ApplyToJobOpportunityInput!) {
        applyToJobOpportunity(input: $input) {
          id status jobTitle jobOpportunityId therapistName createdAt updatedAt
        }
      }
    ''';
    final data = _data(
      await _client.query(
        mutation,
        variables: {
          'input': {
            'jobOpportunityId': jobOpportunityId,
            if (message != null) 'message': message,
          },
        },
      ),
    );
    return JobApplicationModel.fromJson(
      _requireMutationRow(data, 'applyToJobOpportunity'),
    );
  }

  Future<JobApplicationModel> withdrawJobApplication(
    String applicationId,
  ) async {
    final mutation = r'''
      mutation WithdrawJobApplication($id: ID!) {
        withdrawJobApplication(applicationId: $id) {
          id status jobTitle updatedAt
        }
      }
    ''';
    final data = _data(
      await _client.query(
        mutation,
        variables: {'id': applicationId},
      ),
    );
    return JobApplicationModel.fromJson(
      _requireMutationRow(data, 'withdrawJobApplication'),
    );
  }

  Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
    String? note,
  }) async {
    final mutation = r'''
      mutation UpdateJobApplicationStatus($input: UpdateJobApplicationStatusInput!) {
        updateJobApplicationStatus(input: $input) { id status }
      }
    ''';
    await _client.query(
      mutation,
      variables: {
        'input': {
          'applicationId': applicationId,
          'status': status,
          if (note != null) 'note': note,
        },
      },
    );
  }

  Future<void> requestApplicationDocuments({
    required String applicationId,
    String? note,
  }) async {
    final mutation = r'''
      mutation RequestJobApplicationDocuments($input: RequestJobApplicationDocumentsInput!) {
        requestJobApplicationDocuments(input: $input) { id status }
      }
    ''';
    await _client.query(
      mutation,
      variables: {
        'input': {
          'applicationId': applicationId,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      },
    );
  }

  Future<void> approveApplicationCredentials({
    required String applicationId,
    String? note,
  }) async {
    final mutation = r'''
      mutation ApproveJobApplicationCredentials($input: ApproveJobApplicationCredentialsInput!) {
        approveJobApplicationCredentials(input: $input) { id status }
      }
    ''';
    await _client.query(
      mutation,
      variables: {
        'input': {
          'applicationId': applicationId,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      },
    );
  }

  Future<void> sendJobOffer({
    required String applicationId,
    String? compensationRate,
    DateTime? startDate,
    String? message,
  }) async {
    final mutation = r'''
      mutation SendJobOffer($input: SendJobOfferInput!) {
        sendJobOffer(input: $input) { id status }
      }
    ''';
    await _client.query(
      mutation,
      variables: {
        'input': {
          'applicationId': applicationId,
          if (compensationRate != null && compensationRate.isNotEmpty)
            'compensationRate': compensationRate,
          if (startDate != null) 'startDate': startDate.toIso8601String(),
          if (message != null && message.isNotEmpty) 'message': message,
        },
      },
    );
  }

  Future<AgencyHiringPipelineSummaryModel> fetchAgencyHiringPipelineSummary() async {
    const query = r'''
      query AgencyHiringPipelineSummary {
        agencyHiringPipelineSummary {
          newApplicants credentialReview credentialsSubmitted
          offersPending readyToHire totalPendingActions
        }
      }
    ''';
    final data = _data(await _client.query(query));
    return AgencyHiringPipelineSummaryModel.fromJson(
      data['agencyHiringPipelineSummary'] as Map<String, dynamic>,
    );
  }

  Future<JobApplicationModel> refreshApplicationCredentials(
    String applicationId,
  ) async {
    final mutation =
        'mutation RefreshJobApplicationCredentials(\$applicationId: ID!) {'
        ' refreshJobApplicationCredentials(applicationId: \$applicationId) {'
        ' $jobApplicationFields'
        ' }'
        '}';
    final data = _data(
      await _client.query(
        mutation,
        variables: {'applicationId': applicationId},
      ),
    );
    return JobApplicationModel.fromJson(
      _requireMutationRow(data, 'refreshJobApplicationCredentials'),
    );
  }

  Future<JobApplicationModel> respondToJobOffer({
    required String applicationId,
    required bool accept,
    String? note,
  }) async {
    final mutation = '''
      mutation RespondToJobOffer(\$input: RespondToJobOfferInput!) {
        respondToJobOffer(input: \$input) {
          id status jobTitle jobOpportunityId therapistName createdAt updatedAt
        }
      }
    ''';
    final data = _data(
      await _client.query(
        mutation,
        variables: {
          'input': {
            'applicationId': applicationId,
            'accept': accept,
            if (note != null && note.isNotEmpty) 'note': note,
          },
        },
      ),
    );
    return JobApplicationModel.fromJson(
      _requireMutationRow(data, 'respondToJobOffer'),
    );
  }

  Future<JobInterviewModel> updateInterviewNotes({
    required String interviewId,
    required String notes,
  }) async {
    final mutation = '''
      mutation UpdateJobInterviewNotes(\$input: UpdateJobInterviewNotesInput!) {
        updateJobInterviewNotes(input: \$input) {
          $jobInterviewFields
        }
      }
    ''';
    final data = _data(
      await _client.query(
        mutation,
        variables: {
          'input': {'interviewId': interviewId, 'notes': notes},
        },
      ),
    );
    return JobInterviewModel.fromJson(
      _requireMutationRow(data, 'updateJobInterviewNotes'),
    );
  }

  Future<void> markHiredAndAddToRoster(String applicationId) async {
    const hiredMutation = r'''
      mutation MarkHired($id: ID!) {
        markTherapistHiredContracted(applicationId: $id) { id status }
      }
    ''';
    await _client.query(hiredMutation, variables: {'id': applicationId});
    const rosterMutation = r'''
      mutation AddToRoster($id: ID!) {
        addTherapistToAgencyRosterFromApplication(applicationId: $id)
      }
    ''';
    await _client.query(rosterMutation, variables: {'id': applicationId});
  }

  Future<void> scheduleFirstSessionFromHire({
    required String applicationId,
    required DateTime scheduledStart,
    int durationMinutes = 60,
    String? notes,
  }) async {
    const mutation = r'''
      mutation ScheduleFirstSession($input: ScheduleFirstSessionFromHireInput!) {
        scheduleFirstSessionFromHire(input: $input) {
          appointmentId childId therapistId scheduledStart scheduledEnd
        }
      }
    ''';
    await _client.query(
      mutation,
      variables: {
        'input': {
          'applicationId': applicationId,
          'scheduledStart': scheduledStart.toUtc().toIso8601String(),
          'durationMinutes': durationMinutes,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      },
    );
  }

  Future<void> rescheduleJobInterview({
    required String interviewId,
    required DateTime scheduledAt,
    int? durationMinutes,
    String? notes,
  }) async {
    const mutation = r'''
      mutation RescheduleJobInterview($input: RescheduleJobInterviewInput!) {
        rescheduleJobInterview(input: $input) { id status scheduledAt }
      }
    ''';
    await _client.query(
      mutation,
      variables: {
        'input': {
          'interviewId': interviewId,
          'scheduledAt': scheduledAt.toUtc().toIso8601String(),
          if (durationMinutes != null) 'durationMinutes': durationMinutes,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      },
    );
  }

  Future<void> completeJobInterviewManually({
    required String interviewId,
    String? note,
  }) async {
    const mutation = r'''
      mutation CompleteInterview($id: ID!, $note: String) {
        completeJobInterviewManually(interviewId: $id, note: $note) { id status }
      }
    ''';
    await _client.query(
      mutation,
      variables: {
        'id': interviewId,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  Future<List<JobApplicationModel>> fetchAdminApplications() async {
    final query = adminJobApplicationsDocument();
    final data = _data(await _client.query(query));
    final list = data['adminJobApplications'] as List<dynamic>? ?? [];
    return _parseList(
      list,
      JobApplicationModel.fromJson,
      label: 'application',
    );
  }

  Future<List<JobOpportunityModel>> adminJobOpportunities() async {
    final query = r'''
      query AdminJobOpportunities {
        adminJobOpportunities {
          id title status locationAreaLabel agencyName applicationCount createdAt
          disclaimer serviceTypeLabel
        }
      }
    ''';
    final data = _data(await _client.query(query));
    final list = data['adminJobOpportunities'] as List<dynamic>? ?? [];
    return list
        .map((e) => JobOpportunityModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<JobOpportunityInviteModel>> fetchMyJobInvites() async {
    final query = r'''
      query MyJobOpportunityInvites {
        myJobOpportunityInvites {
          id jobOpportunityId jobTitle agencyName invitedAt
        }
      }
    ''';
    final data = _data(await _client.query(query));
    final list = data['myJobOpportunityInvites'] as List<dynamic>? ?? [];
    return list
        .map((e) => JobOpportunityInviteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<JobOpportunityInviteModel> inviteTherapistToApply({
    required String jobOpportunityId,
    required String therapistId,
  }) async {
    final mutation = r'''
      mutation InviteTherapistToApply($jobOpportunityId: ID!, $therapistId: ID!) {
        inviteTherapistToApply(
          jobOpportunityId: $jobOpportunityId
          therapistId: $therapistId
        ) {
          id jobOpportunityId jobTitle agencyName invitedAt
        }
      }
    ''';
    final data = _data(
      await _client.query(
        mutation,
        variables: {
          'jobOpportunityId': jobOpportunityId,
          'therapistId': therapistId,
        },
      ),
    );
    return JobOpportunityInviteModel.fromJson(
      _requireMutationRow(data, 'inviteTherapistToApply'),
    );
  }

  Future<List<JobInterviewModel>> fetchAgencyInterviews({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final query = '''
        query AgencyJobInterviews(\$from: DateTime, \$to: DateTime) {
          agencyJobInterviews(from: \$from, to: \$to) {
            $jobInterviewFields
          }
        }
      ''';
      final data = _data(
        await _client.query(
          query,
          variables: {
            if (from != null) 'from': from.toUtc().toIso8601String(),
            if (to != null) 'to': to.toUtc().toIso8601String(),
          },
        ),
      );
      final list = data['agencyJobInterviews'] as List<dynamic>? ?? [];
      return list
          .map((e) => JobInterviewModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<JobInterviewModel?> fetchInterviewForApplication(
    String applicationId,
  ) async {
    try {
      final query = '''
        query JobInterviewForApplication(\$applicationId: ID!) {
          jobInterviewForApplication(applicationId: \$applicationId) {
            $jobInterviewFields
          }
        }
      ''';
      final data = _data(
        await _client.query(
          query,
          variables: {'applicationId': applicationId},
        ),
      );
      final row = data['jobInterviewForApplication'];
      if (row == null) return null;
      return JobInterviewModel.fromJson(row as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<JobInterviewModel>> fetchMyJobInterviews() async {
    try {
      final query = myJobInterviewsDocument();
      final data = _data(await _client.query(query));
      final list = data['myJobInterviews'] as List<dynamic>? ?? [];
      return list
          .map((e) => JobInterviewModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<JobInterviewModel> scheduleJobInterview({
    required String applicationId,
    required DateTime scheduledAt,
    int durationMinutes = 30,
    bool recordingRequested = false,
    bool agencyRecordingConsent = false,
    String? notes,
  }) async {
    final mutation = '''
      mutation ScheduleJobInterview(\$input: ScheduleJobInterviewInput!) {
        scheduleJobInterview(input: \$input) {
          $jobInterviewFields
        }
      }
    ''';
    final data = _data(
      await _client.query(
        mutation,
        variables: {
          'input': {
            'applicationId': applicationId,
            'scheduledAt': scheduledAt.toUtc().toIso8601String(),
            'durationMinutes': durationMinutes,
            'recordingRequested': recordingRequested,
            'agencyRecordingConsent':
                recordingRequested && agencyRecordingConsent,
            if (notes != null && notes.isNotEmpty) 'notes': notes,
          },
        },
      ),
    );
    return JobInterviewModel.fromJson(
      _requireMutationRow(data, 'scheduleJobInterview'),
    );
  }

  Future<JobInterviewModel> grantInterviewRecordingConsent({
    required String interviewId,
    required bool consent,
  }) async {
    final mutation = '''
      mutation GrantInterviewConsent(\$input: JobInterviewConsentInput!) {
        grantJobInterviewRecordingConsent(input: \$input) {
          $jobInterviewFields
        }
      }
    ''';
    final data = _data(
      await _client.query(
        mutation,
        variables: {
          'input': {'interviewId': interviewId, 'consent': consent},
        },
      ),
    );
    return JobInterviewModel.fromJson(
      _requireMutationRow(data, 'grantJobInterviewRecordingConsent'),
    );
  }

  Future<JobInterviewModel> cancelJobInterview({
    required String interviewId,
    String? reason,
  }) async {
    final mutation = '''
      mutation CancelJobInterview(\$interviewId: ID!, \$reason: String) {
        cancelJobInterview(interviewId: \$interviewId, reason: \$reason) {
          $jobInterviewFields
        }
      }
    ''';
    final data = _data(
      await _client.query(
        mutation,
        variables: {
          'interviewId': interviewId,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      ),
    );
    return JobInterviewModel.fromJson(
      _requireMutationRow(data, 'cancelJobInterview'),
    );
  }

  Future<JobInterviewJoinModel> joinJobInterview(String interviewId) async {
    final mutation = r'''
      mutation JoinJobInterview($interviewId: ID!) {
        joinJobInterview(interviewId: $interviewId) {
          interviewId recordingEnabled jobTitle therapistName agencyName
          callSessionId joinUrl token tokenExpiresAt
        }
      }
    ''';
    final data = _data(
      await _client.query(
        mutation,
        variables: {'interviewId': interviewId},
      ),
    );
    return JobInterviewJoinModel.fromJson(
      _requireMutationRow(data, 'joinJobInterview'),
    );
  }

  Future<void> unsaveJobOpportunity(String jobOpportunityId) async {
    final mutation = r'''
      mutation UnsaveJobOpportunity($id: ID!) {
        unsaveJobOpportunity(jobOpportunityId: $id)
      }
    ''';
    await _client.query(
      mutation,
      variables: {'id': jobOpportunityId},
    );
  }

  Future<List<JobMarketplaceAuditLogModel>> adminAuditLogs() async {
    final query = r'''
      query AdminJobAuditLogs {
        adminMarketplaceAuditLogs {
          id eventType entityType entityId actorName metadataJson createdAt
        }
      }
    ''';
    final data = _data(await _client.query(query));
    final list = data['adminMarketplaceAuditLogs'] as List<dynamic>? ?? [];
    return list
        .map((e) => JobMarketplaceAuditLogModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveJobOpportunity(String jobOpportunityId) async {
    final mutation = r'''
      mutation SaveJobOpportunity($id: ID!) {
        saveJobOpportunity(jobOpportunityId: $id) {
          id
          isSaved
        }
      }
    ''';
    final data = _data(
      await _client.query(
        mutation,
        variables: {'id': jobOpportunityId},
      ),
    );
    final row = _requireMutationRow(data, 'saveJobOpportunity');
    if (row['isSaved'] != true) {
      throw Exception('Failed to save job opportunity');
    }
  }

  Future<void> adminPauseJob(String jobOpportunityId, {String? reason}) async {
    final mutation = r'''
      mutation AdminPause($input: AdminJobModerationInput!) {
        adminPauseJobOpportunity(input: $input) { id status }
      }
    ''';
    await _client.query(
      mutation,
      variables: {
        'input': {
          'jobOpportunityId': jobOpportunityId,
          if (reason != null) 'reason': reason,
        },
      },
    );
  }

  Future<void> adminRemoveJob(String jobOpportunityId, String reason) async {
    final mutation = r'''
      mutation AdminRemove($input: AdminJobModerationInput!) {
        adminRemoveJobOpportunity(input: $input) { id status }
      }
    ''';
    await _client.query(
      mutation,
      variables: {
        'input': {'jobOpportunityId': jobOpportunityId, 'reason': reason},
      },
    );
  }

  Future<String> downloadApplicationCredential({
    required String applicationId,
    required String documentId,
    required String fileName,
  }) async {
    final response = await _api.dio.get<List<int>>(
      '/agency/job-applications/$applicationId/credentials/$documentId/file',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(response.data ?? []);
    return downloadBytes(bytes, fileName);
  }

  Future<List<HireOnboardingModel>> fetchAgencyHireOnboardings() async {
    final result = await _client.query(r'''
      query {
        agencyHireOnboardings {
          agencyTherapistLinkId therapistId therapistName agencyId agencyName
          completedCount totalCount isComplete
          steps { key label complete completedAt therapistCanComplete }
        }
      }
    ''');
    final list = _data(result)['agencyHireOnboardings'] as List<dynamic>? ?? [];
    return list
        .map((e) => HireOnboardingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<HireOnboardingModel>> fetchMyHireOnboardings() async {
    final result = await _client.query(r'''
      query {
        myHireOnboardings {
          agencyTherapistLinkId therapistId therapistName agencyId agencyName
          completedCount totalCount isComplete
          steps { key label complete completedAt therapistCanComplete }
        }
      }
    ''');
    final list = _data(result)['myHireOnboardings'] as List<dynamic>? ?? [];
    return list
        .map((e) => HireOnboardingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<HireOnboardingModel> updateHireOnboardingStep({
    required String agencyTherapistLinkId,
    required String step,
    required bool complete,
  }) async {
    final mutation = r'''
      mutation UpdateHireOnboarding($input: UpdateHireOnboardingStepInput!) {
        updateHireOnboardingStep(input: $input) {
          agencyTherapistLinkId therapistId therapistName agencyId agencyName
          completedCount totalCount isComplete
          steps { key label complete completedAt therapistCanComplete }
        }
      }
    ''';
    final result = await _client.query(
      mutation,
      variables: {
        'input': {
          'agencyTherapistLinkId': agencyTherapistLinkId,
          'step': step,
          'complete': complete,
        },
      },
    );
    return HireOnboardingModel.fromJson(
      _requireMutationRow(_data(result), 'updateHireOnboardingStep'),
    );
  }
}

final jobOpportunitiesRepositoryProvider = Provider<JobOpportunitiesRepository>(
  (ref) => JobOpportunitiesRepository(
    ref.watch(graphqlClientProvider),
    ref.watch(apiClientProvider),
  ),
);

final agencyChildServiceNeedsProvider =
    FutureProvider.autoDispose<List<ChildServiceNeedModel>>((ref) {
  return ref.watch(jobOpportunitiesRepositoryProvider).fetchChildServiceNeeds();
});

final agencyJobOpportunitiesProvider =
    FutureProvider.autoDispose<List<JobOpportunityModel>>((ref) {
  return ref
      .watch(jobOpportunitiesRepositoryProvider)
      .fetchAgencyOpportunities();
});

final therapistJobBrowseProvider =
    FutureProvider.autoDispose<List<JobOpportunityModel>>((ref) {
  return ref.watch(jobOpportunitiesRepositoryProvider).browseJobOpportunities();
});

final therapistMyJobApplicationsProvider =
    FutureProvider.autoDispose<List<JobApplicationModel>>((ref) {
  return ref.watch(jobOpportunitiesRepositoryProvider).fetchMyApplications();
});

final therapistSavedJobsProvider =
    FutureProvider.autoDispose<List<JobOpportunityModel>>((ref) {
  return ref
      .watch(jobOpportunitiesRepositoryProvider)
      .fetchSavedJobOpportunities();
});

final therapistJobOpportunityProvider = FutureProvider.autoDispose
    .family<JobOpportunityModel?, String>((ref, jobOpportunityId) {
  return ref
      .watch(jobOpportunitiesRepositoryProvider)
      .fetchJobOpportunity(jobOpportunityId);
});

final agencyJobApplicationsProvider = FutureProvider.autoDispose
    .family<List<JobApplicationModel>, String?>((ref, jobOpportunityId) {
  return ref
      .watch(jobOpportunitiesRepositoryProvider)
      .fetchAgencyApplications(jobOpportunityId: jobOpportunityId);
});

final therapistJobInvitesProvider =
    FutureProvider.autoDispose<List<JobOpportunityInviteModel>>((ref) {
  return ref.watch(jobOpportunitiesRepositoryProvider).fetchMyJobInvites();
});

final adminJobOpportunitiesProvider =
    FutureProvider.autoDispose<List<JobOpportunityModel>>((ref) {
  return ref.watch(jobOpportunitiesRepositoryProvider).adminJobOpportunities();
});

final adminJobMarketplaceAuditProvider =
    FutureProvider.autoDispose<List<JobMarketplaceAuditLogModel>>((ref) {
  return ref.watch(jobOpportunitiesRepositoryProvider).adminAuditLogs();
});

final adminJobApplicationsProvider =
    FutureProvider.autoDispose<List<JobApplicationModel>>((ref) {
  return ref.watch(jobOpportunitiesRepositoryProvider).fetchAdminApplications();
});

final agencyJobInterviewsProvider =
    FutureProvider.autoDispose<List<JobInterviewModel>>((ref) {
  final now = DateTime.now();
  return ref.watch(jobOpportunitiesRepositoryProvider).fetchAgencyInterviews(
        from: DateTime(now.year, now.month, now.day).subtract(
          const Duration(days: 7),
        ),
        to: now.add(const Duration(days: 60)),
      );
});

final therapistJobInterviewsProvider =
    FutureProvider.autoDispose<List<JobInterviewModel>>((ref) {
  return ref.watch(jobOpportunitiesRepositoryProvider).fetchMyJobInterviews();
});

final agencyHiringPipelineSummaryProvider =
    FutureProvider.autoDispose<AgencyHiringPipelineSummaryModel>((ref) {
  return ref
      .watch(jobOpportunitiesRepositoryProvider)
      .fetchAgencyHiringPipelineSummary();
});

final agencyHireOnboardingsProvider =
    FutureProvider.autoDispose<List<HireOnboardingModel>>((ref) {
  return ref
      .watch(jobOpportunitiesRepositoryProvider)
      .fetchAgencyHireOnboardings();
});

final myHireOnboardingsProvider =
    FutureProvider.autoDispose<List<HireOnboardingModel>>((ref) {
  return ref.watch(jobOpportunitiesRepositoryProvider).fetchMyHireOnboardings();
});

enum AgencyApplicantFilter { all, needsAction, offerSent, hired }

bool matchesAgencyApplicantFilter(
  JobApplicationModel app,
  AgencyApplicantFilter filter,
) {
  switch (filter) {
    case AgencyApplicantFilter.all:
      return true;
    case AgencyApplicantFilter.needsAction:
      if (app.status == 'NEW_APPLICANT' || app.status == 'APPROVED') {
        return true;
      }
      return app.status == 'CREDENTIAL_REVIEW' &&
          app.credentialDocuments.isNotEmpty;
    case AgencyApplicantFilter.offerSent:
      return app.status == 'OFFER_SENT';
    case AgencyApplicantFilter.hired:
      return app.status == 'HIRED_CONTRACTED';
  }
}

final agencyApplicantFilterProvider = StateProvider.autoDispose
    .family<AgencyApplicantFilter, String>(
  (ref, jobOpportunityId) => AgencyApplicantFilter.all,
);
