import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/graphql_client.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/models/child_medical_chart_model.dart';

enum ClinicalChartsAudience { therapist, agency, serviceCoordinator }

final clinicalChartsRepositoryProvider = Provider<ClinicalChartsRepository>((
  ref,
) {
  return ClinicalChartsRepository(ref.watch(graphqlClientProvider));
});

class ClinicalChartsRepository {
  ClinicalChartsRepository(this._graphql);

  final GraphqlClient _graphql;

  static const _chartFields = '''
    childId
    chartNumber
    firstName
    lastName
    dateOfBirth
    gender
    primaryLanguage
    guardianName
    pediatricianName
    insuranceType
    parentName
    therapyTypes
    upcomingAppointments
    completedSessions
    pendingDocumentation
    lastVisitAt
  ''';

  Future<List<ChildMedicalChartModel>> fetchCharts(
    ClinicalChartsAudience audience,
  ) async {
    final query = switch (audience) {
      ClinicalChartsAudience.therapist => '''
        query {
          myTherapistCaseloadCharts {
            $_chartFields
          }
        }
      ''',
      ClinicalChartsAudience.agency => '''
        query {
          agencyCaseloadCharts {
            $_chartFields
          }
        }
      ''',
      ClinicalChartsAudience.serviceCoordinator => '''
        query {
          myServiceCoordinatorCaseloadCharts {
            $_chartFields
          }
        }
      ''',
    };

    final result = await _graphql.query(query);
    final key = switch (audience) {
      ClinicalChartsAudience.therapist => 'myTherapistCaseloadCharts',
      ClinicalChartsAudience.agency => 'agencyCaseloadCharts',
      ClinicalChartsAudience.serviceCoordinator =>
        'myServiceCoordinatorCaseloadCharts',
    };
    final list = result['data']?[key] as List<dynamic>? ?? [];
    return list
        .map((e) => ChildMedicalChartModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final clinicalChartsProvider =
    FutureProvider.family<List<ChildMedicalChartModel>, ClinicalChartsAudience>(
  (ref, audience) {
    return ref.watch(clinicalChartsRepositoryProvider).fetchCharts(audience);
  },
);
