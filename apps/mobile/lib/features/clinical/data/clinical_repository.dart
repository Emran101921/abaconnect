import '../../../core/network/graphql_client.dart';

class TreatmentPlanGoalModel {
  const TreatmentPlanGoalModel({
    required this.id,
    required this.label,
    this.status,
  });

  final String id;
  final String label;
  final String? status;

  factory TreatmentPlanGoalModel.fromJson(Map<String, dynamic> json) {
    return TreatmentPlanGoalModel(
      id: json['id'] as String,
      label: json['label'] as String,
      status: json['status'] as String?,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'done':
        return 'Done';
      case 'in_progress':
        return 'In progress';
      case 'active':
        return 'Active';
      default:
        return 'Not started';
    }
  }

  TreatmentPlanGoalModel cycleStatus() {
    final next = switch (status) {
      'done' => 'active',
      'in_progress' => 'done',
      'active' => 'in_progress',
      _ => 'active',
    };
    return TreatmentPlanGoalModel(id: id, label: label, status: next);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    if (status != null) 'status': status,
  };
}

class TreatmentPlanModel {
  const TreatmentPlanModel({
    required this.id,
    required this.title,
    required this.therapyType,
    required this.childName,
    this.therapistName,
    this.goals = const [],
    this.goalsDoneCount = 0,
    this.goalsTotalCount = 0,
  });

  final String id;
  final String title;
  final String therapyType;
  final String childName;
  final String? therapistName;
  final List<TreatmentPlanGoalModel> goals;
  final int goalsDoneCount;
  final int goalsTotalCount;

  double get goalsProgress =>
      goalsTotalCount > 0 ? goalsDoneCount / goalsTotalCount : 0;
}

class ParentProgressNoteModel {
  const ParentProgressNoteModel({
    required this.id,
    required this.sessionId,
    required this.childName,
    required this.therapistName,
    required this.summary,
    this.parentFeedback,
    this.signedAt,
  });

  final String id;
  final String sessionId;
  final String childName;
  final String therapistName;
  final String summary;
  final String? parentFeedback;
  final DateTime? signedAt;
}

class TherapistWeeklyProgressModel {
  const TherapistWeeklyProgressModel({
    required this.weeks,
    required this.children,
  });

  final List<WeeklyProgressWeekModel> weeks;
  final List<ChildProgressSummaryModel> children;
}

class WeeklyProgressWeekModel {
  const WeeklyProgressWeekModel({
    required this.weekLabel,
    required this.reportCount,
  });

  final String weekLabel;
  final int reportCount;
}

class ChildProgressSummaryModel {
  const ChildProgressSummaryModel({
    required this.childId,
    required this.childName,
    required this.goalCompletionPercent,
    this.activePlanTitle,
  });

  final String childId;
  final String childName;
  final double goalCompletionPercent;
  final String? activePlanTitle;
}

class TherapistBadgeModel {
  const TherapistBadgeModel({required this.type, this.label});

  final String type;
  final String? label;
}

class ClinicalRepository {
  ClinicalRepository(this._graphql);

  final GraphqlClient _graphql;

  Future<List<TreatmentPlanModel>> fetchParentPlans() async {
    final result = await _graphql.query(r'''
      query {
        myTreatmentPlans {
          id title therapyType therapistName
          goalsDoneCount goalsTotalCount
          child { firstName lastName }
          goals { id label status }
        }
      }
    ''');
    final list = result['data']?['myTreatmentPlans'] as List<dynamic>? ?? [];
    return list.map(_mapPlan).toList();
  }

  Future<List<TreatmentPlanModel>> fetchTherapistPlans() async {
    final result = await _graphql.query(r'''
      query {
        therapistTreatmentPlans {
          id title therapyType
          goalsDoneCount goalsTotalCount
          child { firstName lastName }
          goals { id label status }
        }
      }
    ''');
    final list =
        result['data']?['therapistTreatmentPlans'] as List<dynamic>? ?? [];
    return list.map(_mapPlan).toList();
  }

  Future<List<ParentProgressNoteModel>> fetchParentProgressNotes() async {
    final result = await _graphql.query(r'''
      query {
        myProgressNotes {
          id sessionId childName therapistName summary
          parentFeedback signedAt
        }
      }
    ''');
    final list = result['data']?['myProgressNotes'] as List<dynamic>? ?? [];
    return list.map((e) {
      final signed = e['signedAt'] as String?;
      return ParentProgressNoteModel(
        id: e['id'] as String,
        sessionId: e['sessionId'] as String,
        childName: e['childName'] as String? ?? '',
        therapistName: e['therapistName'] as String? ?? '',
        summary: e['summary'] as String? ?? '',
        parentFeedback: e['parentFeedback'] as String?,
        signedAt: signed != null ? DateTime.tryParse(signed) : null,
      );
    }).toList();
  }

