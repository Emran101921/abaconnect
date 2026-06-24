class ChildMedicalChartModel {
  const ChildMedicalChartModel({
    required this.childId,
    required this.chartNumber,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.parentName,
    this.gender,
    this.primaryLanguage,
    this.guardianName,
    this.pediatricianName,
    this.insuranceType,
    this.therapyTypes = const [],
    this.upcomingAppointments = 0,
    this.completedSessions = 0,
    this.pendingDocumentation = 0,
    this.lastVisitAt,
  });

  final String childId;
  final String chartNumber;
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final String parentName;
  final String? gender;
  final String? primaryLanguage;
  final String? guardianName;
  final String? pediatricianName;
  final String? insuranceType;
  final List<String> therapyTypes;
  final int upcomingAppointments;
  final int completedSessions;
  final int pendingDocumentation;
  final DateTime? lastVisitAt;

  String get displayName => '$firstName $lastName';

  factory ChildMedicalChartModel.fromJson(Map<String, dynamic> row) {
    return ChildMedicalChartModel(
      childId: row['childId'] as String,
      chartNumber: row['chartNumber'] as String,
      firstName: row['firstName'] as String,
      lastName: row['lastName'] as String,
      dateOfBirth: DateTime.parse(row['dateOfBirth'] as String),
      parentName: row['parentName'] as String,
      gender: row['gender'] as String?,
      primaryLanguage: row['primaryLanguage'] as String?,
      guardianName: row['guardianName'] as String?,
      pediatricianName: row['pediatricianName'] as String?,
      insuranceType: row['insuranceType'] as String?,
      therapyTypes:
          (row['therapyTypes'] as List<dynamic>?)
              ?.map((t) => t.toString())
              .toList() ??
          const [],
      upcomingAppointments: row['upcomingAppointments'] as int? ?? 0,
      completedSessions: row['completedSessions'] as int? ?? 0,
      pendingDocumentation: row['pendingDocumentation'] as int? ?? 0,
      lastVisitAt: row['lastVisitAt'] != null
          ? DateTime.parse(row['lastVisitAt'] as String)
          : null,
    );
  }
}
