import 'dart:convert';

/// NYC Early Intervention Program Individual Session Note (Home/Facility).
class EipSessionNoteModel {
  const EipSessionNoteModel({
    required this.sessionId,
    this.childName = '',
    this.childDob,
    this.childSex,
    this.eiNumber,
    this.interventionistName = '',
    this.credentials,
    this.npi,
    this.licenseNumber,
    this.licenseState,
    this.serviceType,
    this.sessionDate,
    this.ifspServiceLocation,
    this.timeFrom,
    this.timeFromAmPm = 'AM',
    this.timeTo,
    this.timeToAmPm = 'PM',
    this.intensity = 'Home/Community',
    this.sessionDelivered = 'In-person',
    this.dateNoteWritten,
    this.icd10Code,
    this.hcpcsCode,
    this.cptCode1,
    this.cptCode2,
    this.cptCode3,
    this.cptCode4,
    this.sessionCancelled = false,
    this.cancellationReason,
    this.makeupByDate,
    this.isMakeup = false,
    this.makeupForDate,
    this.participantChild = true,
    this.participantParent = true,
    this.participantOther,
    this.q1IfspOutcomes = '',
    this.q2SessionDescription = '',
    this.q3ObservedRoutines = false,
    this.q3ParentTriedActivity = false,
    this.q3DemonstratedActivity = false,
    this.q3ReviewedCommTool = false,
    this.q3Other,
    this.q4HomeStrategies = '',
    this.parentSignature,
    this.parentSignatureDate,
    this.parentRelationship,
    this.interventionistSignature,
    this.interventionistSignatureDate,
    this.interventionistSignatureLatitude,
    this.interventionistSignatureLongitude,
    this.interventionistSignatureLocationAt,
    this.interventionistLicense,
    this.parentSignatureLatitude,
    this.parentSignatureLongitude,
    this.parentSignatureLocationAt,
    this.supervisorName,
    this.supervisorSignatureDate,
    this.supervisorLicense,
  });

  final String sessionId;
  final String childName;
  final String? childDob;
  final String? childSex;
  final String? eiNumber;
  final String interventionistName;
  final String? credentials;
  final String? npi;
  final String? licenseNumber;
  final String? licenseState;
  final String? serviceType;
  final String? sessionDate;
  final String? ifspServiceLocation;
  final String? timeFrom;
  final String timeFromAmPm;
  final String? timeTo;
  final String timeToAmPm;
  final String intensity;
  final String sessionDelivered;
  final String? dateNoteWritten;
  final String? icd10Code;
  final String? hcpcsCode;
  final String? cptCode1;
  final String? cptCode2;
  final String? cptCode3;
  final String? cptCode4;
  final bool sessionCancelled;
  final String? cancellationReason;
  final String? makeupByDate;
  final bool isMakeup;
  final String? makeupForDate;
  final bool participantChild;
  final bool participantParent;
  final String? participantOther;
  final String q1IfspOutcomes;
  final String q2SessionDescription;
  final bool q3ObservedRoutines;
  final bool q3ParentTriedActivity;
  final bool q3DemonstratedActivity;
  final bool q3ReviewedCommTool;
  final String? q3Other;
  final String q4HomeStrategies;
  final String? parentSignature;
  final String? parentSignatureDate;
  final String? parentRelationship;
  final String? interventionistSignature;
  final String? interventionistSignatureDate;
  final double? interventionistSignatureLatitude;
  final double? interventionistSignatureLongitude;
  final String? interventionistSignatureLocationAt;
  final String? interventionistLicense;
  final double? parentSignatureLatitude;
  final double? parentSignatureLongitude;
  final String? parentSignatureLocationAt;
  final String? supervisorName;
  final String? supervisorSignatureDate;
  final String? supervisorLicense;

  bool get hasRequiredClinicalFields =>
      q1IfspOutcomes.trim().isNotEmpty &&
      q2SessionDescription.trim().isNotEmpty &&
      q4HomeStrategies.trim().isNotEmpty;

  bool get hasParentRelationship =>
      parentRelationship?.trim().isNotEmpty ?? false;

  bool get hasQ3Technique =>
      q3ObservedRoutines ||
      q3ParentTriedActivity ||
      q3DemonstratedActivity ||
      q3ReviewedCommTool ||
      (q3Other?.trim().isNotEmpty ?? false);

