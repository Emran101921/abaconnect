import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/job_opportunities/data/job_opportunities_graphql.dart';

void main() {
  test('application list queries do not contain literal interpolation markers', () {
    for (final document in [
      myJobApplicationsDocument(),
      agencyJobApplicationsDocument(),
      adminJobApplicationsDocument(),
    ]) {
      expect(document, isNot(contains(r'$_')));
      expect(document, contains('id status message therapistName'));
    }
  });

  test('interview queries expand field selection', () {
    final document = myJobInterviewsDocument();
    expect(document, isNot(contains(r'$_')));
    expect(document, contains('scheduledAt durationMinutes status'));
  });
}