  Future<void> createPlan({
    required String childId,
    required String therapyType,
    required String title,
    List<TreatmentPlanGoalModel>? goals,
  }) async {
    await _graphql.query(
      r'''
      mutation Create($input: CreateTreatmentPlanInput!) {
        createTreatmentPlan(input: $input) { id }
      }
    ''',
      variables: {
        'input': {
          'childId': childId,
          'therapyType': therapyType,
          'title': title,
          'startDate': DateTime.now().toIso8601String(),
          if (goals != null && goals.isNotEmpty)
            'goals': goals.map((g) => g.toJson()).toList(),
        },
      },
    );
  }

  Future<void> updatePlan({
    required String planId,
    String? title,
    List<TreatmentPlanGoalModel>? goals,
  }) async {
    await _graphql.query(
      r'''
      mutation Update($input: UpdateTreatmentPlanInput!) {
        updateTreatmentPlan(input: $input) { id }
      }
    ''',
      variables: {
        'input': {
          'planId': planId,
          'title': ?title,
          if (goals != null) 'goals': goals.map((g) => g.toJson()).toList(),
        },
      },
    );
  }

  Future<void> submitSessionFeedback({
    required String sessionId,
    required String feedback,
  }) async {
    await _graphql.query(
      r'''
      mutation Feedback($input: SubmitSessionFeedbackInput!) {
        submitSessionFeedback(input: $input) { id }
      }
    ''',
      variables: {
        'input': {'sessionId': sessionId, 'feedback': feedback},
      },
    );
  }

  Future<void> saveProgressNote({
    required String sessionId,
    required String summary,
  }) async {
    await _graphql.query(
      r'''
      mutation Save($input: SaveProgressNoteInput!) {
        saveProgressNote(input: $input)
      }
    ''',
      variables: {
        'input': {'sessionId': sessionId, 'summary': summary},
      },
    );
  }

  Future<TherapistWeeklyProgressModel> fetchTherapistWeeklyProgress() async {
    final result = await _graphql.query(r'''
      query {
        therapistWeeklyProgress {
          weeks { weekLabel reportCount }
          children {
            childId childName goalCompletionPercent activePlanTitle
          }
        }
      }
    ''');
    final data =
        result['data']?['therapistWeeklyProgress'] as Map<String, dynamic>? ??
        {};
    final weeksRaw = data['weeks'] as List<dynamic>? ?? [];
    final childrenRaw = data['children'] as List<dynamic>? ?? [];
    return TherapistWeeklyProgressModel(
      weeks: weeksRaw
          .map(
            (w) => WeeklyProgressWeekModel(
              weekLabel: w['weekLabel'] as String? ?? '',
              reportCount: w['reportCount'] as int? ?? 0,
            ),
          )
          .toList(),
      children: childrenRaw
          .map(
            (c) => ChildProgressSummaryModel(
              childId: c['childId'] as String? ?? '',
              childName: c['childName'] as String? ?? '',
              goalCompletionPercent:
                  (c['goalCompletionPercent'] as num?)?.toDouble() ?? 0,
              activePlanTitle: c['activePlanTitle'] as String?,
            ),
          )
          .toList(),
    );
  }

  Future<List<TherapistBadgeModel>> fetchBadges() async {
    final result = await _graphql.query(r'''
      query { myTherapistBadges { type label } }
    ''');
    final list = result['data']?['myTherapistBadges'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => TherapistBadgeModel(
            type: e['type'] as String? ?? '',
            label: e['label'] as String?,
          ),
        )
        .toList();
  }

  TreatmentPlanModel _mapPlan(dynamic e) {
    final child = e['child'] as Map<String, dynamic>?;
    final childName = child != null
        ? '${child['firstName']} ${child['lastName']}'
        : 'Child';
    final goalsRaw = e['goals'] as List<dynamic>? ?? [];
    return TreatmentPlanModel(
      id: e['id'] as String,
      title: e['title'] as String,
      therapyType: e['therapyType'] as String? ?? '',
      childName: childName,
      therapistName: e['therapistName'] as String?,
      goalsDoneCount: e['goalsDoneCount'] as int? ?? 0,
      goalsTotalCount: e['goalsTotalCount'] as int? ?? goalsRaw.length,
      goals: goalsRaw
          .map(
            (g) => TreatmentPlanGoalModel.fromJson(g as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
