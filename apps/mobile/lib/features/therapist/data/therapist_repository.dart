import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/graphql_client.dart';
import '../../../core/utils/file_download.dart';
import '../models/eip_session_note_model.dart';

class TherapistProfileModel {
  const TherapistProfileModel({
    required this.id,
    required this.isVerified,
    required this.displayName,
    required this.email,
    required this.rating,
    required this.ratingCount,
    this.bio,
    this.npi,
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
  final String? npi;
  final String? licenseNumber;
  final String? licenseState;

  bool get hasRequiredCredentials =>
      (npi?.trim().isNotEmpty ?? false) &&
      (licenseNumber?.trim().isNotEmpty ?? false);
  final int? yearsExperience;
  final List<String> therapyTypes;
}

class TherapistDashboardModel {
  const TherapistDashboardModel({
    required this.pendingRequests,
    required this.appointmentsToday,
    required this.inProgressSessions,
    required this.pendingDocumentation,
    required this.unreadMessages,
    this.actionItems = const [],
  });

  final int pendingRequests;
  final int appointmentsToday;
  final int inProgressSessions;
  final int pendingDocumentation;
  final int unreadMessages;
  final List<Map<String, dynamic>> actionItems;
}

class TherapistAppointmentModel {
  const TherapistAppointmentModel({
    required this.id,
    required this.status,
    required this.therapyType,
    required this.scheduledStart,
    required this.childName,
    required this.childId,
    this.locationType,
  });

  final String id;
  final String status;
  final String therapyType;
  final DateTime scheduledStart;
  final String childName;
  final String childId;
  final String? locationType;

  bool get isTelehealth => locationType == 'TELEHEALTH';
}

class TherapistSessionModel {
  const TherapistSessionModel({
    required this.id,
    required this.status,
    required this.childName,
    this.childId,
    this.soapNoteId,
    this.hasSoap = false,
    this.subjective,
    this.objective,
    this.assessment,
    this.plan,
  });

  final String id;
  final String status;
  final String childName;
  final String? childId;
  final String? soapNoteId;
  final bool hasSoap;
  final String? subjective;
  final String? objective;
  final String? assessment;
  final String? plan;

  bool get needsDocumentation =>
      status == 'IN_PROGRESS' || status == 'PENDING_DOCUMENTATION';
}

class TherapistRepository {
  TherapistRepository(this._graphql, this._api);

  final GraphqlClient _graphql;
  final ApiClient _api;

  Future<TherapistDashboardModel> fetchDashboard() async {
    const query = r'''
      query TherapistDashboard {
        therapistDashboard {
          pendingRequests
          appointmentsToday
          inProgressSessions
          pendingDocumentation
          unreadMessages
          actionItems {
            id title subtitle actionType priority
            threadId appointmentId sessionId claimId
          }
        }
      }
    ''';
    final result = await _graphql.query(query);
    final d = result['data']?['therapistDashboard'] as Map<String, dynamic>?;
    if (d == null) {
      throw Exception('therapistDashboard unavailable');
    }
    return TherapistDashboardModel(
      pendingRequests: d['pendingRequests'] as int? ?? 0,
      appointmentsToday: d['appointmentsToday'] as int? ?? 0,
      inProgressSessions: d['inProgressSessions'] as int? ?? 0,
      pendingDocumentation: d['pendingDocumentation'] as int? ?? 0,
      unreadMessages: d['unreadMessages'] as int? ?? 0,
      actionItems: (d['actionItems'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>(),
    );
  }

  Future<TherapistProfileModel> fetchProfile() async {
    const query = r'''
      query {
        myTherapistProfile {
          id
          isVerified
          bio
          npi
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
      npi: p['npi'] as String?,
      licenseNumber: p['licenseNumber'] as String?,
      licenseState: p['licenseState'] as String?,
      yearsExperience: p['yearsExperience'] as int?,
      therapyTypes:
          (p['therapyTypes'] as List<dynamic>?)
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
          locationType
          child { id firstName lastName }
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
        childId: child['id'] as String,
        locationType: e['locationType'] as String?,
      );
    }).toList();
  }

  Future<List<TherapistSessionModel>> fetchSessions() async {
    const query = r'''
      query {
        myTherapistSessions {
          id
          status
          child { id firstName lastName }
          soapNote {
            id subjective objective assessment plan
          }
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
        childId: child['id'] as String?,
        soapNoteId: soap?['id'] as String?,
        hasSoap: soap != null,
        subjective: soap?['subjective'] as String?,
        objective: soap?['objective'] as String?,
        assessment: soap?['assessment'] as String?,
        plan: soap?['plan'] as String?,
      );
    }).toList();
  }

  Future<void> updateProfile({
    String? bio,
    String? npi,
    String? licenseNumber,
    String? licenseState,
    int? yearsExperience,
  }) async {
    const mutation = r'''
      mutation Update($input: UpdateTherapistProfileInput!) {
        updateTherapistProfile(input: $input) { id }
      }
    ''';
    await _graphql.query(
      mutation,
      variables: {
        'input': {
          'bio': ?bio,
          'npi': ?npi,
          'licenseNumber': ?licenseNumber,
          'licenseState': ?licenseState,
          'yearsExperience': ?yearsExperience,
        },
      },
    );
  }

  Future<String> downloadAppointmentsIcal() async {
    final response = await _api.dio.get<List<int>>(
      '/therapist/appointments/ical',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(response.data ?? []);
    return downloadBytes(bytes, 'abaconnect-therapist.ics');
  }

  Future<void> confirmAppointment(String appointmentId) async {
    const mutation = r'''
      mutation Confirm($appointmentId: ID!) {
        confirmAppointment(appointmentId: $appointmentId) { id status }
      }
    ''';
    await _graphql.query(mutation, variables: {'appointmentId': appointmentId});
  }

  Future<void> cancelAppointment(String appointmentId, {String? reason}) async {
    const mutation = r'''
      mutation Cancel($appointmentId: ID!, $reason: String) {
        cancelAppointmentAsTherapist(appointmentId: $appointmentId, reason: $reason) { id status }
      }
    ''';
    await _graphql.query(
      mutation,
      variables: {'appointmentId': appointmentId, 'reason': ?reason},
    );
  }

  Future<void> declineAppointment(
    String appointmentId, {
    String? reason,
  }) async {
    const mutation = r'''
      mutation Decline($appointmentId: ID!, $reason: String) {
        declineAppointment(appointmentId: $appointmentId, reason: $reason) { id status }
      }
    ''';
    await _graphql.query(
      mutation,
      variables: {'appointmentId': appointmentId, 'reason': ?reason},
    );
  }

  Future<void> completeSession(String sessionId) async {
    const mutation = r'''
      mutation Complete($sessionId: ID!) {
        completeSession(sessionId: $sessionId) { id status }
      }
    ''';
    await _graphql.query(mutation, variables: {'sessionId': sessionId});
  }

  Future<String> startSession(String appointmentId) async {
    const mutation = r'''
      mutation Start($appointmentId: ID!) {
        startSession(appointmentId: $appointmentId) { id }
      }
    ''';
    final result = await _graphql.query(
      mutation,
      variables: {'appointmentId': appointmentId},
    );
    return result['data']?['startSession']?['id'] as String;
  }

  Future<void> saveSoapNote({
    required String sessionId,
    String? subjective,
    String? objective,
    String? assessment,
    String? plan,
    String? eipFormData,
  }) async {
    const mutation = r'''
      mutation Save($input: SaveSoapNoteInput!) {
        saveSoapNote(input: $input) { id }
      }
    ''';
    await _graphql.query(
      mutation,
      variables: {
        'input': {
          'sessionId': sessionId,
          'subjective': ?subjective,
          'objective': ?objective,
          'assessment': ?assessment,
          'plan': ?plan,
          'eipFormData': ?eipFormData,
        },
      },
    );
  }

  Future<Map<String, dynamic>> fetchSessionNoteFormContext(
    String sessionId,
  ) async {
    final result = await _graphql.query(
      r'''
      query Context($sessionId: ID!) {
        sessionNoteFormContext(sessionId: $sessionId) {
          sessionId childName childDob childSex eiNumber
          interventionistName credentials npi serviceType
          sessionDate ifspServiceLocation timeFrom timeTo
          sessionDelivered icd10Code existingEipFormData
        }
      }
    ''',
      variables: {'sessionId': sessionId},
    );
    final data = result['data']?['sessionNoteFormContext'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Could not load session note context');
    }
    return data;
  }

  Future<void> saveEipSessionNote(EipSessionNoteModel form) async {
    await saveSoapNote(
      sessionId: form.sessionId,
      subjective: form.toSoapSubjective(),
      objective: form.toSoapObjective(),
      assessment: form.toSoapAssessment(),
      plan: form.toSoapPlan(),
      eipFormData: jsonEncode(form.toJson()),
    );
  }
}
