enum EiFieldType { text, yesNo, multiChoice, priority, date }

class EiFieldConfig {
  const EiFieldConfig({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.maxLines = 1,
    this.options = const [],
    this.readOnly = false,
  });

  final String key;
  final String label;
  final EiFieldType type;
  final bool required;
  final int maxLines;
  final List<String> options;
  final bool readOnly;
}

class EiSectionConfig {
  const EiSectionConfig({required this.title, required this.fields});

  final String title;
  final List<EiFieldConfig> fields;
}

List<EiSectionConfig> initialEiSections() => [
  EiSectionConfig(
    title: '1. Child information',
    fields: [
      EiFieldConfig(key: 'childFirstName', label: 'Child first name', type: EiFieldType.text, required: true, readOnly: true),
      EiFieldConfig(key: 'childLastName', label: 'Child last name', type: EiFieldType.text, readOnly: true),
      EiFieldConfig(key: 'childDateOfBirth', label: 'Date of birth', type: EiFieldType.date, required: true, readOnly: true),
      EiFieldConfig(key: 'childGender', label: 'Gender', type: EiFieldType.text, readOnly: true),
      EiFieldConfig(key: 'childPrimaryLanguage', label: 'Primary language', type: EiFieldType.text, readOnly: true),
    ],
  ),
  EiSectionConfig(
    title: '2. Parent/guardian information',
    fields: [
      EiFieldConfig(key: 'guardianName', label: 'Guardian name', type: EiFieldType.text, required: true, readOnly: true),
      EiFieldConfig(key: 'guardianPhone', label: 'Guardian phone', type: EiFieldType.text, required: true, readOnly: true),
      EiFieldConfig(key: 'guardianEmail', label: 'Guardian email', type: EiFieldType.text, readOnly: true),
      EiFieldConfig(key: 'guardianRelationship', label: 'Relationship to child', type: EiFieldType.text),
      EiFieldConfig(key: 'secondaryGuardian', label: 'Secondary caregiver', type: EiFieldType.text),
    ],
  ),
  EiSectionConfig(
    title: '3. Referral source',
    fields: [
      EiFieldConfig(key: 'referralSource', label: 'Referral source', type: EiFieldType.text, required: true),
      EiFieldConfig(
        key: 'referralType',
        label: 'Referral type',
        type: EiFieldType.multiChoice,
        options: ['Pediatrician', 'Hospital', 'Parent self-referral', 'School', 'Other'],
      ),
    ],
  ),
  EiSectionConfig(
    title: '4. Parent concerns',
    fields: [
      EiFieldConfig(key: 'parentConcerns', label: 'Primary concerns', type: EiFieldType.text, required: true, maxLines: 4),
      EiFieldConfig(key: 'concernPriority', label: 'Concern priority', type: EiFieldType.priority),
      EiFieldConfig(key: 'severeParentConcern', label: 'Severe parent concern?', type: EiFieldType.yesNo),
    ],
  ),
  EiSectionConfig(
    title: '5. Medical/birth history',
    fields: [
      EiFieldConfig(key: 'medicalHistory', label: 'Medical/birth history', type: EiFieldType.text, maxLines: 4),
      EiFieldConfig(key: 'prematureBirth', label: 'Premature birth?', type: EiFieldType.yesNo),
      EiFieldConfig(key: 'hospitalizationHistory', label: 'Hospitalizations?', type: EiFieldType.yesNo),
      EiFieldConfig(key: 'diagnosisHistory', label: 'Known diagnoses', type: EiFieldType.text, maxLines: 2),
    ],
  ),
  EiSectionConfig(
    title: '6. Communication/speech concerns',
    fields: [
      EiFieldConfig(key: 'communicationConcerns', label: 'Communication concerns?', type: EiFieldType.yesNo),
      EiFieldConfig(key: 'speechDelay', label: 'Speech delay noted?', type: EiFieldType.yesNo),
      EiFieldConfig(key: 'communicationNotes', label: 'Details', type: EiFieldType.text, maxLines: 3),
    ],
  ),
  EiSectionConfig(
    title: '7. Motor skills concerns',
    fields: [
      EiFieldConfig(key: 'motorConcerns', label: 'Motor skills concerns?', type: EiFieldType.yesNo),
      EiFieldConfig(key: 'motorDelay', label: 'Motor delay noted?', type: EiFieldType.yesNo),
      EiFieldConfig(key: 'motorNotes', label: 'Details', type: EiFieldType.text, maxLines: 3),
    ],
  ),
  EiSectionConfig(
    title: '8. Social-emotional/behavior concerns',
    fields: [
      EiFieldConfig(key: 'socialEmotionalConcerns', label: 'Social-emotional concerns?', type: EiFieldType.yesNo),
      EiFieldConfig(key: 'behaviorConcerns', label: 'Behavior concerns?', type: EiFieldType.yesNo),
      EiFieldConfig(key: 'socialEmotionalNotes', label: 'Details', type: EiFieldType.text, maxLines: 3),
    ],
  ),
  EiSectionConfig(
    title: '9. Feeding/sleeping/daily living',
    fields: [
      EiFieldConfig(key: 'dailyLivingConcerns', label: 'Feeding/sleeping/daily living concerns?', type: EiFieldType.yesNo),
      EiFieldConfig(key: 'feedingConcerns', label: 'Feeding concerns?', type: EiFieldType.yesNo),
      EiFieldConfig(key: 'sleepConcerns', label: 'Sleep concerns?', type: EiFieldType.yesNo),
      EiFieldConfig(key: 'dailyLivingNotes', label: 'Details', type: EiFieldType.text, maxLines: 3),
    ],
  ),
  EiSectionConfig(
    title: '10. Family priorities & resources',
    fields: [
      EiFieldConfig(key: 'familyPriorities', label: 'Family priorities', type: EiFieldType.text, maxLines: 3),
      EiFieldConfig(key: 'familyResourcesNeeded', label: 'Resources needed?', type: EiFieldType.yesNo),
      EiFieldConfig(key: 'familyResourcesNotes', label: 'Resource details', type: EiFieldType.text, maxLines: 2),
    ],
  ),
  EiSectionConfig(
    title: '11. Insurance/Medicaid',
    fields: [
      EiFieldConfig(key: 'insuranceType', label: 'Insurance type', type: EiFieldType.text),
      EiFieldConfig(key: 'medicaidEnrolled', label: 'Medicaid enrolled?', type: EiFieldType.yesNo),
      EiFieldConfig(key: 'insuranceMemberId', label: 'Member ID', type: EiFieldType.text),
    ],
  ),
  EiSectionConfig(
    title: '12. Evaluation planning',
    fields: [
      EiFieldConfig(key: 'evaluationNeeded', label: 'Evaluation needed?', type: EiFieldType.yesNo),
      EiFieldConfig(
        key: 'evaluationTypes',
        label: 'Evaluation types',
        type: EiFieldType.multiChoice,
        options: ['Speech', 'OT', 'PT', 'Developmental', 'Other'],
      ),
      EiFieldConfig(key: 'evaluationTimeline', label: 'Target timeline', type: EiFieldType.text),
    ],
  ),
  EiSectionConfig(
    title: '13. Consent & privacy',
    fields: [
      EiFieldConfig(key: 'consentAcknowledged', label: 'Consent acknowledged', type: EiFieldType.yesNo, required: true),
      EiFieldConfig(key: 'privacyNoticeReviewed', label: 'Privacy notice reviewed?', type: EiFieldType.yesNo),
    ],
  ),
  EiSectionConfig(
    title: '14. Notes & next steps',
    fields: [
      EiFieldConfig(key: 'nextSteps', label: 'Next steps', type: EiFieldType.text, maxLines: 3),
      EiFieldConfig(key: 'coordinatorSummary', label: 'Coordinator summary', type: EiFieldType.text, maxLines: 3),
    ],
  ),
];

