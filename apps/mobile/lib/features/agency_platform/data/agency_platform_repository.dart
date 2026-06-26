import 'dart:convert';

import '../../../core/network/graphql_client.dart';
import '../../../core/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AgencyBranchModel {
  const AgencyBranchModel({
    required this.id,
    required this.name,
    this.region,
    this.city,
    this.state,
    this.zipCode,
    this.phone,
    this.email,
    required this.active,
  });

  final String id;
  final String name;
  final String? region;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? phone;
  final String? email;
  final bool active;

  factory AgencyBranchModel.fromJson(Map<String, dynamic> json) {
    return AgencyBranchModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      region: json['region'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zipCode: json['zipCode'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }
}

class AgencyDepartmentModel {
  const AgencyDepartmentModel({
    required this.id,
    this.branchId,
    required this.name,
    this.code,
    required this.active,
  });

  final String id;
  final String? branchId;
  final String name;
  final String? code;
  final bool active;

  factory AgencyDepartmentModel.fromJson(Map<String, dynamic> json) {
    return AgencyDepartmentModel(
      id: json['id'] as String,
      branchId: json['branchId'] as String?,
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }
}

class AgencyProgramModel {
  const AgencyProgramModel({
    required this.id,
    required this.name,
    this.code,
    this.serviceType,
    this.description,
    this.region,
    required this.active,
  });

  final String id;
  final String name;
  final String? code;
  final String? serviceType;
  final String? description;
  final String? region;
  final bool active;

  factory AgencyProgramModel.fromJson(Map<String, dynamic> json) {
    return AgencyProgramModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      serviceType: json['serviceType'] as String?,
      description: json['description'] as String?,
      region: json['region'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }
}

class AgencyFeatureModuleModel {
  const AgencyFeatureModuleModel({
    required this.id,
    required this.moduleKey,
    required this.label,
    required this.enabled,
  });

  final String id;
  final String moduleKey;
  final String label;
  final bool enabled;

  factory AgencyFeatureModuleModel.fromJson(Map<String, dynamic> json) {
    return AgencyFeatureModuleModel(
      id: json['id'] as String,
      moduleKey: json['moduleKey'] as String? ?? '',
      label: json['label'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

class AgencyPermissionGrantModel {
  const AgencyPermissionGrantModel({
    required this.id,
    required this.scopeType,
    this.scopeId,
    required this.permission,
    required this.granted,
  });

  final String id;
  final String scopeType;
  final String? scopeId;
  final String permission;
  final bool granted;

  factory AgencyPermissionGrantModel.fromJson(Map<String, dynamic> json) {
    return AgencyPermissionGrantModel(
      id: json['id'] as String,
      scopeType: json['scopeType'] as String? ?? '',
      scopeId: json['scopeId'] as String?,
      permission: json['permission'] as String? ?? '',
      granted: json['granted'] as bool? ?? true,
    );
  }
}

class AgencyPlatformOverviewModel {
  const AgencyPlatformOverviewModel({
    required this.agencyId,
    required this.complianceDisclaimer,
    required this.branches,
    required this.departments,
    required this.programs,
    required this.modules,
    required this.settings,
    required this.permissionGrants,
  });

  final String agencyId;
  final String complianceDisclaimer;
  final List<AgencyBranchModel> branches;
  final List<AgencyDepartmentModel> departments;
  final List<AgencyProgramModel> programs;
  final List<AgencyFeatureModuleModel> modules;
  final Map<String, dynamic> settings;
  final List<AgencyPermissionGrantModel> permissionGrants;

  bool isModuleEnabled(String moduleKey) {
    for (final module in modules) {
      if (module.moduleKey == moduleKey) return module.enabled;
    }
    return true;
  }

  factory AgencyPlatformOverviewModel.fromJson(Map<String, dynamic> json) {
    List<T> mapList<T>(
      String key,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      final raw = json[key] as List<dynamic>? ?? [];
      return raw
          .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return AgencyPlatformOverviewModel(
      agencyId: json['agencyId'] as String,
      complianceDisclaimer: json['complianceDisclaimer'] as String? ?? '',
      branches: mapList('branches', AgencyBranchModel.fromJson),
      departments: mapList('departments', AgencyDepartmentModel.fromJson),
      programs: mapList('programs', AgencyProgramModel.fromJson),
      modules: mapList('modules', AgencyFeatureModuleModel.fromJson),
      settings: _parseSettingsJson(json['settingsJson']),
      permissionGrants: mapList(
        'permissionGrants',
        AgencyPermissionGrantModel.fromJson,
      ),
    );
  }
}

class AgencyAuditLogModel {
  const AgencyAuditLogModel({
    required this.id,
    required this.action,
    required this.entityType,
    this.entityId,
    this.patientId,
    this.actorRole,
    required this.createdAt,
  });

  final String id;
  final String action;
  final String entityType;
  final String? entityId;
  final String? patientId;
  final String? actorRole;
  final DateTime createdAt;

  factory AgencyAuditLogModel.fromJson(Map<String, dynamic> json) {
    return AgencyAuditLogModel(
      id: json['id'] as String,
      action: json['action'] as String? ?? '',
      entityType: json['entityType'] as String? ?? '',
      entityId: json['entityId'] as String?,
      patientId: json['patientId'] as String?,
      actorRole: json['actorRole'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

Map<String, dynamic> _parseSettingsJson(dynamic raw) {
  if (raw is String && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
  }
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  return const {};
}

final agencyPlatformRepositoryProvider = Provider<AgencyPlatformRepository>(
  (ref) => AgencyPlatformRepository(ref.watch(graphqlClientProvider)),
);

class AgencyPlatformRepository {
  AgencyPlatformRepository(this._graphql);

  final GraphqlClient _graphql;

  static const _overviewFields = '''
    agencyId
    complianceDisclaimer
    branches { id name region city state zipCode phone email active }
    departments { id branchId name code active }
    programs { id name code serviceType description region active }
    modules { id moduleKey label enabled }
    settingsJson
    permissionGrants { id scopeType scopeId permission granted }
  ''';

  Future<AgencyPlatformOverviewModel> fetchOverview() async {
    final result = await _graphql.query('''
      query {
        agencyPlatformOverview {
          $_overviewFields
        }
      }
    ''');
    final data = result['data']?['agencyPlatformOverview'] as Map?;
    if (data == null) {
      throw Exception('Unable to load agency platform settings');
    }
    return AgencyPlatformOverviewModel.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  Future<AgencyPlatformOverviewModel> updateFeatureModule({
    required String moduleKey,
    required bool enabled,
  }) async {
    await _graphql.query('''
      mutation(\$input: UpdateAgencyFeatureModuleInput!) {
        updateAgencyFeatureModule(input: \$input) {
          id
          moduleKey
          enabled
        }
      }
    ''', variables: {
      'input': {'moduleKey': moduleKey, 'enabled': enabled},
    });
    return fetchOverview();
  }

  Future<AgencyPlatformOverviewModel> upsertBranch({
    String? id,
    required String name,
    String? region,
    String? city,
    String? state,
    String? zipCode,
    String? phone,
    String? email,
  }) async {
    await _graphql.query('''
      mutation(\$input: UpsertAgencyBranchInput!) {
        upsertAgencyBranch(input: \$input) { id }
      }
    ''', variables: {
      'input': {
        if (id != null) 'id': id,
        'name': name,
        if (region != null) 'region': region,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (zipCode != null) 'zipCode': zipCode,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
      },
    });
    return fetchOverview();
  }

  Future<AgencyPlatformOverviewModel> upsertDepartment({
    String? id,
    String? branchId,
    required String name,
    String? code,
  }) async {
    await _graphql.query('''
      mutation(\$input: UpsertAgencyDepartmentInput!) {
        upsertAgencyDepartment(input: \$input) { id }
      }
    ''', variables: {
      'input': {
        if (id != null) 'id': id,
        if (branchId != null) 'branchId': branchId,
        'name': name,
        if (code != null) 'code': code,
      },
    });
    return fetchOverview();
  }

  Future<AgencyPlatformOverviewModel> upsertProgram({
    String? id,
    required String name,
    String? code,
    String? serviceType,
    String? description,
    String? region,
  }) async {
    await _graphql.query('''
      mutation(\$input: UpsertAgencyProgramInput!) {
        upsertAgencyProgram(input: \$input) { id }
      }
    ''', variables: {
      'input': {
        if (id != null) 'id': id,
        'name': name,
        if (code != null) 'code': code,
        if (serviceType != null) 'serviceType': serviceType,
        if (description != null) 'description': description,
        if (region != null) 'region': region,
      },
    });
    return fetchOverview();
  }

  Future<List<AgencyAuditLogModel>> fetchAuditLogs({
    int take = 100,
    String? patientId,
  }) async {
    final result = await _graphql.query('''
      query(\$take: Int, \$patientId: ID) {
        agencyAuditLogs(take: \$take, patientId: \$patientId) {
          id
          action
          entityType
          entityId
          patientId
          actorRole
          createdAt
        }
      }
    ''', variables: {
      'take': take,
      if (patientId != null) 'patientId': patientId,
    });
    final list = result['data']?['agencyAuditLogs'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => AgencyAuditLogModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<AgencyClientCoordinationModel?> fetchClientCoordination(
    String childId,
  ) async {
    final result = await _graphql.query('''
      query(\$childId: ID!) {
        agencyClientCoordinationSummary(childId: \$childId) {
          childId
          assignmentId
          assignedCoordinatorName
          isUrgent
          coordinationNotesCount
          lastCoordinationNoteAt
          screeningRiskLevel
          evaluationRequested
        }
      }
    ''', variables: {'childId': childId});
    final data = result['data']?['agencyClientCoordinationSummary'] as Map?;
    if (data == null) return null;
    return AgencyClientCoordinationModel.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  Future<List<AgencyReferralModel>> fetchReferrals() async {
    final result = await _graphql.query('''
      query {
        agencyReferrals {
          id contactName contactPhone contactEmail childName
          sourceName sourceType status notes convertedChildId createdAt
        }
      }
    ''');
    final list = result['data']?['agencyReferrals'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => AgencyReferralModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<AgencyReferralModel> upsertReferral({
    String? id,
    String? contactName,
    String? childName,
    String? sourceName,
    String? sourceType,
    String? status,
    String? notes,
  }) async {
    await _graphql.query('''
      mutation(\$input: UpsertAgencyReferralInput!) {
        upsertAgencyReferral(input: \$input) { id status }
      }
    ''', variables: {
      'input': {
        if (id != null) 'id': id,
        if (contactName != null) 'contactName': contactName,
        if (childName != null) 'childName': childName,
        if (sourceName != null) 'sourceName': sourceName,
        if (sourceType != null) 'sourceType': sourceType,
        if (status != null) 'status': status,
        if (notes != null) 'notes': notes,
      },
    });
    final list = await fetchReferrals();
    return list.first;
  }

  Future<ConvertReferralResultModel> convertReferralToClient({
    required String referralId,
    required DateTime dateOfBirth,
    String? firstName,
    String? lastName,
  }) async {
    final result = await _graphql.query('''
      mutation(\$input: ConvertAgencyReferralInput!) {
        convertAgencyReferralToClient(input: \$input) {
          referralId childId status
        }
      }
    ''', variables: {
      'input': {
        'referralId': referralId,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
      },
    });
    final data =
        result['data']?['convertAgencyReferralToClient'] as Map? ?? {};
    return ConvertReferralResultModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<ProviderPayRateModel> upsertProviderPayRate({
    String? id,
    required String therapistId,
    String? serviceType,
    required int rateCents,
    String rateUnit = 'hour',
  }) async {
    final result = await _graphql.query('''
      mutation(\$input: UpsertProviderPayRateInput!) {
        upsertAgencyProviderPayRate(input: \$input) {
          id therapistId serviceType rateCents rateUnit effectiveFrom
        }
      }
    ''', variables: {
      'input': {
        if (id != null) 'id': id,
        'therapistId': therapistId,
        if (serviceType != null) 'serviceType': serviceType,
        'rateCents': rateCents,
        'rateUnit': rateUnit,
      },
    });
    final data = result['data']?['upsertAgencyProviderPayRate'] as Map?;
    if (data == null) {
      throw Exception('Failed to save pay rate');
    }
    return ProviderPayRateModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<AgencyIntegrationModel>> fetchIntegrationCatalog() async {
    final result = await _graphql.query('''
      query {
        agencyIntegrationCatalog {
          key label category description enabled
        }
      }
    ''');
    final list =
        result['data']?['agencyIntegrationCatalog'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => AgencyIntegrationModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<List<AgencyOperationalAlertModel>> fetchOperationalAlerts() async {
    final result = await _graphql.query('''
      query {
        agencyOperationalAlerts {
          key label count routeHint
        }
      }
    ''');
    final list =
        result['data']?['agencyOperationalAlerts'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => AgencyOperationalAlertModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<List<ProviderPayRateModel>> fetchProviderPayRates({
    String? therapistId,
  }) async {
    final result = await _graphql.query('''
      query(\$therapistId: ID) {
        agencyProviderPayRates(therapistId: \$therapistId) {
          id therapistId serviceType rateCents rateUnit effectiveFrom
        }
      }
    ''', variables: {
      if (therapistId != null) 'therapistId': therapistId,
    });
    final list =
        result['data']?['agencyProviderPayRates'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => ProviderPayRateModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<AgencyPayrollRunPreviewModel> fetchPayrollRunPreview({
    required DateTime from,
    required DateTime to,
  }) async {
    final result = await _graphql.query('''
      query(\$input: AgencyPayrollRunInput!) {
        agencyPayrollRunPreview(input: \$input) {
          fromDate toDate totalEstimatedPayCents
          lines {
            therapistId therapistName sessionCount hours rateDisplay estimatedPayCents
          }
        }
      }
    ''', variables: {
      'input': {
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
      },
    });
    final data = result['data']?['agencyPayrollRunPreview'] as Map?;
    if (data == null) {
      throw Exception('Failed to load payroll preview');
    }
    return AgencyPayrollRunPreviewModel.fromJson(
      Map<String, dynamic>.from(data),
    );
  }
}

class AgencyClientCoordinationModel {
  const AgencyClientCoordinationModel({
    required this.childId,
    this.assignmentId,
    this.assignedCoordinatorName,
    required this.isUrgent,
    required this.coordinationNotesCount,
    this.lastCoordinationNoteAt,
    this.screeningRiskLevel,
    required this.evaluationRequested,
  });

  final String childId;
  final String? assignmentId;
  final String? assignedCoordinatorName;
  final bool isUrgent;
  final int coordinationNotesCount;
  final DateTime? lastCoordinationNoteAt;
  final String? screeningRiskLevel;
  final bool evaluationRequested;

  factory AgencyClientCoordinationModel.fromJson(Map<String, dynamic> json) {
    return AgencyClientCoordinationModel(
      childId: json['childId'] as String,
      assignmentId: json['assignmentId'] as String?,
      assignedCoordinatorName: json['assignedCoordinatorName'] as String?,
      isUrgent: json['isUrgent'] as bool? ?? false,
      coordinationNotesCount:
          (json['coordinationNotesCount'] as num?)?.toInt() ?? 0,
      lastCoordinationNoteAt: json['lastCoordinationNoteAt'] != null
          ? DateTime.parse(json['lastCoordinationNoteAt'] as String)
          : null,
      screeningRiskLevel: json['screeningRiskLevel'] as String?,
      evaluationRequested: json['evaluationRequested'] as bool? ?? false,
    );
  }
}

class AgencyReferralModel {
  const AgencyReferralModel({
    required this.id,
    this.contactName,
    this.childName,
    this.sourceName,
    this.sourceType,
    required this.status,
    this.notes,
    this.convertedChildId,
    required this.createdAt,
  });

  final String id;
  final String? contactName;
  final String? childName;
  final String? sourceName;
  final String? sourceType;
  final String status;
  final String? notes;
  final String? convertedChildId;
  final DateTime createdAt;

  bool get isConverted => convertedChildId != null;

  factory AgencyReferralModel.fromJson(Map<String, dynamic> json) {
    return AgencyReferralModel(
      id: json['id'] as String,
      contactName: json['contactName'] as String?,
      childName: json['childName'] as String?,
      sourceName: json['sourceName'] as String?,
      sourceType: json['sourceType'] as String?,
      status: json['status'] as String? ?? 'NEW',
      notes: json['notes'] as String?,
      convertedChildId: json['convertedChildId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class ConvertReferralResultModel {
  const ConvertReferralResultModel({
    required this.referralId,
    required this.childId,
    required this.status,
  });

  final String referralId;
  final String childId;
  final String status;

  factory ConvertReferralResultModel.fromJson(Map<String, dynamic> json) {
    return ConvertReferralResultModel(
      referralId: json['referralId'] as String,
      childId: json['childId'] as String,
      status: json['status'] as String? ?? 'CONVERTED_TO_CLIENT',
    );
  }
}

class AgencyOperationalAlertModel {
  const AgencyOperationalAlertModel({
    required this.key,
    required this.label,
    required this.count,
    this.routeHint,
  });

  final String key;
  final String label;
  final int count;
  final String? routeHint;

  factory AgencyOperationalAlertModel.fromJson(Map<String, dynamic> json) {
    return AgencyOperationalAlertModel(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      routeHint: json['routeHint'] as String?,
    );
  }
}

class AgencyIntegrationModel {
  const AgencyIntegrationModel({
    required this.key,
    required this.label,
    required this.category,
    required this.description,
    required this.enabled,
  });

  final String key;
  final String label;
  final String category;
  final String description;
  final bool enabled;

  factory AgencyIntegrationModel.fromJson(Map<String, dynamic> json) {
    return AgencyIntegrationModel(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
    );
  }
}

class ProviderPayRateModel {
  const ProviderPayRateModel({
    required this.id,
    required this.therapistId,
    this.serviceType,
    required this.rateCents,
    required this.rateUnit,
    required this.effectiveFrom,
  });

  final String id;
  final String therapistId;
  final String? serviceType;
  final int rateCents;
  final String rateUnit;
  final DateTime effectiveFrom;

  String get displayRate {
    final dollars = (rateCents / 100).toStringAsFixed(2);
    return '\$$dollars / $rateUnit';
  }

  factory ProviderPayRateModel.fromJson(Map<String, dynamic> json) {
    return ProviderPayRateModel(
      id: json['id'] as String,
      therapistId: json['therapistId'] as String,
      serviceType: json['serviceType'] as String?,
      rateCents: (json['rateCents'] as num).toInt(),
      rateUnit: json['rateUnit'] as String? ?? 'hour',
      effectiveFrom: DateTime.parse(json['effectiveFrom'] as String),
    );
  }
}

class AgencyPayrollRunLineModel {
  const AgencyPayrollRunLineModel({
    required this.therapistId,
    required this.therapistName,
    required this.sessionCount,
    required this.hours,
    required this.rateDisplay,
    required this.estimatedPayCents,
  });

  final String therapistId;
  final String therapistName;
  final int sessionCount;
  final double hours;
  final String rateDisplay;
  final int estimatedPayCents;

  factory AgencyPayrollRunLineModel.fromJson(Map<String, dynamic> json) {
    return AgencyPayrollRunLineModel(
      therapistId: json['therapistId'] as String,
      therapistName: json['therapistName'] as String? ?? '',
      sessionCount: (json['sessionCount'] as num?)?.toInt() ?? 0,
      hours: (json['hours'] as num?)?.toDouble() ?? 0,
      rateDisplay: json['rateDisplay'] as String? ?? '',
      estimatedPayCents: (json['estimatedPayCents'] as num?)?.toInt() ?? 0,
    );
  }
}

class AgencyPayrollRunPreviewModel {
  const AgencyPayrollRunPreviewModel({
    required this.fromDate,
    required this.toDate,
    required this.lines,
    required this.totalEstimatedPayCents,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final List<AgencyPayrollRunLineModel> lines;
  final int totalEstimatedPayCents;

  factory AgencyPayrollRunPreviewModel.fromJson(Map<String, dynamic> json) {
    final lines = json['lines'] as List<dynamic>? ?? [];
    return AgencyPayrollRunPreviewModel(
      fromDate: DateTime.parse(json['fromDate'] as String),
      toDate: DateTime.parse(json['toDate'] as String),
      lines: lines
          .map(
            (line) => AgencyPayrollRunLineModel.fromJson(
              Map<String, dynamic>.from(line as Map),
            ),
          )
          .toList(),
      totalEstimatedPayCents:
          (json['totalEstimatedPayCents'] as num?)?.toInt() ?? 0,
    );
  }
}
