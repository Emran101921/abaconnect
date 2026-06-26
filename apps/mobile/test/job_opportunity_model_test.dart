import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/job_opportunities/data/job_opportunities_repository.dart';

void main() {
  test('JobOpportunityModel tolerates null optional fields from API', () {
    final model = JobOpportunityModel.fromJson({
      'id': 'fdfa4c32-0973-4aa4-a319-534e02a989f8',
      'title': 'Service Coordination Therapist Needed – 11235 area',
      'status': 'DRAFT',
      'serviceType': 'SERVICE_COORDINATION',
      'serviceTypeLabel': 'Service Coordination',
      'locationAreaLabel': '11235 area',
      'zipCode': '11235',
      'locationModality': 'IN_PERSON',
      'disclaimer': 'disclaimer text',
      'createdAt': '2026-06-25T04:16:36.698Z',
      'publicDescription': null,
      'payRateDisplay': null,
      'applicationCount': 0,
      'publishedAt': null,
    });
    expect(model.id, isNotEmpty);
    expect(model.publicDescription, isNull);
  });

  test('JobOpportunityModel tolerates partial mutation payload', () {
    final model = JobOpportunityModel.fromJson({
      'id': 'abc',
      'status': 'PUBLISHED',
    });
    expect(model.id, 'abc');
    expect(model.status, 'PUBLISHED');
  });

  test('ChildServiceNeedModel tolerates null optional fields', () {
    final model = ChildServiceNeedModel.fromJson({
      'id': 'need-1',
      'serviceType': 'OT',
      'status': 'OPEN',
      'childDisplayName': 'Jordan D.',
      'createdAt': '2026-06-25T04:17:04.118Z',
      'internalNotes': null,
      'jobOpportunityId': null,
    });
    expect(model.id, 'need-1');
  });
}
