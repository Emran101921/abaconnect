import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/documents/widgets/employment_document_title_picker.dart';

void main() {
  test('upload title list includes all 17 employment documents', () {
    expect(allEmploymentDocumentUploadTitles, hasLength(17));
    expect(
      allEmploymentDocumentUploadTitles,
      contains('Current NYS Registration Certificate or teaching certificate'),
    );
    expect(allEmploymentDocumentUploadTitles, contains('W-9 Form'));
    expect(
      allEmploymentDocumentUploadTitles,
      contains(
        'Acknowledgement of Receipt of Agency Compliance Plan, Regulations and Onboarding Docs',
      ),
    );
  });
}
