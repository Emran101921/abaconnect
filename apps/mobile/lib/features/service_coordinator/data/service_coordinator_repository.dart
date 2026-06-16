import 'dart:convert';

import '../../../core/network/graphql_client.dart';

class AgencyRosterMemberModel {
  const AgencyRosterMemberModel({
    required this.id,
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    required this.role,
    required this.status,
    required this.languages,
    required this.caseload,
    this.notes,
    required this.addedByName,
    required this.addedAt,
    this.lastLoginAt,
    required this.isActive,
  });

  final String id;
  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String role;
  final String status;
  final List<String> languages;
  final int caseload;
  final String? notes;
  final String addedByName;
  final DateTime addedAt;
  final DateTime? lastLoginAt;
  final bool isActive;

  String get displayName => '$firstName $lastName';
}

class AgencyCaseModel {
  const AgencyCaseModel({
    required this.childId,
    required this.childName,
    required this.parentName,
    this.assignedCoordinatorId,
    this.assignedCoordinatorName,
    this.assignmentId,
  });

  final String childId;
  final String childName;
  final String parentName;
  final String? assignedCoordinatorId;
  final String? assignedCoordinatorName;
  final String? assignmentId;
}

class ScCaseSummaryModel {
  const ScCaseSummaryModel({
    required this.assignmentId,
    required this.childId,
    required this.childName,
    required this.dateOfBirth,
    required this.parentName,
    required this.caseStatus,
    required this.screeningStatus,
    required this.evaluationStatus,
    required this.ifspStatus,
    this.nextFollowUpDate,
    required this.isUrgent,
    required this.priorityLevel,
    this.assignedProviders = const [],
  });

  final String assignmentId;
  final String childId;
  final String childName;
  final DateTime dateOfBirth;
  final String parentName;
  final String caseStatus;
  final String screeningStatus;
  final String evaluationStatus;
  final String ifspStatus;
  final DateTime? nextFollowUpDate;
  final bool isUrgent;
  final String priorityLevel;
  final List<String> assignedProviders;
}

class ScDashboardModel {
  const ScDashboardModel({
    required this.totalCases,
    required this.urgentCases,
    required this.screeningsDue,
    required this.followUpsDue,
    required this.evaluationsPending,
    required this.ifspReviewsDue,
    required this.cases,
  });

  final int totalCases;
  final int urgentCases;
  final int screeningsDue;
  final int followUpsDue;
  final int evaluationsPending;
  final int ifspReviewsDue;
  final List<ScCaseSummaryModel> cases;
}

class ScCaseDetailModel {
  const ScCaseDetailModel({
    required this.childId,
    required this.childName,
    required this.dateOfBirth,
    required this.parentName,
    this.parentEmail,
    this.parentPhone,
    this.guardianPhone,
    this.initialScreening,
    this.ongoingScreenings = const [],
    this.notes = const [],
  });

  final String childId;
  final String childName;
  final DateTime dateOfBirth;
  final String parentName;
  final String? parentEmail;
  final String? parentPhone;
  final String? guardianPhone;
  final Map<String, dynamic>? initialScreening;
  final List<Map<String, dynamic>> ongoingScreenings;
  final List<Map<String, dynamic>> notes;
}

class ScFollowUpModel {
  const ScFollowUpModel({
    required this.type,
    required this.childId,
    required this.childName,
    required this.dueDate,
    required this.overdue,
  });

  final String type;
  final String childId;
  final String childName;
  final DateTime dueDate;
  final bool overdue;
}

class ServiceCoordinatorRepository {
  ServiceCoordinatorRepository(this._graphql);

  final GraphqlClient _graphql;

