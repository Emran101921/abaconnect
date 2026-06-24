import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/graphql_client.dart';
import '../../../core/providers/app_providers.dart';

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
    this.publishedAt,
    this.isSaved,
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
  final DateTime? publishedAt;
  final bool? isSaved;

  factory JobOpportunityModel.fromJson(Map<String, dynamic> json) {
    return JobOpportunityModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      serviceType: json['serviceType'] as String? ?? 'OTHER',
      serviceTypeLabel: json['serviceTypeLabel'] as String? ?? '',
      status: json['status'] as String? ?? 'DRAFT',
      locationAreaLabel: json['locationAreaLabel'] as String? ?? '',
      zipCode: json['zipCode'] as String? ?? '',
      locationModality: json['locationModality'] as String? ?? 'IN_PERSON',
      disclaimer: json['disclaimer'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      publicDescription: json['publicDescription'] as String?,
      borough: json['borough'] as String?,
      county: json['county'] as String?,
      serviceRadiusMiles: json['serviceRadiusMiles'] as int?,
      distanceMiles: (json['distanceMiles'] as num?)?.toDouble(),
      languageRequirement: json['languageRequirement'] as String?,
      employmentType: json['employmentType'] as String?,
      payRateDisplay: json['payRateDisplay'] as String?,
      requiredExperience: json['requiredExperience'] as String?,
      agencyName: json['agencyName'] as String?,
      applicationCount: json['applicationCount'] as int?,
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'] as String)
          : null,
      isSaved: json['isSaved'] as bool?,
    );
  }
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

  factory ChildServiceNeedModel.fromJson(Map<String, dynamic> json) {
    return ChildServiceNeedModel(
      id: json['id'] as String,
      serviceType: json['serviceType'] as String? ?? 'OTHER',
      status: json['status'] as String? ?? 'OPEN',
      childDisplayName: json['childDisplayName'] as String? ?? 'Child',
      createdAt: DateTime.parse(json['createdAt'] as String),
      internalNotes: json['internalNotes'] as String?,
      jobOpportunityId: json['jobOpportunityId'] as String?,
      jobOpportunityTitle: json['jobOpportunityTitle'] as String?,
      jobOpportunityStatus: json['jobOpportunityStatus'] as String?,
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

  factory JobApplicationModel.fromJson(Map<String, dynamic> json) {
    return JobApplicationModel(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'NEW_APPLICANT',
      therapistName: json['therapistName'] as String? ?? '',
      jobOpportunityId: json['jobOpportunityId'] as String? ?? '',
      jobTitle: json['jobTitle'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      message: json['message'] as String?,
      therapistEmail: json['therapistEmail'] as String?,
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
      id: json['id'] as String,
      eventType: json['eventType'] as String? ?? '',
      entityType: json['entityType'] as String? ?? '',
      entityId: json['entityId'] as String? ?? '',
      metadataJson: json['metadataJson'] as String? ?? '{}',
      createdAt: DateTime.parse(json['createdAt'] as String),
      actorName: json['actorName'] as String?,
    );
  }
}

class JobOpportunitiesRepository {
  JobOpportunitiesRepository(this._client);

  final GraphqlClient _client;

  Map<String, dynamic> _data(Map<String, dynamic> result) =>
      result['data'] as Map<String, dynamic>? ?? {};

  Future<List<ChildServiceNeedModel>> fetchChildServiceNeeds() async {
    const query = r'''
      query MyChildServiceNeeds {
        myChildServiceNeeds {
          id serviceType status childDisplayName internalNotes
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
    const query = r'''
      query MyAgencyJobOpportunities {
        myAgencyJobOpportunities {
          id title serviceType serviceTypeLabel status locationAreaLabel zipCode
          locationModality disclaimer publicDescription applicationCount
          payRateDisplay publishedAt createdAt
        }
      }
    ''';
    final data = _data(await _client.query(query));
    final list = data['myAgencyJobOpportunities'] as List<dynamic>? ?? [];
    return list
        .map((e) => JobOpportunityModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<JobApplicationModel>> fetchAgencyApplications({
    String? jobOpportunityId,
  }) async {
    const query = r'''
      query AgencyJobApplications($jobOpportunityId: ID) {
        agencyJobApplications(jobOpportunityId: $jobOpportunityId) {
          id status message therapistName therapistEmail
          jobOpportunityId jobTitle createdAt updatedAt
        }
      }
    ''';
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
    const query = r'''
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
    const query = r'''
      query JobOpportunity($jobOpportunityId: ID!) {
        jobOpportunity(jobOpportunityId: $jobOpportunityId) {
          id title serviceType serviceTypeLabel status locationAreaLabel zipCode
          distanceMiles locationModality disclaimer publicDescription
          payRateDisplay agencyName applicationCount publishedAt createdAt
          languageRequirement employmentType requiredExperience borough county
          isSaved
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
    const query = r'''
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
    const query = r'''
      query MyJobApplications {
        myJobApplications {
          id status message therapistName jobOpportunityId jobTitle
          createdAt updatedAt
        }
      }
    ''';
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
    const mutation = r'''
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
      data['createChildServiceNeed'] as Map<String, dynamic>,
    );
  }

  Future<JobOpportunityModel> generateJobOpportunity(
    String childServiceNeedId,
  ) async {
    const mutation = r'''
      mutation GenerateJobOpportunity($id: ID!) {
        generateJobOpportunity(childServiceNeedId: $id) {
          id title status disclaimer locationAreaLabel createdAt
        }
      }
    ''';
    final data = _data(
      await _client.query(
        mutation,
        variables: {'id': childServiceNeedId},
      ),
    );
    return JobOpportunityModel.fromJson(
      data['generateJobOpportunity'] as Map<String, dynamic>,
    );
  }

  Future<JobOpportunityModel> updateJobOpportunity({
    required String jobOpportunityId,
    String? title,
    String? publicDescription,
    String? borough,
    String? county,
    String? payRateDisplay,
  }) async {
    const mutation = r'''
      mutation UpdateJobOpportunity($input: UpdateJobOpportunityInput!) {
        updateJobOpportunity(input: $input) {
          id title status publicDescription disclaimer
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
    return JobOpportunityModel.fromJson(
      data['updateJobOpportunity'] as Map<String, dynamic>,
    );
  }

  Future<JobOpportunityModel> publishJobOpportunity(
    String jobOpportunityId,
  ) async {
    const mutation = r'''
      mutation PublishJobOpportunity($id: ID!) {
        publishJobOpportunity(jobOpportunityId: $id) {
          id title status publishedAt disclaimer
        }
      }
    ''';
    final data = _data(
      await _client.query(
        mutation,
        variables: {'id': jobOpportunityId},
      ),
    );
    return JobOpportunityModel.fromJson(
      data['publishJobOpportunity'] as Map<String, dynamic>,
    );
  }

  Future<JobApplicationModel> applyToJobOpportunity({
    required String jobOpportunityId,
    String? message,
  }) async {
    const mutation = r'''
      mutation ApplyToJobOpportunity($input: ApplyToJobOpportunityInput!) {
        applyToJobOpportunity(input: $input) {
          id status jobTitle createdAt updatedAt
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
      data['applyToJobOpportunity'] as Map<String, dynamic>,
    );
  }

  Future<JobApplicationModel> withdrawJobApplication(
    String applicationId,
  ) async {
    const mutation = r'''
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
      data['withdrawJobApplication'] as Map<String, dynamic>,
    );
  }

  Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
    String? note,
  }) async {
    const mutation = r'''
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

  Future<List<JobOpportunityModel>> adminJobOpportunities() async {
    const query = r'''
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

  Future<List<JobMarketplaceAuditLogModel>> adminAuditLogs() async {
    const query = r'''
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

  Future<void> unsaveJobOpportunity(String jobOpportunityId) async {
    const mutation = r'''
      mutation UnsaveJobOpportunity($id: ID!) {
        unsaveJobOpportunity(jobOpportunityId: $id)
      }
    ''';
    await _client.query(
      mutation,
      variables: {'id': jobOpportunityId},
    );
  }

  Future<JobOpportunityModel> saveJobOpportunity(String jobOpportunityId) async {
    const mutation = r'''
      mutation SaveJobOpportunity($id: ID!) {
        saveJobOpportunity(jobOpportunityId: $id) {
          id title isSaved
        }
      }
    ''';
    final data = _data(
      await _client.query(
        mutation,
        variables: {'id': jobOpportunityId},
      ),
    );
    return JobOpportunityModel.fromJson(
      data['saveJobOpportunity'] as Map<String, dynamic>,
    );
  }

  Future<void> adminPauseJob(String jobOpportunityId, {String? reason}) async {
    const mutation = r'''
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
    const mutation = r'''
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
}

final jobOpportunitiesRepositoryProvider = Provider<JobOpportunitiesRepository>(
  (ref) => JobOpportunitiesRepository(ref.watch(graphqlClientProvider)),
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

final adminJobOpportunitiesProvider =
    FutureProvider.autoDispose<List<JobOpportunityModel>>((ref) {
  return ref.watch(jobOpportunitiesRepositoryProvider).adminJobOpportunities();
});

final adminJobMarketplaceAuditProvider =
    FutureProvider.autoDispose<List<JobMarketplaceAuditLogModel>>((ref) {
  return ref.watch(jobOpportunitiesRepositoryProvider).adminAuditLogs();
});
