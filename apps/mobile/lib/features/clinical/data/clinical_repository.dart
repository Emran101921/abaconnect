import '../../../core/network/graphql_client.dart';

class TreatmentPlanModel {
  const TreatmentPlanModel({
    required this.id,
    required this.title,
    required this.therapyType,
    required this.childName,
    this.therapistName,
  });

  final String id;
  final String title;
  final String therapyType;
  final String childName;
  final String? therapistName;
}

class TherapistBadgeModel {
  const TherapistBadgeModel({
    required this.type,
    this.label,
  });

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
          id title therapyType
          child { firstName lastName }
          therapistName
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
          child { firstName lastName }
        }
      }
    ''');
    final list =
        result['data']?['therapistTreatmentPlans'] as List<dynamic>? ?? [];
    return list.map(_mapPlan).toList();
  }

  Future<void> createPlan({
    required String childId,
    required String therapyType,
    required String title,
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
        },
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
    return TreatmentPlanModel(
      id: e['id'] as String,
      title: e['title'] as String,
      therapyType: e['therapyType'] as String? ?? '',
      childName: childName,
      therapistName: e['therapistName'] as String?,
    );
  }
}