List<EiSectionConfig> ongoingEiSections() => [
  EiSectionConfig(
    title: '1. Current services status',
    fields: [
      EiFieldConfig(key: 'servicesActive', label: 'Are services active?', type: EiFieldType.yesNo, required: true),
      EiFieldConfig(key: 'noServicesStarted', label: 'No services started yet?', type: EiFieldType.yesNo),
      EiFieldConfig(key: 'activeServiceTypes', label: 'Active services', type: EiFieldType.text, maxLines: 2),
    ],
  ),
  EiSectionConfig(
    title: '2. Provider attendance/missed visits',
    fields: [
      EiFieldConfig(key: 'missedSessions', label: 'Any missed sessions?', type: EiFieldType.yesNo),
      EiFieldConfig(key: 'missedSessionCount', label: 'Missed session count', type: EiFieldType.text),
      EiFieldConfig(key: 'providerIssues', label: 'Any provider issues?', type: EiFieldType.yesNo),
    ],
  ),
  EiSectionConfig(
    title: '3. Child progress update',
    fields: [
      EiFieldConfig(key: 'childProgress', label: 'Progress update', type: EiFieldType.text, required: true, maxLines: 4),
      EiFieldConfig(key: 'childRegression', label: 'Any regression?', type: EiFieldType.yesNo),
    ],
  ),
  EiSectionConfig(
    title: '4. Family priority changes',
    fields: [
      EiFieldConfig(key: 'priorityChanges', label: 'Priority changes', type: EiFieldType.text, maxLines: 3),
      EiFieldConfig(key: 'familyGoalsUpdated', label: 'Goals updated?', type: EiFieldType.yesNo),
    ],
  ),
  EiSectionConfig(
    title: '5. New concerns',
    fields: [
      EiFieldConfig(key: 'newConcernsFlag', label: 'New concerns?', type: EiFieldType.yesNo),
      EiFieldConfig(key: 'newConcernsDetail', label: 'New concern details', type: EiFieldType.text, maxLines: 3),
      EiFieldConfig(key: 'moderateConcern', label: 'Moderate concern level?', type: EiFieldType.yesNo),
    ],
  ),
  EiSectionConfig(
    title: '6. Provider communication',
    fields: [
      EiFieldConfig(key: 'providerCommunication', label: 'Provider communication notes', type: EiFieldType.text, maxLines: 3),
      EiFieldConfig(key: 'providerCoordinationNeeded', label: 'Coordination needed?', type: EiFieldType.yesNo),
    ],
  ),
  EiSectionConfig(
    title: '7. IFSP/plan review',
    fields: [
      EiFieldConfig(key: 'ifspReviewNeeded', label: 'IFSP/plan review needed?', type: EiFieldType.yesNo),
      EiFieldConfig(key: 'ifspReviewDate', label: 'Review target date', type: EiFieldType.date),
    ],
  ),
  EiSectionConfig(
    title: '8. Safety/risk check',
    fields: [
      EiFieldConfig(key: 'urgentSafetyConcern', label: 'Urgent safety concern?', type: EiFieldType.yesNo),
      EiFieldConfig(key: 'familyCrisis', label: 'Family crisis or urgent concern?', type: EiFieldType.yesNo),
      EiFieldConfig(key: 'safetyPlanNeeded', label: 'Safety plan needed?', type: EiFieldType.yesNo),
    ],
  ),
  EiSectionConfig(
    title: '9. Transition planning',
    fields: [
      EiFieldConfig(key: 'transitionPlanning', label: 'Transition planning notes', type: EiFieldType.text, maxLines: 2),
      EiFieldConfig(key: 'transitionDue', label: 'Transition due?', type: EiFieldType.yesNo),
    ],
  ),
  EiSectionConfig(
    title: '10. Follow-up action plan',
    fields: [
      EiFieldConfig(key: 'actionItems', label: 'Action items', type: EiFieldType.text, maxLines: 3),
      EiFieldConfig(key: 'nextFollowUpDate', label: 'Next follow-up date', type: EiFieldType.date, required: true),
      EiFieldConfig(key: 'followUpRequired', label: 'Follow-up required?', type: EiFieldType.yesNo),
    ],
  ),
];

List<String> requiredKeysForSections(List<EiSectionConfig> sections) {
  return sections
      .expand((s) => s.fields)
      .where((f) => f.required)
      .map((f) => f.key)
      .toList();
}

int completionPercentForSections(
  Map<String, dynamic> answers,
  List<EiSectionConfig> sections,
) {
  final required = requiredKeysForSections(sections);
  if (required.isEmpty) return 100;
  final filled = required.where((k) {
    final v = answers[k];
    if (v is bool) return v;
    return v != null && v.toString().trim().isNotEmpty;
  }).length;
  return ((filled / required.length) * 100).round();
}