  bool get hasSessionParticipant =>
      participantChild ||
      participantParent ||
      (participantOther?.trim().isNotEmpty ?? false);

  bool get isReadyForParentSignature =>
      missingFieldsForParentSignature().isEmpty;

  List<String> missingFieldsForParentSignature() {
    final missing = <String>[];

    if (childName.trim().isEmpty) missing.add('Child\'s name');
    if (childDob?.trim().isEmpty ?? true) missing.add('DOB');
    if (childSex?.trim().isEmpty ?? true) missing.add('Sex');
    if (interventionistName.trim().isEmpty) missing.add('Interventionist name');
    if (credentials?.trim().isEmpty ?? true) missing.add('Credentials');
    if (npi?.trim().isEmpty ?? true) missing.add('NPI');
    if (licenseNumber?.trim().isEmpty ?? true) {
      missing.add('State license number');
    }
    if (serviceType?.trim().isEmpty ?? true) missing.add('Service type');

    if (sessionDate?.trim().isEmpty ?? true) missing.add('Session date');
    if (ifspServiceLocation?.trim().isEmpty ?? true) {
      missing.add('IFSP service location');
    } else if (ifspServiceLocation == 'Other') {
      missing.add('Specified IFSP service location');
    }
    if (timeFrom?.trim().isEmpty ?? true) missing.add('Time from');
    if (timeTo?.trim().isEmpty ?? true) missing.add('Time to');
    if (intensity.trim().isEmpty) {
      missing.add('Intensity');
    } else if (intensity == 'Other') {
      missing.add('Specified intensity');
    }
    if (sessionDelivered.trim().isEmpty) missing.add('Session delivered');
    if (dateNoteWritten?.trim().isEmpty ?? true) {
      missing.add('Date note written');
    }
    if (icd10Code?.trim().isEmpty ?? true) missing.add('ICD-10 code');

    if (!hasSessionParticipant) missing.add('Session participants');

    if (q1IfspOutcomes.trim().isEmpty) missing.add('IFSP outcomes (#1)');
    if (q2SessionDescription.trim().isEmpty) {
      missing.add('Session description (#2)');
    }
    if (!hasQ3Technique) {
      missing.add('Parent/caregiver technique (#3)');
    }
    if (q4HomeStrategies.trim().isEmpty) missing.add('Home strategies (#4)');

    if (sessionCancelled && (cancellationReason?.trim().isEmpty ?? true)) {
      missing.add('Cancellation reason');
    }
    if (isMakeup && (makeupForDate?.trim().isEmpty ?? true)) {
      missing.add('Make-up for missed session date');
    }

    if (!hasParentRelationship) missing.add('Relationship to child');
    return missing;
  }

  bool get hasInterventionistSignature =>
      interventionistSignature?.trim().isNotEmpty ?? false;

  bool get hasGpsVerifiedInterventionistSignature =>
      hasInterventionistSignature &&
      interventionistSignatureLatitude != null &&
      interventionistSignatureLongitude != null;

  bool get hasParentSignature => parentSignature?.trim().isNotEmpty ?? false;

  bool get hasParentSignatureGpsCapture =>
      parentSignatureLatitude != null && parentSignatureLongitude != null;

  bool get hasGpsVerifiedParentSignature =>
      hasParentSignature && hasParentSignatureGpsCapture;

  /// Signatures without GPS coordinates are not allowed to be saved.
  bool get hasInvalidSignatures =>
      (hasInterventionistSignature && !hasGpsVerifiedInterventionistSignature) ||
      (hasParentSignature && !hasGpsVerifiedParentSignature);

  bool get isFullySigned =>
      hasGpsVerifiedInterventionistSignature && hasGpsVerifiedParentSignature;

