import '../../../core/network/graphql_client.dart';

class AgencyDashboardModel {
  const AgencyDashboardModel({
    required this.therapistCount,
    required this.activeClients,
    required this.appointmentsToday,
    required this.pendingTherapists,
  });

  final int therapistCount;
  final int activeClients;
  final int appointmentsToday;
  final int pendingTherapists;
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
    );
  }

  Future<List<AgencyTherapistModel>> fetchTherapists() async {
    final result = await _graphql.query(_therapistsQuery);
    final list = result['data']?['agencyTherapists'] as List<dynamic>? ?? [];
    return list.map((e) {
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
    }).toList();
  }
}
