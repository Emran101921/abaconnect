import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/therapist/models/therapist_employment_document_requirements.dart';

void main() {
  test('W2 employees see all-employee and signature groups only', () {
    final items = requirementsForEmploymentType(TherapistEmploymentType.w2);
    expect(
      items.any((r) => r.label.contains('W-9')),
      isFalse,
    );
    expect(
      items.any((r) => r.label.contains('NYS Registration')),
      isTrue,
    );
    expect(
      items.any((r) => r.label.contains('I-9')),
      isTrue,
    );
  });

  test('1099 contractors include additional paperwork', () {
    final items = requirementsForEmploymentType(
      TherapistEmploymentType.contractor1099,
    );
    expect(items.any((r) => r.label.contains('W-9')), isTrue);
    expect(
      items.any((r) => r.label.contains('Worker\'s Compensation')),
      isTrue,
    );
  });
}