  EipSessionNoteModel copyWith({
    String? childName,
    String? childDob,
    String? childSex,
    String? eiNumber,
    String? interventionistName,
    String? credentials,
    String? npi,
    String? licenseNumber,
    String? licenseState,
    String? serviceType,
    String? sessionDate,
    String? ifspServiceLocation,
    String? timeFrom,
    String? timeFromAmPm,
    String? timeTo,
    String? timeToAmPm,
    String? intensity,
    String? sessionDelivered,
    String? dateNoteWritten,
    String? icd10Code,
    String? hcpcsCode,
    String? cptCode1,
    String? cptCode2,
    String? cptCode3,
    String? cptCode4,
    bool? sessionCancelled,
    String? cancellationReason,
    String? makeupByDate,
    bool? isMakeup,
    String? makeupForDate,
    bool? participantChild,
    bool? participantParent,
    String? participantOther,
    String? q1IfspOutcomes,
    String? q2SessionDescription,
    bool? q3ObservedRoutines,
    bool? q3ParentTriedActivity,
    bool? q3DemonstratedActivity,
    bool? q3ReviewedCommTool,
    String? q3Other,
    String? q4HomeStrategies,
    String? parentSignature,
    String? parentSignatureDate,
    String? parentRelationship,
    String? interventionistSignature,
    String? interventionistSignatureDate,
    double? interventionistSignatureLatitude,
    double? interventionistSignatureLongitude,
    String? interventionistSignatureLocationAt,
    String? interventionistLicense,
    double? parentSignatureLatitude,
    double? parentSignatureLongitude,
    String? parentSignatureLocationAt,
    String? supervisorName,
    String? supervisorSignatureDate,
    String? supervisorLicense,
  }) {
    return EipSessionNoteModel(
      sessionId: sessionId,
      childName: childName ?? this.childName,
      childDob: childDob ?? this.childDob,
      childSex: childSex ?? this.childSex,
      eiNumber: eiNumber ?? this.eiNumber,
      interventionistName: interventionistName ?? this.interventionistName,
      credentials: credentials ?? this.credentials,
      npi: npi ?? this.npi,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseState: licenseState ?? this.licenseState,
      serviceType: serviceType ?? this.serviceType,
      sessionDate: sessionDate ?? this.sessionDate,
      ifspServiceLocation:
          ifspServiceLocation ?? this.ifspServiceLocation,
      timeFrom: timeFrom ?? this.timeFrom,
      timeFromAmPm: timeFromAmPm ?? this.timeFromAmPm,
      timeTo: timeTo ?? this.timeTo,
      timeToAmPm: timeToAmPm ?? this.timeToAmPm,
      intensity: intensity ?? this.intensity,
      sessionDelivered: sessionDelivered ?? this.sessionDelivered,
      dateNoteWritten: dateNoteWritten ?? this.dateNoteWritten,
      icd10Code: icd10Code ?? this.icd10Code,
      hcpcsCode: hcpcsCode ?? this.hcpcsCode,
      cptCode1: cptCode1 ?? this.cptCode1,
      cptCode2: cptCode2 ?? this.cptCode2,
      cptCode3: cptCode3 ?? this.cptCode3,
      cptCode4: cptCode4 ?? this.cptCode4,
      sessionCancelled: sessionCancelled ?? this.sessionCancelled,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      makeupByDate: makeupByDate ?? this.makeupByDate,
      isMakeup: isMakeup ?? this.isMakeup,
      makeupForDate: makeupForDate ?? this.makeupForDate,
      participantChild: participantChild ?? this.participantChild,
      participantParent: participantParent ?? this.participantParent,
      participantOther: participantOther ?? this.participantOther,
      q1IfspOutcomes: q1IfspOutcomes ?? this.q1IfspOutcomes,
      q2SessionDescription:
          q2SessionDescription ?? this.q2SessionDescription,
      q3ObservedRoutines: q3ObservedRoutines ?? this.q3ObservedRoutines,
      q3ParentTriedActivity:
          q3ParentTriedActivity ?? this.q3ParentTriedActivity,
      q3DemonstratedActivity:
          q3DemonstratedActivity ?? this.q3DemonstratedActivity,
      q3ReviewedCommTool: q3ReviewedCommTool ?? this.q3ReviewedCommTool,
      q3Other: q3Other ?? this.q3Other,
      q4HomeStrategies: q4HomeStrategies ?? this.q4HomeStrategies,
      parentSignature: parentSignature ?? this.parentSignature,
      parentSignatureDate: parentSignatureDate ?? this.parentSignatureDate,
      parentRelationship: parentRelationship ?? this.parentRelationship,
      interventionistSignature:
          interventionistSignature ?? this.interventionistSignature,
      interventionistSignatureDate:
          interventionistSignatureDate ?? this.interventionistSignatureDate,
      interventionistSignatureLatitude: interventionistSignatureLatitude ??
          this.interventionistSignatureLatitude,
      interventionistSignatureLongitude: interventionistSignatureLongitude ??
          this.interventionistSignatureLongitude,
      interventionistSignatureLocationAt: interventionistSignatureLocationAt ??
          this.interventionistSignatureLocationAt,
      interventionistLicense:
          interventionistLicense ?? this.interventionistLicense,
      parentSignatureLatitude:
          parentSignatureLatitude ?? this.parentSignatureLatitude,
      parentSignatureLongitude:
          parentSignatureLongitude ?? this.parentSignatureLongitude,
      parentSignatureLocationAt:
          parentSignatureLocationAt ?? this.parentSignatureLocationAt,
      supervisorName: supervisorName ?? this.supervisorName,
      supervisorSignatureDate:
          supervisorSignatureDate ?? this.supervisorSignatureDate,
      supervisorLicense: supervisorLicense ?? this.supervisorLicense,
    );
  }

