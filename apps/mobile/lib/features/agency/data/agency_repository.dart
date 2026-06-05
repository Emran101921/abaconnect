import '../../../core/network/graphql_client.dart';

class AgencyDashboardModel {
  const AgencyDashboardModel({
    required this.therapistCount,
    required this.activeClients,
    required this.appointmentsToday,
    required this.pendingTherapists,
    required this.missingEvvCount,
    required this.draftClaimsCount,
    required this.cancellationsToday,
    this.actionItems = const [],
  });

  final int therapistCount;
  final int activeClients;
  final int appointmentsToday;
  final int pendingTherapists;
  final int missingEvvCount;
  final int draftClaimsCount;
  final int cancellationsToday;
  final List<Map<String, dynamic>> actionItems;
}

class AgencyAppointmentModel {
  const AgencyAppointmentModel({
    required this.id,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.therapyType,
    required this.status,
    required this.locationType,
    required this.childName,
    required this.therapistName,
  });

  final String id;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final String therapyType;
  final String status;
  final String locationType;
  final String childName;
  final String therapistName;
}

class AgencyTherapistModel {
  const AgencyTherapistModel({
    required this.id,
    required this.displayName,
    required this.isVerified,
    this.licenseNumber,
  });

  final String id;
  final String displayName;
  final bool isVerified;
  final String? licenseNumber;
}

class AgencyRepository {
  AgencyRepository(this._graphql);

  final GraphqlClient _graphql;

  static const _dashboardQuery = r'''
    query AgencyDashboard {
      agencyDashboard {
        therapistCount
        activeClients
        appointmentsToday
        pendingTherapists
        missingEvvCount
        draftClaimsCount
        cancellationsToday
        actionItems {
          id title subtitle actionType priority
          threadId appointmentId sessionId claimId
        }
      }
    }
  ''';

  static const _therapistsQuery = r'''
    query AgencyTherapists {
      agencyTherapists {
        id
        isVerified
        licenseNumber
        user { firstName lastName }
      }
    }
  ''';

  Future<AgencyDashboardModel> fetchDashboard() async {
    final result = await _graphql.query(_dashboardQuery);
    final data = result['data']?['agencyDashboard'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Failed to load agency dashboard');
    }
    return AgencyDashboardModel(
      therapistCount: data['therapistCount'] as int? ?? 0,
      activeClients: data['activeClients'] as int? ?? 0,
      appointmentsToday: data['appointmentsToday'] as int? ?? 0,
      pendingTherapists: data['pendingTherapists'] as int? ?? 0,
      missingEvvCount: data['missingEvvCount'] as int? ?? 0,
      draftClaimsCount: data['draftClaimsCount'] as int? ?? 0,
      cancellationsToday: data['cancellationsToday'] as int? ?? 0,
      actionItems: (data['actionItems'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>(),
    );
  }

  static const _availableInviteQuery = r'''
    query AvailableInvite {
      agencyTherapistsAvailableToInvite {
        id
        isVerified
        licenseNumber
        user { firstName lastName }
      }
    }
  ''';

  static const _inviteMutation = r'''
    mutation Invite($therapistId: ID!) {
      inviteAgencyTherapist(therapistId: $therapistId) {
        id
        isVerified
      }
    }
  ''';

  Future<List<AgencyTherapistModel>> fetchAvailableToInvite() async {
    final result = await _graphql.query(_availableInviteQuery);
    final list = result['data']?['agencyTherapistsAvailableToInvite']
            as List<dynamic>? ??
        [];
    return list.map(_mapTherapist).toList();
  }

  Future<void> removeTherapist(String therapistId) async {
    await _graphql.query(
      r'''
      mutation Remove($therapistId: ID!) {
        removeAgencyTherapist(therapistId: $therapistId)
      }
    ''',
      variables: {'therapistId': therapistId},
    );
  }

  Future<void> inviteTherapist(String therapistId) async {
    await _graphql.query(
      _inviteMutation,
      variables: {'therapistId': therapistId},
    );
  }

  static const _upcomingAppointmentsQuery = r'''
    query AgencyUpcoming {
      agencyUpcomingAppointments {
        id
        scheduledStart
        scheduledEnd
        therapyType
        status
        locationType
        childName
        therapistName
      }
    }
  ''';

  Future<List<AgencyAppointmentModel>> fetchUpcomingAppointments() async {
    final result = await _graphql.query(_upcomingAppointmentsQuery);
    final list =
        result['data']?['agencyUpcomingAppointments'] as List<dynamic>? ?? [];
    return list.map((e) {
      return AgencyAppointmentModel(
        id: e['id'] as String,
        scheduledStart: DateTime.parse(e['scheduledStart'] as String),
        scheduledEnd: DateTime.parse(e['scheduledEnd'] as String),
        therapyType: e['therapyType'] as String? ?? '',
        status: e['status'] as String? ?? '',
        locationType: e['locationType'] as String? ?? '',
        childName: e['childName'] as String? ?? '',
        therapistName: e['therapistName'] as String? ?? '',
      );
    }).toList();
  }

  Future<List<AgencyTherapistModel>> fetchTherapists() async {
    final result = await _graphql.query(_therapistsQuery);
    final list = result['data']?['agencyTherapists'] as List<dynamic>? ?? [];
    return list.map(_mapTherapist).toList();
  }

  AgencyTherapistModel _mapTherapist(dynamic e) {
    final user = e['user'] as Map<String, dynamic>?;
    final name = user != null
        ? '${user['firstName']} ${user['lastName']}'
        : 'Therapist';
    return AgencyTherapistModel(
      id: e['id'] as String,
      displayName: name,
      isVerified: e['isVerified'] as bool? ?? false,
      licenseNumber: e['licenseNumber'] as String?,
    );
  }
}
