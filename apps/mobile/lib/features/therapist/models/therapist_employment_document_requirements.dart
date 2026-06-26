/// Employment onboarding paperwork required by agency partners.
enum TherapistEmploymentType { w2, contractor1099 }

enum TherapistDocumentRequirementGroup {
  allEmployees,
  contractor1099Only,
  signatureRequired,
}

class TherapistDocumentRequirement {
  const TherapistDocumentRequirement({
    required this.label,
    required this.group,
    this.hint,
    this.suggestedUploadType = 'OTHER',
  });

  final String label;
  final TherapistDocumentRequirementGroup group;
  final String? hint;

  /// Maps to platform [DocumentType] when uploading.
  final String suggestedUploadType;
}

const therapistEmploymentDocumentIntro =
    'Please forward a copy of the following documents.';

const therapist1099AdditionalIntro =
    'Same requirements listed above, plus the following documents.';

const therapistSignatureDocumentsIntro =
    '1099 and W2 employees — documents that require signatures.';

const therapistEmploymentDocumentRequirements = [
  TherapistDocumentRequirement(
    label: 'Current NYS Registration Certificate or teaching certificate',
    group: TherapistDocumentRequirementGroup.allEmployees,
    suggestedUploadType: 'LICENSE',
  ),
  TherapistDocumentRequirement(
    label: 'Current Resume',
    group: TherapistDocumentRequirementGroup.allEmployees,
    suggestedUploadType: 'OTHER',
  ),
  TherapistDocumentRequirement(
    label: 'Current Professional Liability Insurance Certificate',
    group: TherapistDocumentRequirementGroup.allEmployees,
    suggestedUploadType: 'CERTIFICATION',
  ),
  TherapistDocumentRequirement(
    label: 'NYS Dept of Health Early Intervention Approval Letter',
    group: TherapistDocumentRequirementGroup.allEmployees,
    suggestedUploadType: 'CERTIFICATION',
  ),
  TherapistDocumentRequirement(
    label: 'Copy of Photo ID or Passport',
    group: TherapistDocumentRequirementGroup.allEmployees,
    suggestedUploadType: 'OTHER',
  ),
  TherapistDocumentRequirement(
    label: 'NPI#',
    group: TherapistDocumentRequirementGroup.allEmployees,
    hint: 'Enter on your profile under Credentials, or upload supporting documentation.',
    suggestedUploadType: 'LICENSE',
  ),
  TherapistDocumentRequirement(
    label: 'License #',
    group: TherapistDocumentRequirementGroup.allEmployees,
    hint: 'Enter on your profile under Credentials, or upload your license certificate.',
    suggestedUploadType: 'LICENSE',
  ),
  TherapistDocumentRequirement(
    label: 'Physical Form w/ Vaccinations',
    group: TherapistDocumentRequirementGroup.allEmployees,
    suggestedUploadType: 'OTHER',
  ),
  TherapistDocumentRequirement(
    label: 'W-9 Form',
    group: TherapistDocumentRequirementGroup.contractor1099Only,
    suggestedUploadType: 'OTHER',
  ),
  TherapistDocumentRequirement(
    label: 'Letter of Agreement Independent Contract',
    group: TherapistDocumentRequirementGroup.contractor1099Only,
    suggestedUploadType: 'CONSENT_FORM',
  ),
  TherapistDocumentRequirement(
    label: "Worker's Compensation Insurance (or proof of ownership of corp.)",
    group: TherapistDocumentRequirementGroup.contractor1099Only,
    suggestedUploadType: 'CERTIFICATION',
  ),
  TherapistDocumentRequirement(
    label: 'IRS Taxpayer Identification Number (or Supporting Letter)',
    group: TherapistDocumentRequirementGroup.contractor1099Only,
    suggestedUploadType: 'OTHER',
  ),
  TherapistDocumentRequirement(
    label: 'Contract with Hourly Rate and Confidentiality Agreement',
    group: TherapistDocumentRequirementGroup.signatureRequired,
    suggestedUploadType: 'CONSENT_FORM',
  ),
  TherapistDocumentRequirement(
    label: 'Direct Deposit Form',
    group: TherapistDocumentRequirementGroup.signatureRequired,
    suggestedUploadType: 'CONSENT_FORM',
  ),
  TherapistDocumentRequirement(
    label: 'I-9 Form',
    group: TherapistDocumentRequirementGroup.signatureRequired,
    suggestedUploadType: 'CONSENT_FORM',
  ),
  TherapistDocumentRequirement(
    label: 'W-4',
    group: TherapistDocumentRequirementGroup.signatureRequired,
    suggestedUploadType: 'CONSENT_FORM',
  ),
  TherapistDocumentRequirement(
    label:
        'Acknowledgement of Receipt of Agency Compliance Plan, Regulations and Onboarding Docs',
    group: TherapistDocumentRequirementGroup.signatureRequired,
    suggestedUploadType: 'CONSENT_FORM',
  ),
];

List<TherapistDocumentRequirement> requirementsForEmploymentType(
  TherapistEmploymentType type,
) {
  return therapistEmploymentDocumentRequirements.where((req) {
    switch (req.group) {
      case TherapistDocumentRequirementGroup.allEmployees:
      case TherapistDocumentRequirementGroup.signatureRequired:
        return true;
      case TherapistDocumentRequirementGroup.contractor1099Only:
        return type == TherapistEmploymentType.contractor1099;
    }
  }).toList();
}

List<TherapistDocumentRequirement> requirementsInGroup(
  TherapistDocumentRequirementGroup group,
  TherapistEmploymentType type,
) {
  return requirementsForEmploymentType(type)
      .where((req) => req.group == group)
      .toList();
}

String groupTitle(TherapistDocumentRequirementGroup group) {
  switch (group) {
    case TherapistDocumentRequirementGroup.allEmployees:
      return 'All employees (1099 & W2)';
    case TherapistDocumentRequirementGroup.contractor1099Only:
      return '1099 employees only';
    case TherapistDocumentRequirementGroup.signatureRequired:
      return 'Documents requiring signatures';
  }
}

String groupIntro(TherapistDocumentRequirementGroup group) {
  switch (group) {
    case TherapistDocumentRequirementGroup.allEmployees:
      return therapistEmploymentDocumentIntro;
    case TherapistDocumentRequirementGroup.contractor1099Only:
      return therapist1099AdditionalIntro;
    case TherapistDocumentRequirementGroup.signatureRequired:
      return therapistSignatureDocumentsIntro;
  }
}