  factory EipSessionNoteModel.fromContext(Map<String, dynamic> ctx) {
    EipSessionNoteModel? existing;
    final raw = ctx['existingEipFormData'] as String?;
    if (raw != null && raw.isNotEmpty) {
      try {
        existing = EipSessionNoteModel.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
          sessionId: ctx['sessionId'] as String,
        );
      } catch (_) {}
    }

    final license = ctx['licenseNumber'] as String?;
    final npi = ctx['npi'] as String?;

    final base = EipSessionNoteModel(
      sessionId: ctx['sessionId'] as String,
      childName: ctx['childName'] as String? ?? '',
      childDob: ctx['childDob'] as String?,
      childSex: ctx['childSex'] as String?,
      eiNumber: ctx['eiNumber'] as String?,
      interventionistName: ctx['interventionistName'] as String? ?? '',
      credentials: ctx['credentials'] as String?,
      npi: npi,
      licenseNumber: license,
      licenseState: ctx['licenseState'] as String?,
      serviceType: ctx['serviceType'] as String?,
      sessionDate: ctx['sessionDate'] as String?,
      ifspServiceLocation: ctx['ifspServiceLocation'] as String?,
      timeFrom: _splitTime(ctx['timeFrom'] as String?)?.$1,
      timeFromAmPm: _splitTime(ctx['timeFrom'] as String?)?.$2 ?? 'AM',
      timeTo: _splitTime(ctx['timeTo'] as String?)?.$1,
      timeToAmPm: _splitTime(ctx['timeTo'] as String?)?.$2 ?? 'PM',
      sessionDelivered: ctx['sessionDelivered'] as String? ?? 'In-person',
      dateNoteWritten: DateTime.now().toIso8601String().slice(0, 10),
      icd10Code: ctx['icd10Code'] as String?,
      interventionistLicense: license,
    );

