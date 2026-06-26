import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/job_opportunities/data/job_opportunities_repository.dart';
import 'package:mobile/features/job_opportunities/widgets/job_offer_summary.dart';

void main() {
  test('JobOfferDetails parses compensation, start date, and message', () {
    final details = JobOfferDetails.fromNote(
      'Compensation: \$70/hr\n\nStart date: Jun 26, 2026\n\nWelcome aboard',
      changedByName: 'Alex Agency',
    );

    expect(details?.compensation, '\$70/hr');
    expect(details?.startDate, 'Jun 26, 2026');
    expect(details?.message, 'Welcome aboard');
    expect(details?.changedByName, 'Alex Agency');
  });

  test('JobOfferDetails.fromHistory reads OFFER_SENT entry', () {
    final details = JobOfferDetails.fromHistory([
      JobApplicationStatusHistoryModel(
        toStatus: 'APPROVED',
        changedByName: 'Therapist',
        createdAt: DateTime(2026, 6, 26),
        note: 'Accepted',
      ),
      JobApplicationStatusHistoryModel(
        fromStatus: 'INTERVIEW_REQUESTED',
        toStatus: 'OFFER_SENT',
        changedByName: 'Alex Agency',
        createdAt: DateTime(2026, 6, 25),
        note: 'Compensation: \$65/hr\n\nWe would like to offer you this role.',
      ),
    ]);

    expect(details?.compensation, '\$65/hr');
    expect(details?.message, 'We would like to offer you this role.');
  });
}
