import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/graphql_client.dart';
import '../../../core/providers/app_providers.dart';

Map<String, dynamic> _graphqlData(Map<String, dynamic> result) =>
    (result['data'] as Map<String, dynamic>?) ?? result;

class EiBillingDashboardModel {
  const EiBillingDashboardModel({
    required this.totalRecords,
    required this.readyAgencyReview,
    required this.missingInformation,
    required this.submitted,
    required this.paid,
    required this.denialsAndCorrections,
  });

  final int totalRecords;
  final int readyAgencyReview;
  final int missingInformation;
  final int submitted;
  final int paid;
  final int denialsAndCorrections;

  factory EiBillingDashboardModel.fromJson(Map<String, dynamic> json) {
    return EiBillingDashboardModel(
      totalRecords: json['totalRecords'] as int? ?? 0,
      readyAgencyReview: json['readyAgencyReview'] as int? ?? 0,
      missingInformation: json['missingInformation'] as int? ?? 0,
      submitted: json['submitted'] as int? ?? 0,
      paid: json['paid'] as int? ?? 0,
      denialsAndCorrections: json['denialsAndCorrections'] as int? ?? 0,
    );
  }
}

class EiDenialListItemModel {
  const EiDenialListItemModel({
    required this.id,
    required this.code,
    required this.reason,
    required this.correctionStatus,
    required this.recordId,
    required this.recordQueueStatus,
    this.payerName,
    this.receivedAt,
    this.childDisplayName,
    this.therapistName,
  });

  final String id;
  final String code;
  final String reason;
  final String correctionStatus;
  final String recordId;
  final String recordQueueStatus;
  final String? payerName;
  final DateTime? receivedAt;
  final String? childDisplayName;
  final String? therapistName;

  factory EiDenialListItemModel.fromJson(Map<String, dynamic> json) {
    return EiDenialListItemModel(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      correctionStatus: json['correctionStatus'] as String? ?? 'OPEN',
      recordId: json['recordId'] as String,
      recordQueueStatus: json['recordQueueStatus'] as String? ?? '',
      payerName: json['payerName'] as String?,
      receivedAt: json['receivedAt'] != null
          ? DateTime.tryParse(json['receivedAt'] as String)
          : null,
      childDisplayName: json['childDisplayName'] as String?,
      therapistName: json['therapistName'] as String?,
    );
  }
}

class EiDenialModel {
  const EiDenialModel({
    required this.id,
    required this.code,
    required this.reason,
    required this.correctionStatus,
    this.payerName,
    this.receivedAt,
  });

  final String id;
  final String code;
  final String reason;
  final String correctionStatus;
  final String? payerName;
  final DateTime? receivedAt;

  factory EiDenialModel.fromJson(Map<String, dynamic> json) {
    return EiDenialModel(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      correctionStatus: json['correctionStatus'] as String? ?? 'OPEN',
      payerName: json['payerName'] as String?,
      receivedAt: json['receivedAt'] != null
          ? DateTime.tryParse(json['receivedAt'] as String)
          : null,
    );
  }
}

class EiPaymentModel {
  const EiPaymentModel({
    required this.id,
    required this.paidAmount,
    required this.reconciliationStatus,
    required this.postedAt,
    this.allowedAmount,
    this.eftReference,
  });

  final String id;
  final double paidAmount;
  final String reconciliationStatus;
  final DateTime postedAt;
  final double? allowedAmount;
  final String? eftReference;

  factory EiPaymentModel.fromJson(Map<String, dynamic> json) {
    return EiPaymentModel(
      id: json['id'] as String,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
      reconciliationStatus: json['reconciliationStatus'] as String? ?? 'UNRECONCILED',
      postedAt: DateTime.parse(json['postedAt'] as String),
      allowedAmount: (json['allowedAmount'] as num?)?.toDouble(),
      eftReference: json['eftReference'] as String?,
    );
  }
}

class EiBillingRecordModel {
  const EiBillingRecordModel({
    required this.id,
    required this.queueStatus,
    required this.units,
    required this.serviceDate,
    this.agencyId,
    this.childId,
    this.childDisplayName,
    this.therapistName,
    this.sessionId,
    this.lockedAt,
    this.submittedAt,
    this.externalReferenceId,
    this.validationIssues = const [],
    this.denials = const [],
    this.payments = const [],
  });

  final String id;
  final String queueStatus;
  final double units;
  final DateTime serviceDate;
  final String? agencyId;
  final String? childId;
  final String? childDisplayName;
  final String? therapistName;
  final String? sessionId;
  final DateTime? lockedAt;
  final DateTime? submittedAt;
  final String? externalReferenceId;
  final List<EiValidationIssueModel> validationIssues;
  final List<EiDenialModel> denials;
  final List<EiPaymentModel> payments;