    if (existing != null) {
      return existing.withProfileCredentials(
        npi: base.npi,
        licenseNumber: base.licenseNumber,
        licenseState: base.licenseState,
      );
    }
    return base;
  }

  /// Fills NPI and license from therapist profile when not already on the form.
  EipSessionNoteModel withProfileCredentials({
    String? npi,
    String? licenseNumber,
    String? licenseState,
  }) {
    final profileNpi = npi?.trim();
    final profileLicense = licenseNumber?.trim();
    final profileState = licenseState?.trim();

    return copyWith(
      npi: _preferExisting(this.npi, profileNpi),
      licenseNumber: _preferExisting(this.licenseNumber, profileLicense),
      licenseState: _preferExisting(this.licenseState, profileState),
      interventionistLicense: _preferExisting(
        interventionistLicense,
        profileLicense,
      ),
    );
  }

  static String? _preferExisting(String? current, String? fromProfile) {
    if (current != null && current.trim().isNotEmpty) return current.trim();
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    return current;
  }

  factory EipSessionNoteModel.fromJson(
    Map<String, dynamic> json, {
    required String sessionId,
  }) {
    return EipSessionNoteModel(
      sessionId: sessionId,
      childName: json['childName'] as String? ?? '',
      childDob: json['childDob'] as String?,
      childSex: json['childSex'] as String?,
      eiNumber: json['eiNumber'] as String?,
      interventionistName: json['interventionistName'] as String? ?? '',
      credentials: json['credentials'] as String?,
      npi: json['npi'] as String?,
      licenseNumber: json['licenseNumber'] as String?,
      licenseState: json['licenseState'] as String?,
      serviceType: json['serviceType'] as String?,
      sessionDate: json['sessionDate'] as String?,
      ifspServiceLocation: json['ifspServiceLocation'] as String?,
      timeFrom: json['timeFrom'] as String?,
      timeFromAmPm: json['timeFromAmPm'] as String? ?? 'AM',
      timeTo: json['timeTo'] as String?,
      timeToAmPm: json['timeToAmPm'] as String? ?? 'PM',
      intensity: json['intensity'] as String? ?? 'Home/Community',
      sessionDelivered: json['sessionDelivered'] as String? ?? 'In-person',
      dateNoteWritten: json['dateNoteWritten'] as String?,
      icd10Code: json['icd10Code'] as String?,
      hcpcsCode: json['hcpcsCode'] as String?,
      cptCode1: json['cptCode1'] as String?,
      cptCode2: json['cptCode2'] as String?,
      cptCode3: json['cptCode3'] as String?,
      cptCode4: json['cptCode4'] as String?,
      sessionCancelled: json['sessionCancelled'] as bool? ?? false,
      cancellationReason: json['cancellationReason'] as String?,
      makeupByDate: json['makeupByDate'] as String?,
      isMakeup: json['isMakeup'] as bool? ?? false,
      makeupForDate: json['makeupForDate'] as String?,
      participantChild: json['participantChild'] as bool? ?? true,
      participantParent: json['participantParent'] as bool? ?? true,
      participantOther: json['participantOther'] as String?,
      q1IfspOutcomes: json['q1IfspOutcomes'] as String? ?? '',
      q2SessionDescription: json['q2SessionDescription'] as String? ?? '',
      q3ObservedRoutines: json['q3ObservedRoutines'] as bool? ?? false,
      q3ParentTriedActivity: json['q3ParentTriedActivity'] as bool? ?? false,
      q3DemonstratedActivity: json['q3DemonstratedActivity'] as bool? ?? false,
      q3ReviewedCommTool: json['q3ReviewedCommTool'] as bool? ?? false,
      q3Other: json['q3Other'] as String?,
      q4HomeStrategies: json['q4HomeStrategies'] as String? ?? '',
      parentSignature: json['parentSignature'] as String?,
      parentSignatureDate: json['parentSignatureDate'] as String?,
      parentRelationship: json['parentRelationship'] as String?,
      interventionistSignature: json['interventionistSignature'] as String?,
      interventionistSignatureDate: json['interventionistSignatureDate'] as String?,
      interventionistSignatureLatitude:
          (json['interventionistSignatureLatitude'] as num?)?.toDouble(),
      interventionistSignatureLongitude:
          (json['interventionistSignatureLongitude'] as num?)?.toDouble(),
      interventionistSignatureLocationAt:
          json['interventionistSignatureLocationAt'] as String?,
      interventionistLicense: json['interventionistLicense'] as String?,
      parentSignatureLatitude:
          (json['parentSignatureLatitude'] as num?)?.toDouble(),
      parentSignatureLongitude:
          (json['parentSignatureLongitude'] as num?)?.toDouble(),
      parentSignatureLocationAt: json['parentSignatureLocationAt'] as String?,
      supervisorName: json['supervisorName'] as String?,
      supervisorSignatureDate: json['supervisorSignatureDate'] as String?,
      supervisorLicense: json['supervisorLicense'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'childName': childName,
        'childDob': childDob,
        'childSex': childSex,
        'eiNumber': eiNumber,
        'interventionistName': interventionistName,
        'credentials': credentials,
        'npi': npi,
        'licenseNumber': licenseNumber,
        'licenseState': licenseState,
        'serviceType': serviceType,
        'sessionDate': sessionDate,
        'ifspServiceLocation': ifspServiceLocation,
        'timeFrom': timeFrom,
        'timeFromAmPm': timeFromAmPm,
        'timeTo': timeTo,
        'timeToAmPm': timeToAmPm,
        'intensity': intensity,
        'sessionDelivered': sessionDelivered,
        'dateNoteWritten': dateNoteWritten,
        'icd10Code': icd10Code,
        'hcpcsCode': hcpcsCode,
        'cptCode1': cptCode1,
        'cptCode2': cptCode2,
        'cptCode3': cptCode3,
        'cptCode4': cptCode4,
        'sessionCancelled': sessionCancelled,
        'cancellationReason': cancellationReason,
        'makeupByDate': makeupByDate,
        'isMakeup': isMakeup,
        'makeupForDate': makeupForDate,
        'participantChild': participantChild,
        'participantParent': participantParent,
        'participantOther': participantOther,
        'q1IfspOutcomes': q1IfspOutcomes,
        'q2SessionDescription': q2SessionDescription,
        'q3ObservedRoutines': q3ObservedRoutines,
        'q3ParentTriedActivity': q3ParentTriedActivity,
        'q3DemonstratedActivity': q3DemonstratedActivity,
        'q3ReviewedCommTool': q3ReviewedCommTool,
        'q3Other': q3Other,
        'q4HomeStrategies': q4HomeStrategies,
        'parentSignature': parentSignature,
        'parentSignatureDate': parentSignatureDate,
        'parentRelationship': parentRelationship,
        'interventionistSignature': interventionistSignature,
        'interventionistSignatureDate': interventionistSignatureDate,
        'interventionistSignatureLatitude': interventionistSignatureLatitude,
        'interventionistSignatureLongitude': interventionistSignatureLongitude,
        'interventionistSignatureLocationAt':
            interventionistSignatureLocationAt,
        'interventionistLicense': interventionistLicense,
        'parentSignatureLatitude': parentSignatureLatitude,
        'parentSignatureLongitude': parentSignatureLongitude,
        'parentSignatureLocationAt': parentSignatureLocationAt,
        'supervisorName': supervisorName,
        'supervisorSignatureDate': supervisorSignatureDate,
        'supervisorLicense': supervisorLicense,
      };

  String toSoapSubjective() => q2SessionDescription.trim();

  String toSoapObjective() {
    final parts = <String>[
      'IFSP Outcomes: ${q1IfspOutcomes.trim()}',
      'Location: ${ifspServiceLocation ?? ''}',
      'Delivery: $sessionDelivered',
      'Participants: ${_participantsLabel()}',
    ];
    if (sessionCancelled) {
      parts.add('Session cancelled: ${cancellationReason ?? ''}');
    }
    return parts.join('\n');
  }

  String toSoapAssessment() {
    final methods = <String>[
      if (q3ObservedRoutines) 'Observed parent/caregiver and child during routines',
      if (q3ParentTriedActivity) 'Parent/caregiver tried activity; feedback exchanged',
      if (q3DemonstratedActivity) 'Demonstrated activity to parent/caregiver',
      if (q3ReviewedCommTool) 'Reviewed communication tool with parent/caregiver',
      if (q3Other?.trim().isNotEmpty == true) 'Other: ${q3Other!.trim()}',
    ];
    return methods.isEmpty
        ? 'Parent/caregiver collaboration documented.'
        : methods.join('; ');
  }

  String toSoapPlan() => q4HomeStrategies.trim();

  String toProgressSummary() {
    final parts = <String>[
      if (q2SessionDescription.trim().isNotEmpty) q2SessionDescription.trim(),
      if (q4HomeStrategies.trim().isNotEmpty)
        'Home strategies: ${q4HomeStrategies.trim()}',
    ];
    return parts.isEmpty ? 'Session documented per NYC EIP standards.' : parts.join('\n\n');
  }

  String _participantsLabel() {
    final parts = <String>[
      if (participantChild) 'child',
      if (participantParent) 'parent/caregiver',
      if (participantOther?.trim().isNotEmpty == true) participantOther!.trim(),
    ];
    return parts.isEmpty ? 'none listed' : parts.join(', ');
  }

  static (String, String)? _splitTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final upper = value.toUpperCase();
    final isPm = upper.contains('PM');
    final isAm = upper.contains('AM');
    final cleaned = value
        .replaceAll(RegExp(r'\s*(AM|PM)\s*', caseSensitive: false), '')
        .trim();
    return (cleaned, isPm ? 'PM' : (isAm ? 'AM' : 'AM'));
  }
}

extension on String {
  String slice(int start, [int? end]) => substring(start, end);
}
