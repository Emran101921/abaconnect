import '../../../core/network/graphql_client.dart';

class ChildModel {
  const ChildModel({
    required this.id,
    required this.firstName,
    required this.lastName,
  });

  final String id;
  final String firstName;
  final String lastName;

  String get displayName => '$firstName $lastName';
}

class TherapistModel {
  const TherapistModel({
    required this.id,
    required this.displayName,
    required this.rating,
    this.matchScore,
  });

  final String id;
  final String displayName;
  final double rating;
  final double? matchScore;
}

class AppointmentModel {
  const AppointmentModel({
    required this.id,
    required this.status,
    required this.therapyType,
    required this.scheduledStart,
    required this.childName,
    required this.therapistName,
  });

  final String id;
  final String status;
  final String therapyType;
  final DateTime scheduledStart;
  final String childName;
  final String therapistName;
}

class ParentBookingRepository {
  ParentBookingRepository(this._graphql);

  final GraphqlClient _graphql;

  static const _myChildrenQuery = r'''
    query MyChildren {
      myChildren {
        id
        firstName
        lastName
      }
    }
  ''';

  static const _myAppointmentsQuery = r'''
    query MyAppointments {
      myAppointments {
        id
        status
        therapyType
        scheduledStart
        child { firstName lastName }
        therapist { user { firstName lastName } }
      }
    }
  ''';

  static const _recommendedTherapistsQuery = r'''
    query Recommended($therapyType: TherapyType) {
      recommendedTherapists(input: { therapyType: $therapyType }) {
        id
        ratingAverage
        matchScore
        user { firstName lastName }
      }
    }
  ''';

  static const _bookMutation = r'''
    mutation Book($input: BookAppointmentInput!) {
      bookAppointment(input: $input) {
        id
        status
        scheduledStart
      }
    }
  ''';

  Future<List<ChildModel>> fetchChildren() async {
    final result = await _graphql.query(_myChildrenQuery);
    final list = result['data']?['myChildren'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => ChildModel(
            id: e['id'] as String,
            firstName: e['firstName'] as String,
            lastName: e['lastName'] as String,
          ),
        )
        .toList();
  }

  Future<List<AppointmentModel>> fetchAppointments() async {
    final result = await _graphql.query(_myAppointmentsQuery);
    final list = result['data']?['myAppointments'] as List<dynamic>? ?? [];
    return list.map(_mapAppointment).toList();
  }

  Future<List<TherapistModel>> fetchTherapists({String? therapyType}) async {
    final result = await _graphql.query(
      _recommendedTherapistsQuery,
      variables: therapyType != null ? {'therapyType': therapyType} : null,
    );
    final list =
        result['data']?['recommendedTherapists'] as List<dynamic>? ?? [];
    return list.map((e) {
      final user = e['user'] as Map<String, dynamic>?;
      final name = user != null
          ? '${user['firstName']} ${user['lastName']}'
          : 'Therapist';
      return TherapistModel(
        id: e['id'] as String,
        displayName: name,
        rating: (e['ratingAverage'] as num?)?.toDouble() ?? 0,
        matchScore: (e['matchScore'] as num?)?.toDouble(),
      );
    }).toList();
  }

  Future<void> bookAppointment({
    required String childId,
    required String therapistId,
    required String therapyType,
    required DateTime start,
    required DateTime end,
  }) async {
    await _graphql.query(
      _bookMutation,
      variables: {
        'input': {
          'childId': childId,
          'therapistId': therapistId,
          'therapyType': therapyType,
          'scheduledStart': start.toIso8601String(),
          'scheduledEnd': end.toIso8601String(),
        },
      },
    );
  }

  AppointmentModel _mapAppointment(dynamic e) {
    final child = e['child'] as Map<String, dynamic>?;
    final therapist = e['therapist'] as Map<String, dynamic>?;
    final user = therapist?['user'] as Map<String, dynamic>?;
    return AppointmentModel(
      id: e['id'] as String,
      status: e['status'] as String? ?? '',
      therapyType: e['therapyType'] as String? ?? '',
      scheduledStart: DateTime.parse(e['scheduledStart'] as String),
      childName: child != null
          ? '${child['firstName']} ${child['lastName']}'
          : 'Child',
      therapistName: user != null
          ? '${user['firstName']} ${user['lastName']}'
          : 'Therapist',
    );
  }
}