  factory EiBillingRecordModel.fromJson(Map<String, dynamic> json) {
    final issues = (json['validationIssues'] as List<dynamic>? ?? [])
        .map((e) => EiValidationIssueModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final denials = (json['denials'] as List<dynamic>? ?? [])
        .map((e) => EiDenialModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final payments = (json['payments'] as List<dynamic>? ?? [])
        .map((e) => EiPaymentModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return EiBillingRecordModel(
      id: json['id'] as String,
      queueStatus: json['queueStatus'] as String? ?? 'DRAFT_INCOMPLETE',
      units: (json['units'] as num?)?.toDouble() ?? 0,
      serviceDate: DateTime.parse(json['serviceDate'] as String),
      agencyId: json['agencyId'] as String?,
      childId: json['childId'] as String?,
      childDisplayName: json['childDisplayName'] as String?,
      therapistName: json['therapistName'] as String?,
      sessionId: json['sessionId'] as String?,
      lockedAt: json['lockedAt'] != null
          ? DateTime.tryParse(json['lockedAt'] as String)
          : null,
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'] as String)
          : null,
      externalReferenceId: json['externalReferenceId'] as String?,
      validationIssues: issues,
      denials: denials,
      payments: payments,
    );
  }
}

class EiValidationIssueModel {
  const EiValidationIssueModel({
    required this.code,
    required this.severity,
    required this.message,
    this.resolved = false,
  });

  final String code;
  final String severity;
  final String message;
  final bool resolved;

  factory EiValidationIssueModel.fromJson(Map<String, dynamic> json) {
    return EiValidationIssueModel(
      code: json['code'] as String? ?? '',
      severity: json['severity'] as String? ?? 'ERROR',
      message: json['message'] as String? ?? '',
      resolved: json['resolved'] as bool? ?? false,
    );
  }
}

class EiAgencyBillingProfileModel {
  const EiAgencyBillingProfileModel({
    required this.id,
    required this.legalName,
    required this.enrollmentComplete,
    this.agencyId,
    this.npi,
    this.medicaidProviderId,
    this.ein,
    this.etin,
    this.eiHubReferenceId,
    this.eftEnrollmentStatus,
    this.baaSignedAt,
    this.city,
    this.state,
  });

  final String id;
  final String legalName;
  final bool enrollmentComplete;
  final String? agencyId;
  final String? npi;
  final String? medicaidProviderId;
  final String? ein;
  final String? etin;
  final String? eiHubReferenceId;
  final String? eftEnrollmentStatus;
  final DateTime? baaSignedAt;
  final String? city;
  final String? state;

  factory EiAgencyBillingProfileModel.fromJson(Map<String, dynamic> json) {
    return EiAgencyBillingProfileModel(
      id: json['id'] as String,
      legalName: json['legalName'] as String? ?? '',
      enrollmentComplete: json['enrollmentComplete'] as bool? ?? false,
      agencyId: json['agencyId'] as String?,
      npi: json['npi'] as String?,
      medicaidProviderId: json['medicaidProviderId'] as String?,
      ein: json['ein'] as String?,
      etin: json['etin'] as String?,
      eiHubReferenceId: json['eiHubReferenceId'] as String?,
      eftEnrollmentStatus: json['eftEnrollmentStatus'] as String?,
      baaSignedAt: json['baaSignedAt'] != null
          ? DateTime.tryParse(json['baaSignedAt'] as String)
          : null,
      city: json['city'] as String?,
      state: json['state'] as String?,
    );
  }
}

class EiProviderEnrollmentModel {
  const EiProviderEnrollmentModel({
    required this.id,
    required this.therapistName,
    required this.credentialStatus,
    required this.isActive,
    this.therapistId,
    this.renderingNpi,
    this.discipline,
    this.eiCategory,
    this.medicaidEnrollmentStatus,
    this.licenseExpiry,
  });

  final String id;
  final String therapistName;
  final String credentialStatus;
  final bool isActive;
  final String? therapistId;
  final String? renderingNpi;
  final String? discipline;
  final String? eiCategory;
  final String? medicaidEnrollmentStatus;
  final DateTime? licenseExpiry;

  factory EiProviderEnrollmentModel.fromJson(Map<String, dynamic> json) {
    return EiProviderEnrollmentModel(
      id: json['id'] as String,
      therapistName: json['therapistName'] as String? ?? 'Provider',
      credentialStatus: json['credentialStatus'] as String? ?? 'PENDING',
      isActive: json['isActive'] as bool? ?? false,
      therapistId: json['therapistId'] as String?,
      renderingNpi: json['renderingNpi'] as String?,
      discipline: json['discipline'] as String?,
      eiCategory: json['eiCategory'] as String?,
      medicaidEnrollmentStatus: json['medicaidEnrollmentStatus'] as String?,
      licenseExpiry: json['licenseExpiry'] != null
          ? DateTime.tryParse(json['licenseExpiry'] as String)
          : null,
    );
  }
}

class EiCaseBillingProfileModel {
  const EiCaseBillingProfileModel({
    required this.id,
    required this.childId,
    required this.consentStatus,
    this.childDisplayName,
    this.eiCaseId,
    this.municipality,
    this.ifspAuthorizationNumber,
    this.serviceType,
    this.medicaidCin,
    this.authorizationStartDate,
    this.authorizationEndDate,
    this.placeOfService,
  });

  final String id;
  final String childId;
  final String consentStatus;
  final String? childDisplayName;
  final String? eiCaseId;
  final String? municipality;
  final String? ifspAuthorizationNumber;
  final String? serviceType;
  final String? medicaidCin;
  final DateTime? authorizationStartDate;
  final DateTime? authorizationEndDate;
  final String? placeOfService;

  factory EiCaseBillingProfileModel.fromJson(Map<String, dynamic> json) {
    return EiCaseBillingProfileModel(
      id: json['id'] as String,
      childId: json['childId'] as String,
      consentStatus: json['consentStatus'] as String? ?? 'PENDING',
      childDisplayName: json['childDisplayName'] as String?,
      eiCaseId: json['eiCaseId'] as String?,
      municipality: json['municipality'] as String?,
      ifspAuthorizationNumber: json['ifspAuthorizationNumber'] as String?,
      serviceType: json['serviceType'] as String?,
      medicaidCin: json['medicaidCin'] as String?,
      authorizationStartDate: json['authorizationStartDate'] != null
          ? DateTime.tryParse(json['authorizationStartDate'] as String)
          : null,
      authorizationEndDate: json['authorizationEndDate'] != null
          ? DateTime.tryParse(json['authorizationEndDate'] as String)
          : null,
      placeOfService: json['placeOfService'] as String?,
    );
  }
}

class EiBillingExportResultModel {
  const EiBillingExportResultModel({
    required this.artifactType,
    required this.payload,
    required this.fileName,
  });

  final String artifactType;
  final String payload;
  final String fileName;

  factory EiBillingExportResultModel.fromJson(Map<String, dynamic> json) {
    return EiBillingExportResultModel(
      artifactType: json['artifactType'] as String? ?? '',
      payload: json['payload'] as String? ?? '',
      fileName: json['fileName'] as String? ?? 'export.txt',
    );
  }
}

class EiBillingSubmitResultModel {
  const EiBillingSubmitResultModel({
    required this.accepted,
    required this.externalReferenceId,
    required this.message,
    required this.record,
  });

  final bool accepted;
  final String externalReferenceId;
  final String message;
  final EiBillingRecordModel record;

  factory EiBillingSubmitResultModel.fromJson(Map<String, dynamic> json) {
    return EiBillingSubmitResultModel(
      accepted: json['accepted'] as bool? ?? false,
      externalReferenceId: json['externalReferenceId'] as String? ?? '',
      message: json['message'] as String? ?? '',
      record: EiBillingRecordModel.fromJson(
        json['record'] as Map<String, dynamic>,
      ),
    );
  }
}

class EiClearinghouseConfigModel {
  const EiClearinghouseConfigModel({
    required this.id,
    required this.name,
    required this.workflow,
    required this.testMode,
    required this.isActive,
    this.tradingPartnerId,
    this.baaSignedAt,
    this.lastConnectionTestAt,
    this.lastConnectionTestResult,
  });

  final String id;
  final String name;
  final String workflow;
  final bool testMode;
  final bool isActive;
  final String? tradingPartnerId;
  final DateTime? baaSignedAt;
  final DateTime? lastConnectionTestAt;
  final String? lastConnectionTestResult;

  factory EiClearinghouseConfigModel.fromJson(Map<String, dynamic> json) {
    return EiClearinghouseConfigModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      workflow: json['workflow'] as String? ?? 'EI_HUB',
      testMode: json['testMode'] as bool? ?? true,
      isActive: json['isActive'] as bool? ?? false,
      tradingPartnerId: json['tradingPartnerId'] as String?,
      baaSignedAt: json['baaSignedAt'] != null
          ? DateTime.tryParse(json['baaSignedAt'] as String)
          : null,
      lastConnectionTestAt: json['lastConnectionTestAt'] != null
          ? DateTime.tryParse(json['lastConnectionTestAt'] as String)
          : null,
      lastConnectionTestResult: json['lastConnectionTestResult'] as String?,
    );
  }
}

class EiClearinghouseTestResultModel {
  const EiClearinghouseTestResultModel({
    required this.success,
    required this.message,
    required this.config,
  });

  final bool success;
  final String message;
  final EiClearinghouseConfigModel config;

  factory EiClearinghouseTestResultModel.fromJson(Map<String, dynamic> json) {
    return EiClearinghouseTestResultModel(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      config: EiClearinghouseConfigModel.fromJson(
        json['config'] as Map<String, dynamic>,
      ),
    );
  }
}

class EiBillingReportRowModel {
  const EiBillingReportRowModel({
    required this.status,
    required this.count,
    this.billedTotal,
    this.allowedTotal,
  });

  final String status;
  final int count;
  final double? billedTotal;
  final double? allowedTotal;

  factory EiBillingReportRowModel.fromJson(Map<String, dynamic> json) {
    return EiBillingReportRowModel(
      status: json['status'] as String? ?? '',
      count: json['count'] as int? ?? 0,
      billedTotal: (json['billedTotal'] as num?)?.toDouble(),
      allowedTotal: (json['allowedTotal'] as num?)?.toDouble(),
    );
  }
}

class EiBillingAuditLogModel {
  const EiBillingAuditLogModel({
    required this.id,
    required this.action,
    required this.createdAt,
    this.actorName,
  });

  final String id;
  final String action;
  final DateTime createdAt;
  final String? actorName;

  factory EiBillingAuditLogModel.fromJson(Map<String, dynamic> json) {
    return EiBillingAuditLogModel(
      id: json['id'] as String,
      action: json['action'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      actorName: json['actorName'] as String?,
    );
  }
}

const eiBillingRecordFields = r'''
  id
  agencyId
  childId
  queueStatus
  units
  serviceDate
  childDisplayName
  therapistName
  sessionId
  lockedAt
  submittedAt
  externalReferenceId
  validationIssues {
    code
    severity
    message
    resolved
  }
  denials {
    id
    code
    reason
    correctionStatus
    payerName
    receivedAt
  }
  payments {
    id
    paidAmount
    allowedAmount
    reconciliationStatus
    postedAt
    eftReference
  }
''';

class EiBillingRepository {
  EiBillingRepository(this._client);

  final GraphqlClient _client;

  Future<EiBillingDashboardModel> fetchDashboard({String? agencyId}) async {
    const query = r'''
      query EiBillingDashboard($agencyId: ID) {
        eiBillingDashboard(agencyId: $agencyId) {
          totalRecords
          readyAgencyReview
          missingInformation
          submitted
          paid
          denialsAndCorrections
        }
      }
    ''';
    final result = await _client.query(query, variables: {
      if (agencyId != null) 'agencyId': agencyId,
    });
    return EiBillingDashboardModel.fromJson(
      _graphqlData(result)['eiBillingDashboard'] as Map<String, dynamic>,
    );
  }

  Future<List<EiBillingRecordModel>> fetchQueue({
    String? status,
    int? take,
  }) async {
    const query = r'''
      query EiBillingQueue($filter: EiBillingQueueFilterInput) {
        eiBillingQueue(filter: $filter) {
          id
          queueStatus
          units
          serviceDate
          childDisplayName
          therapistName
          sessionId
          validationIssues {
            code
            severity
            message
          }
        }
      }
    ''';
    final filter = <String, dynamic>{
      if (status != null) 'status': status,
      if (take != null) 'take': take,
    };
    final result = await _client.query(
      query,
      variables: {if (filter.isNotEmpty) 'filter': filter},
    );
    return (_graphqlData(result)['eiBillingQueue'] as List<dynamic>)
        .map((e) => EiBillingRecordModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EiBillingRecordModel> fetchRecord(String id) async {
    const query = r'''
      query EiBillingRecord($id: ID!) {
        eiBillingRecord(id: $id) {
          id
          agencyId
          childId
          queueStatus
          units
          serviceDate
          childDisplayName
          therapistName
          sessionId
          lockedAt
          submittedAt
          externalReferenceId
          validationIssues {
            code
            severity
            message
            resolved
          }
          denials {
            id
            code
            reason
            correctionStatus
            payerName
            receivedAt
          }
          payments {
            id
            paidAmount
            allowedAmount
            reconciliationStatus
            postedAt
            eftReference
          }
        }
      }
    ''';
    final result = await _client.query(query, variables: {'id': id});
    final raw = _graphqlData(result)['eiBillingRecord'] as Map<String, dynamic>?;
    if (raw == null) throw Exception('EI billing record not found');
    return EiBillingRecordModel.fromJson(raw);
  }

  Future<EiBillingRecordModel> validateRecord(String recordId) async {
    final mutation = '''
      mutation ValidateEiBillingRecord(\$recordId: ID!) {
        validateEiBillingRecord(recordId: \$recordId) {
$eiBillingRecordFields
        }
      }
    ''';
    final result = await _client.query(
      mutation,
      variables: {'recordId': recordId},
    );
    final raw =
        _graphqlData(result)['validateEiBillingRecord'] as Map<String, dynamic>?;
    if (raw == null) throw Exception('Validation failed');
    return EiBillingRecordModel.fromJson(raw);
  }

  Future<EiBillingRecordModel> transitionQueue(
    String recordId,
    String targetStatus,
  ) async {
    final mutation = '''
      mutation TransitionEiBillingQueue(\$input: TransitionEiBillingQueueInput!) {
        transitionEiBillingQueue(input: \$input) {
$eiBillingRecordFields
        }
      }
    ''';
    final result = await _client.query(
      mutation,
      variables: {
        'input': {
          'recordId': recordId,
          'targetStatus': targetStatus,
        },
      },
    );
    final raw = _graphqlData(result)['transitionEiBillingQueue']
        as Map<String, dynamic>?;
    if (raw == null) throw Exception('Queue transition failed');
    return EiBillingRecordModel.fromJson(raw);
  }

  Future<EiAgencyBillingProfileModel> upsertAgencyProfile({
    String? agencyId,
    required String legalName,
    String? npi,
    String? medicaidProviderId,
    String? ein,
    String? etin,
    String? eiHubReferenceId,
    bool? enrollmentComplete,
    DateTime? baaSignedAt,
    String? city,
    String? state,
    String? zipCode,
  }) async {
    const mutation = r'''
      mutation UpsertEiAgencyBillingProfile($input: UpsertEiAgencyBillingProfileInput!) {
        upsertEiAgencyBillingProfile(input: $input) {
          id
          agencyId
          legalName
          npi
          medicaidProviderId
          ein
          etin
          eiHubReferenceId
          eftEnrollmentStatus
          enrollmentComplete
          baaSignedAt
          city
          state
        }
      }
    ''';
    final result = await _client.query(
      mutation,
      variables: {
        'input': {
          if (agencyId != null) 'agencyId': agencyId,
          'legalName': legalName,
          if (npi != null) 'npi': npi,
          if (medicaidProviderId != null) 'medicaidProviderId': medicaidProviderId,
          if (ein != null) 'ein': ein,
          if (etin != null) 'etin': etin,
          if (eiHubReferenceId != null) 'eiHubReferenceId': eiHubReferenceId,
          if (enrollmentComplete != null) 'enrollmentComplete': enrollmentComplete,
          if (baaSignedAt != null)
            'baaSignedAt': baaSignedAt.toIso8601String(),
          if (city != null) 'city': city,
          if (state != null) 'state': state,
          if (zipCode != null) 'zipCode': zipCode,
        },
      },
    );
    final raw = _graphqlData(result)['upsertEiAgencyBillingProfile']
        as Map<String, dynamic>?;
    if (raw == null) throw Exception('Failed to save agency billing profile');
    return EiAgencyBillingProfileModel.fromJson(raw);
  }

  Future<EiProviderEnrollmentModel> upsertProviderEnrollment({
    String? agencyId,
    required String therapistId,
    String? renderingNpi,
    String? discipline,
    String? eiCategory,
    String? medicaidEnrollmentStatus,
    String? credentialStatus,
    DateTime? licenseExpiry,
    bool? isActive,
  }) async {
    const mutation = r'''
      mutation UpsertEiProviderEnrollment($input: UpsertEiProviderEnrollmentInput!) {
        upsertEiProviderEnrollment(input: $input) {
          id
          therapistId
          therapistName
          renderingNpi
          discipline
          eiCategory
          medicaidEnrollmentStatus
          credentialStatus
          isActive
        }
      }
    ''';
    final result = await _client.query(
      mutation,
      variables: {
        'input': {
          if (agencyId != null) 'agencyId': agencyId,
          'therapistId': therapistId,
          if (renderingNpi != null) 'renderingNpi': renderingNpi,
          if (discipline != null) 'discipline': discipline,
          if (eiCategory != null) 'eiCategory': eiCategory,
          if (medicaidEnrollmentStatus != null)
            'medicaidEnrollmentStatus': medicaidEnrollmentStatus,
          if (credentialStatus != null) 'credentialStatus': credentialStatus,
          if (licenseExpiry != null)
            'licenseExpiry': licenseExpiry.toIso8601String(),
          if (isActive != null) 'isActive': isActive,
        },
      },
    );
    final raw = _graphqlData(result)['upsertEiProviderEnrollment']
        as Map<String, dynamic>?;
    if (raw == null) throw Exception('Failed to save provider enrollment');
    return EiProviderEnrollmentModel.fromJson(raw);
  }

  Future<EiCaseBillingProfileModel> upsertCaseProfile({
    String? agencyId,
    required String childId,
    String? eiCaseId,
    String? municipality,
    String? ifspAuthorizationNumber,
    String? serviceType,
    String? medicaidCin,
    String? consentStatus,
    DateTime? authorizationStartDate,
    DateTime? authorizationEndDate,
    String? placeOfService,
  }) async {
    const mutation = r'''
      mutation UpsertEiCaseBillingProfile($input: UpsertEiCaseBillingProfileInput!) {
        upsertEiCaseBillingProfile(input: $input) {
          id
          childId
          childDisplayName
          eiCaseId
          municipality
          ifspAuthorizationNumber
          serviceType
          medicaidCin
          consentStatus
        }
      }
    ''';
    final result = await _client.query(
      mutation,
      variables: {
        'input': {
          if (agencyId != null) 'agencyId': agencyId,
          'childId': childId,
          if (eiCaseId != null) 'eiCaseId': eiCaseId,
          if (municipality != null) 'municipality': municipality,
          if (ifspAuthorizationNumber != null)
            'ifspAuthorizationNumber': ifspAuthorizationNumber,
          if (serviceType != null) 'serviceType': serviceType,
          if (medicaidCin != null) 'medicaidCin': medicaidCin,
          if (consentStatus != null) 'consentStatus': consentStatus,
          if (authorizationStartDate != null)
            'authorizationStartDate':
                authorizationStartDate.toIso8601String(),
          if (authorizationEndDate != null)
            'authorizationEndDate': authorizationEndDate.toIso8601String(),
          if (placeOfService != null) 'placeOfService': placeOfService,
        },
      },
    );
    final raw = _graphqlData(result)['upsertEiCaseBillingProfile']
        as Map<String, dynamic>?;
    if (raw == null) throw Exception('Failed to save case billing profile');
    return EiCaseBillingProfileModel.fromJson(raw);
  }

  Future<EiCaseBillingProfileModel?> fetchCaseProfile(String childId) async {
    const query = r'''
      query EiCaseBillingProfile($childId: ID!) {
        eiCaseBillingProfile(childId: $childId) {
          id
          childId
          childDisplayName
          eiCaseId
          municipality
          ifspAuthorizationNumber
          serviceType
          medicaidCin
          consentStatus
        }
      }
    ''';
    final result = await _client.query(query, variables: {'childId': childId});
    final raw =
        _graphqlData(result)['eiCaseBillingProfile'] as Map<String, dynamic>?;
    if (raw == null) return null;
    return EiCaseBillingProfileModel.fromJson(raw);
  }

  Future<List<EiDenialListItemModel>> fetchDenials({String? agencyId}) async {
    const query = r'''
      query EiBillingDenials($agencyId: ID) {
        eiBillingDenials(agencyId: $agencyId) {
          id
          code
          reason
          payerName
          correctionStatus
          receivedAt
          recordId
          childDisplayName
          therapistName
          recordQueueStatus
        }
      }
    ''';
    final result = await _client.query(
      query,
      variables: {if (agencyId != null) 'agencyId': agencyId},
    );
    return (_graphqlData(result)['eiBillingDenials'] as List<dynamic>)
        .map((e) => EiDenialListItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> recordDenial({
    required String recordId,
    required String code,
    required String reason,
    String? payerName,
  }) async {
    const mutation = r'''
      mutation RecordEiDenial($input: RecordEiDenialInput!) {
        recordEiDenial(input: $input) {
          id
          code
          reason
        }
      }
    ''';
    final result = await _client.query(
      mutation,
      variables: {
        'input': {
          'recordId': recordId,
          'code': code,
          'reason': reason,
          if (payerName != null) 'payerName': payerName,
        },
      },
    );
    if (_graphqlData(result)['recordEiDenial'] == null) {
      throw Exception('Failed to record denial');
    }
  }

  Future<void> recordPayment({
    required String recordId,
    required double paidAmount,
    double? allowedAmount,
    String? eftReference,
    String? eraPlaceholder,
  }) async {
    const mutation = r'''
      mutation RecordEiPayment($input: RecordEiPaymentInput!) {
        recordEiPayment(input: $input) {
          id
          paidAmount
        }
      }
    ''';
    final result = await _client.query(
      mutation,
      variables: {
        'input': {
          'recordId': recordId,
          'paidAmount': paidAmount,
          if (allowedAmount != null) 'allowedAmount': allowedAmount,
          if (eftReference != null) 'eftReference': eftReference,
          if (eraPlaceholder != null) 'eraPlaceholder': eraPlaceholder,
        },
      },
    );
    if (_graphqlData(result)['recordEiPayment'] == null) {
      throw Exception('Failed to record payment');
    }
  }

  Future<void> importEiEraStub({
    required String recordId,
    required String eraJson,
  }) async {
    const mutation = r'''
      mutation ImportEiEraStub($input: ImportEiEraStubInput!) {
        importEiEraStub(input: $input) {
          id
          paidAmount
        }
      }
    ''';
    final result = await _client.query(
      mutation,
      variables: {
        'input': {
          'recordId': recordId,
          'eraJson': eraJson,
        },
      },
    );
    if (_graphqlData(result)['importEiEraStub'] == null) {
      throw Exception('Failed to import ERA stub');
    }
  }

  Future<EiBillingExportResultModel> exportRecord({
    required String recordId,
    required String workflow,
    required bool authorizedConfirm,
  }) async {
    const mutation = r'''
      mutation ExportEiBillingRecord($input: ExportEiBillingRecordInput!) {
        exportEiBillingRecord(input: $input) {
          artifactType
          payload
          fileName
        }
      }
    ''';
    final result = await _client.query(
      mutation,
      variables: {
        'input': {
          'recordId': recordId,
          'workflow': workflow,
          'authorizedConfirm': authorizedConfirm,
        },
      },
    );
    final raw = _graphqlData(result)['exportEiBillingRecord']
        as Map<String, dynamic>?;
    if (raw == null) throw Exception('Export failed');
    return EiBillingExportResultModel.fromJson(raw);
  }

  Future<EiBillingSubmitResultModel> submitRecord({
    required String recordId,
    required String workflow,
    required bool authorizedConfirm,
  }) async {
    final mutation = '''
      mutation SubmitEiBillingRecord(\$input: SubmitEiBillingRecordInput!) {
        submitEiBillingRecord(input: \$input) {
          accepted
          externalReferenceId
          message
          record {
$eiBillingRecordFields
          }
        }
      }
    ''';
    final result = await _client.query(
      mutation,
      variables: {
        'input': {
          'recordId': recordId,
          'workflow': workflow,
          'authorizedConfirm': authorizedConfirm,
        },
      },
    );
    final raw = _graphqlData(result)['submitEiBillingRecord']
        as Map<String, dynamic>?;
    if (raw == null) throw Exception('Submission failed');
    return EiBillingSubmitResultModel.fromJson(raw);
  }

  Future<void> lockSessionForBilling(String sessionId) async {
    final mutation = '''
      mutation LockEiSessionForBilling(\$sessionId: ID!) {
        lockEiSessionForBilling(sessionId: \$sessionId) {
$eiBillingRecordFields
        }
      }
    ''';
    final result = await _client.query(
      mutation,
      variables: {'sessionId': sessionId},
    );
    if (_graphqlData(result)['lockEiSessionForBilling'] == null) {
      throw Exception('Failed to lock session for billing');
    }
  }

  Future<EiBillingRecordModel> createFromSession({
    required String sessionId,
    String? agencyId,
  }) async {
    final mutation = '''
      mutation CreateEiBillingFromSession(\$sessionId: ID!, \$agencyId: ID) {
        createEiBillingFromSession(sessionId: \$sessionId, agencyId: \$agencyId) {
$eiBillingRecordFields
        }
      }
    ''';
    final result = await _client.query(
      mutation,
      variables: {
        'sessionId': sessionId,
        if (agencyId != null) 'agencyId': agencyId,
      },
    );
    final raw = _graphqlData(result)['createEiBillingFromSession']
        as Map<String, dynamic>?;
    if (raw == null) throw Exception('Failed to create billing record');
    return EiBillingRecordModel.fromJson(raw);
  }

  Future<EiAgencyBillingProfileModel?> fetchAgencyProfile() async {
    const query = r'''
      query EiAgencyBillingProfile {
        eiAgencyBillingProfile {
          id
          agencyId
          legalName
          npi
          medicaidProviderId
          ein
          etin
          eiHubReferenceId
          eftEnrollmentStatus
          enrollmentComplete
          baaSignedAt
          city
          state
        }
      }
    ''';
    final result = await _client.query(query);
    final raw = _graphqlData(result)['eiAgencyBillingProfile'];
    if (raw == null) return null;
    return EiAgencyBillingProfileModel.fromJson(raw as Map<String, dynamic>);
  }

  Future<List<EiProviderEnrollmentModel>> fetchProviderEnrollments() async {
    const query = r'''
      query EiProviderEnrollments {
        eiProviderEnrollments {
          id
          therapistId
          therapistName
          renderingNpi
          discipline
          eiCategory
          medicaidEnrollmentStatus
          credentialStatus
          isActive
        }
      }
    ''';
    final result = await _client.query(query);
    return (_graphqlData(result)['eiProviderEnrollments'] as List<dynamic>)
        .map((e) => EiProviderEnrollmentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EiClearinghouseConfigModel>> fetchClearinghouseConfigs() async {
    const query = r'''
      query EiClearinghouseConfig {
        eiClearinghouseConfig {
          id
          name
          workflow
          testMode
          isActive
          tradingPartnerId
          baaSignedAt
          lastConnectionTestAt
          lastConnectionTestResult
        }
      }
    ''';
    final result = await _client.query(query);
    return (_graphqlData(result)['eiClearinghouseConfig'] as List<dynamic>)
        .map((e) => EiClearinghouseConfigModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EiClearinghouseConfigModel> upsertClearinghouseConfig({
    String? id,
    String? agencyId,
    required String name,
    required String workflow,
    String? tradingPartnerId,
    bool? testMode,
    bool? isActive,
    DateTime? baaSignedAt,
  }) async {
    const mutation = r'''
      mutation UpsertEiClearinghouseConfig($input: UpsertEiClearinghouseConfigInput!) {
        upsertEiClearinghouseConfig(input: $input) {
          id
          name
          workflow
          testMode
          isActive
          tradingPartnerId
          baaSignedAt
          lastConnectionTestAt
          lastConnectionTestResult
        }
      }
    ''';
    final result = await _client.query(
      mutation,
      variables: {
        'input': {
          if (id != null) 'id': id,
          if (agencyId != null) 'agencyId': agencyId,
          'name': name,
          'workflow': workflow,
          if (tradingPartnerId != null) 'tradingPartnerId': tradingPartnerId,
          if (testMode != null) 'testMode': testMode,
          if (isActive != null) 'isActive': isActive,
          if (baaSignedAt != null)
            'baaSignedAt': baaSignedAt.toIso8601String(),
        },
      },
    );
    final raw = _graphqlData(result)['upsertEiClearinghouseConfig']
        as Map<String, dynamic>?;
    if (raw == null) throw Exception('Failed to save clearinghouse config');
    return EiClearinghouseConfigModel.fromJson(raw);
  }

  Future<EiClearinghouseTestResultModel> testClearinghouseConnection(
    String configId,
  ) async {
    const mutation = r'''
      mutation TestEiClearinghouseConnection($configId: ID!) {
        testEiClearinghouseConnection(configId: $configId) {
          success
          message
          config {
            id
            name
            workflow
            testMode
            isActive
            tradingPartnerId
            baaSignedAt
            lastConnectionTestAt
            lastConnectionTestResult
          }
        }
      }
    ''';
    final result = await _client.query(
      mutation,
      variables: {'configId': configId},
    );
    final raw = _graphqlData(result)['testEiClearinghouseConnection']
        as Map<String, dynamic>?;
    if (raw == null) throw Exception('Connection test failed');
    return EiClearinghouseTestResultModel.fromJson(raw);
  }

  Future<List<EiBillingReportRowModel>> fetchReports() async {
    const query = r'''
      query EiBillingReports {
        eiBillingReports {
          status
          count
          billedTotal
          allowedTotal
        }
      }
    ''';
    final result = await _client.query(query);
    return (_graphqlData(result)['eiBillingReports'] as List<dynamic>)
        .map((e) => EiBillingReportRowModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EiBillingAuditLogModel>> fetchAuditLogs() async {
    const query = r'''
      query EiBillingAuditLogs {
        eiBillingAuditLogs {
          id
          action
          actorName
          createdAt
        }
      }
    ''';
    final result = await _client.query(query);
    return (_graphqlData(result)['eiBillingAuditLogs'] as List<dynamic>)
        .map((e) => EiBillingAuditLogModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final eiBillingRepositoryProvider = Provider<EiBillingRepository>((ref) {
  return EiBillingRepository(ref.watch(graphqlClientProvider));
});

final eiBillingDashboardProvider =
    FutureProvider.autoDispose<EiBillingDashboardModel>((ref) {
  return ref.watch(eiBillingRepositoryProvider).fetchDashboard();
});

final eiBillingQueueProvider =
    FutureProvider.autoDispose.family<List<EiBillingRecordModel>, String?>(
  (ref, status) {
    return ref.watch(eiBillingRepositoryProvider).fetchQueue(status: status);
  },
);

final eiBillingRecordProvider =
    FutureProvider.autoDispose.family<EiBillingRecordModel, String>(
  (ref, recordId) {
    return ref.watch(eiBillingRepositoryProvider).fetchRecord(recordId);
  },
);

final eiCaseBillingProfileProvider =
    FutureProvider.autoDispose.family<EiCaseBillingProfileModel?, String>(
  (ref, childId) {
    return ref.watch(eiBillingRepositoryProvider).fetchCaseProfile(childId);
  },
);

final eiBillingDenialsProvider =
    FutureProvider.autoDispose<List<EiDenialListItemModel>>((ref) {
  return ref.watch(eiBillingRepositoryProvider).fetchDenials();
});

final eiAgencyBillingProfileProvider =
    FutureProvider.autoDispose<EiAgencyBillingProfileModel?>((ref) {
  return ref.watch(eiBillingRepositoryProvider).fetchAgencyProfile();
});

final eiProviderEnrollmentsProvider =
    FutureProvider.autoDispose<List<EiProviderEnrollmentModel>>((ref) {
  return ref.watch(eiBillingRepositoryProvider).fetchProviderEnrollments();
});

final eiClearinghouseConfigsProvider =
    FutureProvider.autoDispose<List<EiClearinghouseConfigModel>>((ref) {
  return ref.watch(eiBillingRepositoryProvider).fetchClearinghouseConfigs();
});

final eiBillingReportsProvider =
    FutureProvider.autoDispose<List<EiBillingReportRowModel>>((ref) {
  return ref.watch(eiBillingRepositoryProvider).fetchReports();
});

final eiBillingAuditLogsProvider =
    FutureProvider.autoDispose<List<EiBillingAuditLogModel>>((ref) {
  return ref.watch(eiBillingRepositoryProvider).fetchAuditLogs();
});

/// Logical next queue statuses for UI advance actions.
const eiBillingQueueTransitions = <String, List<String>>{
  'DRAFT_INCOMPLETE': ['MISSING_INFORMATION', 'READY_AGENCY_REVIEW'],
  'MISSING_INFORMATION': ['DRAFT_INCOMPLETE', 'READY_AGENCY_REVIEW'],
  'READY_AGENCY_REVIEW': [
    'MISSING_INFORMATION',
    'READY_BILLING_VALIDATION',
  ],
  'READY_BILLING_VALIDATION': [
    'MISSING_INFORMATION',
    'READY_AGENCY_REVIEW',
    'READY_AUTHORIZED_SUBMISSION',
  ],
  'READY_AUTHORIZED_SUBMISSION': [
    'READY_BILLING_VALIDATION',
    'SUBMITTED',
  ],
  'SUBMITTED': ['REJECTED', 'DENIED', 'PAID', 'CORRECTION_NEEDED'],
  'REJECTED': ['CORRECTION_NEEDED', 'RESUBMITTED'],
  'DENIED': ['CORRECTION_NEEDED'],
  'CORRECTION_NEEDED': [
    'MISSING_INFORMATION',
    'READY_BILLING_VALIDATION',
    'RESUBMITTED',
  ],
  'RESUBMITTED': ['SUBMITTED', 'REJECTED', 'DENIED', 'PAID'],
  'PAID': [],
};

const eiClearinghouseWorkflows = <String>[
  'EI_HUB',
  'STATE_FISCAL_AGENT',
  'EMEDNY',
  'EDI_837P_EXPORT',
  'CSV_EXPORT',
  'API_CLEARINGHOUSE',
];
