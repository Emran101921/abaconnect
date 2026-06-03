import '../../../core/network/graphql_client.dart';

class TherapistProfileModel {
  const TherapistProfileModel({
    required this.id,
    required this.isVerified,
    required this.displayName,
    required this.email,
    required this.rating,
    required this.ratingCount,
    this.bio,
    this.licenseNumber,
    this.licenseState,
    this.yearsExperience,
    this.therapyTypes = const [],
  });

  final String id;
  final bool isVerified;
  final String displayName;
  final String email;
  final double rating;
  final int ratingCount;
  final String? bio;
  final String? licenseNumber;
  final String? licenseState;
  final int? yearsExperience;
  final List<String> therapyTypes;
}

class TherapistAppointmentModel {
  const TherapistAppointmentModel({
    required this.id,
    required this.status,
    required this.therapyType,
    required this.scheduledStart,
    required this.childName,
  });

  final String id;
  final String status;
  final String therapyType;
  final DateTime scheduledStart;
  final String childName;
}

class TherapistSessionModel {
  const TherapistSessionModel({
    required this.id,
    required this.status,
    required this.childName,
    this.soapNoteId,
    this.hasSoap = false,
  });

  final String id;
  final String status;
  final String childName;
  final String? soapNoteId;
  final bool hasSoap;
}

class TherapistRepository {
  TherapistRepository(this._graphql);

  final GraphqlClient _graphql;

  Future<TherapistProfileModel> fetchProfile() async {
    const query = r'''
      query {
        myTherapistProfile {
          id
          isVerified
          bio
          licenseNumber
          licenseState
          yearsExperience
          therapyTypes
          ratingAverage
          ratingCount
          user { firstName lastName email }
        }
      }
    ''';
    final result = await _graphql.query(query);
    final p = result['data']?['myTherapistProfile'] as Map<String, dynamic>;
    final user = p['user'] as Map<String, dynamic>;
    return TherapistProfileModel(
      id: p['id'] as String,
      isVerified: p['isVerified'] as bool? ?? false,
      displayName: '${user['firstName']} ${user['lastName']}',
      email: user['email'] as String,
      bio: p['bio'] as String?,
      licenseNumber: p['licenseNumber'] as String?,
      licenseState: p['licenseState'] as String?,
      yearsExperience: p['yearsExperience'] as int?,
      therapyTypes: (p['therapyTypes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rating: (p['ratingAverage'] as num?)?.toDouble() ?? 0,
      ratingCount: p['ratingCount'] as int? ?? 0,
    );
  }

  Future<List<TherapistAppointmentModel>> fetchAppointments() async {
    const query = r'''
      query {
        myTherapistAppointments {
          id
          status
          therapyType
          scheduledStart
          child { firstName lastName }
        }
      }
    ''';
    final result = await _graphql.query(query);
    final list =
        result['data']?['myTherapistAppointments'] as List<dynamic>? ?? [];
    return list.map((e) {
      final child = e['child'] as Map<String, dynamic>;
      return TherapistAppointmentModel(
        id: e['id'] as String,
        status: e['status'] as String? ?? '',
        therapyType: e['therapyType'] as String? ?? '',
        scheduledStart: DateTime.parse(e['scheduledStart'] as String),
        childName: '${child['firstName']} ${child['lastName']}',
      );
    }).toList();
  }

  Future<List<TherapistSessionModel>> fetchSessions() async {
    const query = r'''
      query {
        myTherapistSessions {
          id
          status
          child { firstName lastName }
          soapNote { id }
        }
      }
    ''';
    final result = await _graphql.query(query);
    final list = result['data']?['myTherapistSessions'] as List<dynamic>? ?? [];
    return list.map((e) {
      final child = e['child'] as Map<String, dynamic>;
      final soap = e['soapNote'] as Map<String, dynamic>?;
      return TherapistSessionModel(
        id: e['id'] as String,
        status: e['status'] as String? ?? '',
        childName: '${child['firstName']} ${child['lastName']}',
        soapNoteId: soap?['id'] as String?,
        hasSoap: soap != null,
      );
    }).toList();
  }

  Future<void> updateProfile({
    String? bio,
    String? licenseNumber,
    String? licenseState,
    int? yearsExperience,
  }) async {
    const mutation = r'''
      mutation Update($input: UpdateTherapistProfileInput!) {
        updateTherapistProfile(input: $input) { id }
      }
    ''';
    await _graphql.query(mutation, variables: {
      'input': {
        'bio': ?bio,
        'licenseNumber': ?licenseNumber,
        'licenseState': ?licenseState,
        'yearsExperience': ?yearsExperience,
      },
    });
  }

  Future<String> startSession(String appointmentId) async {
    const mutation = r'''
      mutation Start($appointmentId: ID!) {
        startSession(appointmentId: $appointmentId) { id }
      }
    ''';
    final result = await _graphql.query(mutation, variables: {
      'appointmentId': appointmentId,
    });
    return result['data']?['startSession']?['id'] as String;
  }

  Future<void> saveSoapNote({
    required String sessionId,
    String? subjective,
    String? objective,
    String? assessment,
    String? plan,
  }) async {
    const mutation = r'''
      mutation Save($input: SaveSoapNoteInput!) {
        saveSoapNote(input: $input) { id }
      }
    ''';
    await _graphql.query(mutation, variables: {
      'input': {
        'sessionId': sessionId,
        'subjective': ?subjective,
        'objective': ?objective,
        'assessment': ?assessment,
        'plan': ?plan,
      },
    });
  }
}