  Future<List<AgencyRosterMemberModel>> fetchAgencyRosterMembers() async {
    final result = await _graphql.query(r'''
        query AgencyRosterMembers {
          agencyRosterMembers {
            id userId email firstName lastName phone role status
            languages caseload notes addedByName addedAt lastLoginAt isActive
          }
        }
      ''');
    final list = result['data']?['agencyRosterMembers'] as List<dynamic>? ?? [];
    return list.map((raw) {
      final m = raw as Map<String, dynamic>;
      return AgencyRosterMemberModel(
        id: m['id'] as String,
        userId: m['userId'] as String,
        email: m['email'] as String,
        firstName: m['firstName'] as String,
        lastName: m['lastName'] as String,
        phone: m['phone'] as String?,
        role: m['role'] as String,
        status: m['status'] as String,
        languages: (m['languages'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        caseload: m['caseload'] as int? ?? 0,
        notes: m['notes'] as String?,
        addedByName: m['addedByName'] as String,
        addedAt: DateTime.parse(m['addedAt'] as String),
        lastLoginAt: m['lastLoginAt'] != null
            ? DateTime.parse(m['lastLoginAt'] as String)
            : null,
        isActive: m['isActive'] as bool? ?? false,
      );
    }).toList();
  }

  Future<AgencyRosterMemberModel> createServiceCoordinator({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    List<String>? languages,
    String? notes,
  }) async {
    final result = await _graphql.query(
      r'''
        mutation CreateServiceCoordinator($input: CreateServiceCoordinatorInput!) {
          createServiceCoordinator(input: $input) {
            id userId email firstName lastName phone role status
            languages caseload notes addedByName addedAt lastLoginAt isActive
          }
        }
      ''',
      variables: {
        'input': {
          'email': email,
          'password': password,
          'firstName': firstName,
          'lastName': lastName,
          'phone': phone,
          'languages': languages ?? [],
          'notes': notes,
        },
      },
    );
    final m = result['data']?['createServiceCoordinator'] as Map<String, dynamic>?;
    if (m == null) throw Exception('Failed to create service coordinator');
    return AgencyRosterMemberModel(
      id: m['id'] as String,
      userId: m['userId'] as String,
      email: m['email'] as String,
      firstName: m['firstName'] as String,
      lastName: m['lastName'] as String,
      phone: m['phone'] as String?,
      role: m['role'] as String,
      status: m['status'] as String,
      languages: (m['languages'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      caseload: m['caseload'] as int? ?? 0,
      notes: m['notes'] as String?,
      addedByName: m['addedByName'] as String,
      addedAt: DateTime.parse(m['addedAt'] as String),
      lastLoginAt: m['lastLoginAt'] != null
          ? DateTime.parse(m['lastLoginAt'] as String)
          : null,
      isActive: m['isActive'] as bool? ?? false,
    );
  }

  Future<void> updateServiceCoordinatorStatus({
    required String coordinatorUserId,
    required String status,
  }) async {
    await _graphql.query(
      r'''
        mutation UpdateSc($id: ID!, $input: UpdateServiceCoordinatorInput!) {
          updateServiceCoordinator(coordinatorUserId: $id, input: $input) {
            id
          }
        }
      ''',
      variables: {
        'id': coordinatorUserId,
        'input': {'status': status},
      },
    );
  }

  Future<void> removeServiceCoordinator(String coordinatorUserId) async {
    await _graphql.query(
      r'''
        mutation RemoveSc($id: ID!) {
          removeServiceCoordinatorFromRoster(coordinatorUserId: $id)
        }
      ''',
      variables: {'id': coordinatorUserId},
    );
  }

  Future<List<AgencyCaseModel>> fetchAgencyCases() async {
    final result = await _graphql.query(r'''
        query AgencyCases {
          agencyCases {
            childId childName parentName
            assignedCoordinatorId assignedCoordinatorName assignmentId
          }
        }
      ''');
    final list = result['data']?['agencyCases'] as List<dynamic>? ?? [];
    return list.map((raw) {
      final m = raw as Map<String, dynamic>;
      return AgencyCaseModel(
        childId: m['childId'] as String,
        childName: m['childName'] as String,
        parentName: m['parentName'] as String,
        assignedCoordinatorId: m['assignedCoordinatorId'] as String?,
        assignedCoordinatorName: m['assignedCoordinatorName'] as String?,
        assignmentId: m['assignmentId'] as String?,
      );
    }).toList();
  }

  Future<void> assignChildToCoordinator({
    required String childId,
    required String coordinatorUserId,
  }) async {
    await _graphql.query(
      r'''
        mutation AssignChild($childId: ID!, $coordinatorUserId: ID!) {
          assignChildToServiceCoordinator(
            childId: $childId
            coordinatorUserId: $coordinatorUserId
          )
        }
      ''',
      variables: {'childId': childId, 'coordinatorUserId': coordinatorUserId},
    );
  }

  Future<void> removeChildAssignment(String assignmentId) async {
    await _graphql.query(
      r'''
        mutation RemoveAssignment($id: ID!) {
          removeChildScAssignment(assignmentId: $id)
        }
      ''',
      variables: {'id': assignmentId},
    );
  }

  Future<ScDashboardModel> fetchDashboard() async {
    final result = await _graphql.query(r'''
        query ScDashboard {
          serviceCoordinatorDashboard {
            totalCases urgentCases screeningsDue followUpsDue
            evaluationsPending ifspReviewsDue
            cases {
              assignmentId childId childName dateOfBirth parentName
              caseStatus screeningStatus evaluationStatus ifspStatus
              nextFollowUpDate isUrgent priorityLevel assignedProviders
            }
          }
        }
      ''');
    final d = result['data']?['serviceCoordinatorDashboard'] as Map<String, dynamic>?;
    if (d == null) throw Exception('Failed to load dashboard');
    final cases = (d['cases'] as List<dynamic>? ?? []).map((raw) {
      final m = raw as Map<String, dynamic>;
      return ScCaseSummaryModel(
        assignmentId: m['assignmentId'] as String,
        childId: m['childId'] as String,
        childName: m['childName'] as String,
        dateOfBirth: DateTime.parse(m['dateOfBirth'] as String),
        parentName: m['parentName'] as String,
        caseStatus: m['caseStatus'] as String,
        screeningStatus: m['screeningStatus'] as String,
        evaluationStatus: m['evaluationStatus'] as String,
        ifspStatus: m['ifspStatus'] as String,
        nextFollowUpDate: m['nextFollowUpDate'] != null
            ? DateTime.parse(m['nextFollowUpDate'] as String)
            : null,
        isUrgent: m['isUrgent'] as bool? ?? false,
        priorityLevel: m['priorityLevel'] as String,
        assignedProviders: (m['assignedProviders'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
      );
    }).toList();
    return ScDashboardModel(
      totalCases: d['totalCases'] as int? ?? 0,
      urgentCases: d['urgentCases'] as int? ?? 0,
      screeningsDue: d['screeningsDue'] as int? ?? 0,
      followUpsDue: d['followUpsDue'] as int? ?? 0,
      evaluationsPending: d['evaluationsPending'] as int? ?? 0,
      ifspReviewsDue: d['ifspReviewsDue'] as int? ?? 0,
      cases: cases,
    );
  }

  Future<ScCaseDetailModel> fetchCaseDetail(String childId) async {
    final result = await _graphql.query(
      r'''
        query ScCase($childId: ID!) {
          serviceCoordinatorCase(childId: $childId) {
            childId childName dateOfBirth parentName parentEmail parentPhone
            guardianPhone
            initialScreening {
              id answersJson status priorityLevel followUpRequired
              followUpDueDate notes createdAt updatedAt
            }
            ongoingScreenings {
              id answersJson status priorityLevel followUpRequired
              followUpDueDate notes progressSummary newConcerns createdAt updatedAt
            }
            notes {
              id childId noteType noteText actionRequired actionDueDate createdAt
            }
          }
        }
      ''',
      variables: {'childId': childId},
    );
    final m = result['data']?['serviceCoordinatorCase'] as Map<String, dynamic>?;
    if (m == null) throw Exception('Failed to load case');
    return ScCaseDetailModel(
      childId: m['childId'] as String,
      childName: m['childName'] as String,
      dateOfBirth: DateTime.parse(m['dateOfBirth'] as String),
      parentName: m['parentName'] as String,
      parentEmail: m['parentEmail'] as String?,
      parentPhone: m['parentPhone'] as String?,
      guardianPhone: m['guardianPhone'] as String?,
      initialScreening: m['initialScreening'] as Map<String, dynamic>?,
      ongoingScreenings:
          (m['ongoingScreenings'] as List<dynamic>? ?? [])
              .map((e) => e as Map<String, dynamic>)
              .toList(),
      notes: (m['notes'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
    );
  }

  Future<List<ScFollowUpModel>> fetchFollowUps() async {
    final result = await _graphql.query(r'''
        query ScFollowUps {
          serviceCoordinatorFollowUps {
            type childId childName dueDate overdue
          }
        }
      ''');
    final list = result['data']?['serviceCoordinatorFollowUps'] as List<dynamic>? ?? [];
    return list.map((raw) {
      final m = raw as Map<String, dynamic>;
      return ScFollowUpModel(
        type: m['type'] as String,
        childId: m['childId'] as String,
        childName: m['childName'] as String,
        dueDate: DateTime.parse(m['dueDate'] as String),
        overdue: m['overdue'] as bool? ?? false,
      );
    }).toList();
  }

  Future<int> upsertInitialScreening({
    required String childId,
    required Map<String, dynamic> answers,
    String? notes,
    bool? followUpRequired,
    DateTime? followUpDueDate,
    bool submit = false,
  }) async {
    final result = await _graphql.query(
      r'''
        mutation UpsertInitial($childId: ID!, $input: UpsertEiScreeningInput!) {
          upsertInitialEiScreening(childId: $childId, input: $input) {
            completionPercent
          }
        }
      ''',
      variables: {
        'childId': childId,
        'input': {
          'answersJson': jsonEncode(answers),
          'notes': notes,
          'followUpRequired': followUpRequired,
          'followUpDueDate': followUpDueDate?.toIso8601String(),
          'submit': submit,
        },
      },
    );
    return result['data']?['upsertInitialEiScreening']?['completionPercent'] as int? ?? 0;
  }

  Future<int> upsertOngoingScreening({
    required String childId,
    required Map<String, dynamic> answers,
    String? notes,
    String? progressSummary,
    String? newConcerns,
    bool? followUpRequired,
    DateTime? followUpDueDate,
    bool submit = false,
  }) async {
    final result = await _graphql.query(
      r'''
        mutation UpsertOngoing($childId: ID!, $input: UpsertEiScreeningInput!) {
          upsertOngoingEiScreening(childId: $childId, input: $input) {
            completionPercent
          }
        }
      ''',
      variables: {
        'childId': childId,
        'input': {
          'answersJson': jsonEncode(answers),
          'notes': notes,
          'progressSummary': progressSummary,
          'newConcerns': newConcerns,
          'followUpRequired': followUpRequired,
          'followUpDueDate': followUpDueDate?.toIso8601String(),
          'submit': submit,
        },
      },
    );
    return result['data']?['upsertOngoingEiScreening']?['completionPercent'] as int? ?? 0;
  }

  Future<void> createNote({
    required String childId,
    required String noteType,
    required String noteText,
    bool actionRequired = false,
    DateTime? actionDueDate,
  }) async {
    await _graphql.query(
      r'''
        mutation CreateNote($childId: ID!, $input: CreateScNoteInput!) {
          createServiceCoordinationNote(childId: $childId, input: $input) {
            id
          }
        }
      ''',
      variables: {
        'childId': childId,
        'input': {
          'noteType': noteType,
          'noteText': noteText,
          'actionRequired': actionRequired,
          'actionDueDate': actionDueDate?.toIso8601String(),
        },
      },
    );
  }

  Future<void> flagUrgent(String childId, bool urgent) async {
    await _graphql.query(
      r'''
        mutation FlagUrgent($childId: ID!, $urgent: Boolean!) {
          flagUrgentScCase(childId: $childId, urgent: $urgent)
        }
      ''',
      variables: {'childId': childId, 'urgent': urgent},
    );
  }
}
