import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../shared/models/child_medical_chart_model.dart';

import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/graphql_client.dart';
import '../../../core/utils/file_download.dart';
import '../models/eip_session_note_model.dart';

class PaymentResultModel {
  const PaymentResultModel({
    required this.id,
    required this.status,
    required this.amount,
    this.description,
  });

  final String id;
  final String status;
  final double amount;
  final String? description;

  bool get isPaid => status == 'SUCCEEDED';
}

class SessionPaymentResult {
  const SessionPaymentResult({
    required this.payment,
    required this.stripeConfigured,
  });

  final PaymentResultModel payment;
  final bool stripeConfigured;
}

class TherapistProfileModel {
  const TherapistProfileModel({
    required this.id,
    required this.isVerified,
    required this.displayName,
    required this.email,
    required this.rating,
    required this.ratingCount,
    this.bio,
    this.npi,
    this.licenseNumber,
    this.licenseState,
    this.yearsExperience,
    this.therapyTypes = const [],
  });

  final String id;
  final bool isVerified;
  final String displayName;
  final String email;
  final double rating;
  final int ratingCount;
  final String? bio;
  final String? npi;
  final String? licenseNumber;
  final String? licenseState;

  bool get hasRequiredCredentials =>
      (npi?.trim().isNotEmpty ?? false) &&
      (licenseNumber?.trim().isNotEmpty ?? false);
  final int? yearsExperience;
  final List<String> therapyTypes;
}

typedef TherapistCaseloadChartModel = ChildMedicalChartModel;

class TherapistDashboardModel {
  const TherapistDashboardModel({
    required this.pendingRequests,
    required this.appointmentsToday,
    required this.inProgressSessions,
    required this.pendingDocumentation,
    required this.unreadMessages,
    this.actionItems = const [],
  });

  final int pendingRequests;
  final int appointmentsToday;
  final int inProgressSessions;
  final int pendingDocumentation;
  final int unreadMessages;
  final List<Map<String, dynamic>> actionItems;
}

List<TherapistAppointmentModel> sortTherapistAppointments(
  List<TherapistAppointmentModel> list,
) {
  final active = list
      .where((a) => !['CANCELLED', 'NO_SHOW'].contains(a.status))
      .toList();
  final now = DateTime.now();
  final upcoming =
      active.where((a) => !a.scheduledStart.isBefore(now)).toList()
        ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
  final past =
      active.where((a) => a.scheduledStart.isBefore(now)).toList()
        ..sort((a, b) => b.scheduledStart.compareTo(a.scheduledStart));
  return [...upcoming, ...past];
}

class TherapistAppointmentModel {
  const TherapistAppointmentModel({
    required this.id,
    required this.status,
    required this.therapyType,
    required this.scheduledStart,
    required this.childName,
    required this.childId,
    this.locationType,
    this.childInsuranceType,
    this.requiresSelfPayCollection = false,
    this.hasArrived = false,
    this.canStartSession = false,
    this.sessionPaymentId,
    this.sessionPaymentStatus,
    this.sessionPaymentAmount,
    this.confirmationStatus = 'PENDING',
    this.parentConfirmedAt,
    this.therapistConfirmedAt,
    this.rescheduleRequestedBy,
    this.proposedScheduledStart,
    this.proposedScheduledEnd,
    this.rescheduleReason,
    this.parentUserId,
    this.parentName,
  });

  final String id;
  final String status;
  final String therapyType;
  final DateTime scheduledStart;
  final String childName;
  final String childId;
  final String? locationType;
  final String? childInsuranceType;
  final bool requiresSelfPayCollection;
  final bool hasArrived;
  final bool canStartSession;
  final String? sessionPaymentId;
  final String? sessionPaymentStatus;
  final double? sessionPaymentAmount;
  final String confirmationStatus;
  final DateTime? parentConfirmedAt;
  final DateTime? therapistConfirmedAt;
  final String? rescheduleRequestedBy;
  final DateTime? proposedScheduledStart;
  final DateTime? proposedScheduledEnd;
  final String? rescheduleReason;
  final String? parentUserId;
  final String? parentName;

  bool get isTelehealth => locationType == 'TELEHEALTH';

  bool get isSelfPay => requiresSelfPayCollection;

  bool get isSessionPaymentReceived => sessionPaymentStatus == 'SUCCEEDED';

  bool get parentConfirmed => parentConfirmedAt != null;

  bool get therapistConfirmed => therapistConfirmedAt != null;

  bool get needsTherapistConfirmation =>
      confirmationStatus != 'CONFIRMED' &&
      !therapistConfirmed &&
      confirmationStatus != 'CANCELLED' &&
      status != 'CANCELLED' &&
      status != 'COMPLETED';

  bool get isFullyConfirmed =>
      confirmationStatus == 'CONFIRMED' && parentConfirmed && therapistConfirmed;

  bool get isRescheduleRequested =>
      confirmationStatus == 'RESCHEDULE_REQUESTED';
}

class TherapistServiceLogModel {
  const TherapistServiceLogModel({
    required this.id,
    required this.childName,
    this.therapistSignatureName,
    this.therapistSignedAt,
    this.parentSignatureName,
    this.parentSignedAt,
    this.parentSignatureDate,
  });

  final String id;
  final String childName;
  final String? therapistSignatureName;
  final String? therapistSignedAt;
  final String? parentSignatureName;
  final String? parentSignedAt;
  final String? parentSignatureDate;
}

class TherapistSessionModel {
  const TherapistSessionModel({
    required this.id,
    required this.status,
    required this.childName,
    this.childId,
    this.soapNoteId,
    this.hasSoap = false,
    this.subjective,
    this.objective,
    this.assessment,
    this.plan,
    this.eipFormFullySigned = false,
    this.serviceLog,
  });

  final String id;
  final String status;
  final String childName;
  final String? childId;
  final String? soapNoteId;
  final bool hasSoap;
  final bool eipFormFullySigned;
  final String? subjective;
  final String? objective;
  final String? assessment;
  final String? plan;
  final TherapistServiceLogModel? serviceLog;

  bool get needsDocumentation =>
      status == 'IN_PROGRESS' || status == 'PENDING_DOCUMENTATION';

  bool get hasServiceLog => serviceLog != null;
}

class TherapistRepository {
  TherapistRepository(this._graphql, this._api);

  final GraphqlClient _graphql;
  final ApiClient _api;

  Future<TherapistDashboardModel> fetchDashboard() async {
    const query = r'''
      query TherapistDashboard {
        therapistDashboard {
          pendingRequests
          appointmentsToday
          inProgressSessions
          pendingDocumentation
          unreadMessages
          actionItems {
            id title subtitle actionType priority
            threadId appointmentId sessionId claimId
          }
        }
      }
    ''';
    final result = await _graphql.query(query);
    final d = result['data']?['therapistDashboard'] as Map<String, dynamic>?;
    if (d == null) {
      throw Exception('therapistDashboard unavailable');
    }
    return TherapistDashboardModel(
      pendingRequests: d['pendingRequests'] as int? ?? 0,
      appointmentsToday: d['appointmentsToday'] as int? ?? 0,
      inProgressSessions: d['inProgressSessions'] as int? ?? 0,
      pendingDocumentation: d['pendingDocumentation'] as int? ?? 0,
      unreadMessages: d['unreadMessages'] as int? ?? 0,
      actionItems: (d['actionItems'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>(),
    );
  }

  Future<List<TherapistCaseloadChartModel>> fetchCaseloadCharts() async {
    const query = r'''
      query {
        myTherapistCaseloadCharts {
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
        }
      }
    ''';
    final result = await _graphql.query(query);
    final list =
        result['data']?['myTherapistCaseloadCharts'] as List<dynamic>? ?? [];
    return list
        .map((e) => ChildMedicalChartModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TherapistProfileModel> fetchProfile() async {
    const query = r'''
      query {
        myTherapistProfile {
          id
          isVerified
          bio
          npi
          licenseNumber
          licenseState
          yearsExperience
          therapyTypes
          ratingAverage
          ratingCount
          user { firstName lastName email }
        }
      }
    ''';
    final result = await _graphql.query(query);
    final p = result['data']?['myTherapistProfile'] as Map<String, dynamic>;
    final user = p['user'] as Map<String, dynamic>;
    return TherapistProfileModel(
      id: p['id'] as String,
      isVerified: p['isVerified'] as bool? ?? false,
      displayName: '${user['firstName']} ${user['lastName']}',
      email: user['email'] as String,
      bio: p['bio'] as String?,
      npi: p['npi'] as String?,
      licenseNumber: p['licenseNumber'] as String?,
      licenseState: p['licenseState'] as String?,
      yearsExperience: p['yearsExperience'] as int?,
      therapyTypes:
          (p['therapyTypes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rating: (p['ratingAverage'] as num?)?.toDouble() ?? 0,
      ratingCount: p['ratingCount'] as int? ?? 0,
    );
  }

  Future<List<TherapistAppointmentModel>> fetchAppointments() async {
    const query = r'''
      query {
        myTherapistAppointments {
          id
          status
          therapyType
          scheduledStart
          locationType
          confirmationStatus
          parentConfirmedAt
          therapistConfirmedAt
          rescheduleRequestedBy
          proposedScheduledStart
          proposedScheduledEnd
          rescheduleReason
          childInsuranceType
          requiresSelfPayCollection
          hasArrived
          canStartSession
          sessionPaymentId
          sessionPaymentStatus
          sessionPaymentAmount
          parentUserId
          parentName
          child { id firstName lastName }
        }
      }
    ''';
    final result = await _graphql.query(query);
    final list =
        result['data']?['myTherapistAppointments'] as List<dynamic>? ?? [];
    return sortTherapistAppointments(list.map((e) {
      final child = e['child'] as Map<String, dynamic>;
      return TherapistAppointmentModel(
        id: e['id'] as String,
        status: e['status'] as String? ?? '',
        therapyType: e['therapyType'] as String? ?? '',
        scheduledStart: DateTime.parse(e['scheduledStart'] as String),
        childName: '${child['firstName']} ${child['lastName']}',
        childId: child['id'] as String,
        locationType: e['locationType'] as String?,
        childInsuranceType: e['childInsuranceType'] as String?,
        requiresSelfPayCollection:
            e['requiresSelfPayCollection'] as bool? ?? false,
        hasArrived: e['hasArrived'] as bool? ?? false,
        canStartSession: e['canStartSession'] as bool? ?? false,
        sessionPaymentId: e['sessionPaymentId'] as String?,
        sessionPaymentStatus: e['sessionPaymentStatus'] as String?,
        sessionPaymentAmount:
            (e['sessionPaymentAmount'] as num?)?.toDouble(),
        confirmationStatus: e['confirmationStatus'] as String? ?? 'PENDING',
        parentConfirmedAt: e['parentConfirmedAt'] != null
            ? DateTime.parse(e['parentConfirmedAt'] as String)
            : null,
        therapistConfirmedAt: e['therapistConfirmedAt'] != null
            ? DateTime.parse(e['therapistConfirmedAt'] as String)
            : null,
        rescheduleRequestedBy: e['rescheduleRequestedBy'] as String?,
        proposedScheduledStart: e['proposedScheduledStart'] != null
            ? DateTime.parse(e['proposedScheduledStart'] as String)
            : null,
        proposedScheduledEnd: e['proposedScheduledEnd'] != null
            ? DateTime.parse(e['proposedScheduledEnd'] as String)
            : null,
        rescheduleReason: e['rescheduleReason'] as String?,
        parentUserId: e['parentUserId'] as String?,
        parentName: e['parentName'] as String?,
      );
    }).toList());
  }

  Future<List<TherapistSessionModel>> fetchSessions() async {
    const query = r'''
      query {
        myTherapistSessions {
          id
          status
          child { id firstName lastName }
          soapNote {
            id subjective objective assessment plan eipFormFullySigned
          }
          serviceLog {
            id childName therapistSignatureName therapistSignedAt
            parentSignatureName parentSignatureDate parentSignedAt
          }
        }
      }
    ''';
    final result = await _graphql.query(query);
    final list = result['data']?['myTherapistSessions'] as List<dynamic>? ?? [];
    return list.map((e) {
      final child = e['child'] as Map<String, dynamic>;
      final soap = e['soapNote'] as Map<String, dynamic>?;
      final log = e['serviceLog'] as Map<String, dynamic>?;
      return TherapistSessionModel(
        id: e['id'] as String,
        status: e['status'] as String? ?? '',
        childName: '${child['firstName']} ${child['lastName']}',
        childId: child['id'] as String?,
        soapNoteId: soap?['id'] as String?,
        hasSoap: soap != null,
        subjective: soap?['subjective'] as String?,
        objective: soap?['objective'] as String?,
        assessment: soap?['assessment'] as String?,
        plan: soap?['plan'] as String?,
        eipFormFullySigned: soap?['eipFormFullySigned'] as bool? ?? false,
        serviceLog: log == null
            ? null
            : TherapistServiceLogModel(
                id: log['id'] as String,
                childName: log['childName'] as String? ?? '',
                therapistSignatureName:
                    log['therapistSignatureName'] as String?,
                therapistSignedAt: log['therapistSignedAt'] as String?,
                parentSignatureName: log['parentSignatureName'] as String?,
                parentSignedAt: log['parentSignedAt'] as String?,
                parentSignatureDate: log['parentSignatureDate'] as String?,
              ),
      );
    }).toList();
  }

  Future<String> downloadServiceLogPdf(String sessionId) async {
    final response = await _api.dio.get<List<int>>(
      '/service-logs/therapist/$sessionId/pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(response.data ?? []);
    return downloadBytes(bytes, 'service-log-$sessionId.pdf');
  }

  Future<void> updateProfile({
    String? bio,
    String? npi,
    String? licenseNumber,
    String? licenseState,
    int? yearsExperience,
  }) async {
    const mutation = r'''
      mutation Update($input: UpdateTherapistProfileInput!) {
        updateTherapistProfile(input: $input) { id }
      }
    ''';
    await _graphql.query(
      mutation,
      variables: {
        'input': {
          'bio': ?bio,
          'npi': ?npi,
          'licenseNumber': ?licenseNumber,
          'licenseState': ?licenseState,
          'yearsExperience': ?yearsExperience,
        },
      },
    );
  }

  Future<String> downloadAppointmentsIcal() async {
    final response = await _api.dio.get<List<int>>(
      '/therapist/appointments/ical',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(response.data ?? []);
    return downloadBytes(bytes, 'abaconnect-therapist.ics');
  }

  Future<void> confirmAppointment(String appointmentId) async {
    const mutation = r'''
      mutation Confirm($appointmentId: ID!) {
        confirmAppointment(appointmentId: $appointmentId) {
          id
          status
          confirmationStatus
        }
      }
    ''';
    await _graphql.query(mutation, variables: {'appointmentId': appointmentId});
  }

  Future<void> requestRescheduleAppointment({
    required String appointmentId,
    required DateTime proposedStart,
    required DateTime proposedEnd,
    String? reason,
  }) async {
    const mutation = r'''
      mutation Reschedule($input: RequestRescheduleAppointmentInput!) {
        requestRescheduleAppointment(input: $input) {
          id
          status
          confirmationStatus
        }
      }
    ''';
    await _graphql.query(
      mutation,
      variables: {
        'input': {
          'appointmentId': appointmentId,
          'proposedStart': proposedStart.toIso8601String(),
          'proposedEnd': proposedEnd.toIso8601String(),
          'reason': ?reason,
        },
      },
    );
  }

  Future<void> cancelAppointment(String appointmentId, {String? reason}) async {
    const mutation = r'''
      mutation Cancel($appointmentId: ID!, $reason: String) {
        cancelAppointmentAsTherapist(appointmentId: $appointmentId, reason: $reason) { id status }
      }
    ''';
    await _graphql.query(
      mutation,
      variables: {'appointmentId': appointmentId, 'reason': ?reason},
    );
  }

  Future<void> declineAppointment(
    String appointmentId, {
    String? reason,
  }) async {
    const mutation = r'''
      mutation Decline($appointmentId: ID!, $reason: String) {
        declineAppointment(appointmentId: $appointmentId, reason: $reason) { id status }
      }
    ''';
    await _graphql.query(
      mutation,
      variables: {'appointmentId': appointmentId, 'reason': ?reason},
    );
  }

  Future<void> completeSession(String sessionId) async {
    const mutation = r'''
      mutation Complete($sessionId: ID!) {
        completeSession(sessionId: $sessionId) { id status }
      }
    ''';
    await _graphql.query(mutation, variables: {'sessionId': sessionId});
  }

  Future<void> recordTherapistArrival(String appointmentId) async {
    const mutation = r'''
      mutation Arrival($appointmentId: ID!) {
        recordTherapistArrival(appointmentId: $appointmentId) { id status hasArrived }
      }
    ''';
    await _graphql.query(mutation, variables: {'appointmentId': appointmentId});
  }

  Future<SessionPaymentResult> requestSessionPayment(String appointmentId) async {
    const mutation = r'''
      mutation Charge($appointmentId: ID!) {
        requestSessionPayment(appointmentId: $appointmentId) {
          payment { id status amount description }
          stripeConfigured
        }
      }
    ''';
    final result = await _graphql.query(
      mutation,
      variables: {'appointmentId': appointmentId},
    );
    final row =
        result['data']?['requestSessionPayment'] as Map<String, dynamic>?;
    if (row == null) throw Exception('Payment request failed');
    final payment = row['payment'] as Map<String, dynamic>;
    return SessionPaymentResult(
      payment: PaymentResultModel(
        id: payment['id'] as String,
        status: payment['status'] as String? ?? 'PENDING',
        amount: (payment['amount'] as num?)?.toDouble() ?? 0,
        description: payment['description'] as String?,
      ),
      stripeConfigured: row['stripeConfigured'] as bool? ?? false,
    );
  }

  Future<String> startSession(String appointmentId) async {
    const mutation = r'''
      mutation Start($appointmentId: ID!) {
        startSession(appointmentId: $appointmentId) { id }
      }
    ''';
    final result = await _graphql.query(
      mutation,
      variables: {'appointmentId': appointmentId},
    );
    return result['data']?['startSession']?['id'] as String;
  }

  Future<bool> saveSoapNote({
    required String sessionId,
    String? subjective,
    String? objective,
    String? assessment,
    String? plan,
    String? eipFormData,
  }) async {
    const mutation = r'''
      mutation Save($input: SaveSoapNoteInput!) {
        saveSoapNote(input: $input) {
          id
          serviceLog { id childName therapistSignatureName }
        }
      }
    ''';
    final result = await _graphql.query(
      mutation,
      variables: {
        'input': {
          'sessionId': sessionId,
          'subjective': ?subjective,
          'objective': ?objective,
          'assessment': ?assessment,
          'plan': ?plan,
          'eipFormData': ?eipFormData,
        },
      },
    );
    final log = result['data']?['saveSoapNote']?['serviceLog'];
    return log is Map<String, dynamic> && log['id'] != null;
  }

  Future<Map<String, dynamic>> fetchSessionNoteFormContext(
    String sessionId,
  ) async {
    final result = await _graphql.query(
      r'''
      query Context($sessionId: ID!) {
        sessionNoteFormContext(sessionId: $sessionId) {
          sessionId childName childDob childSex eiNumber
          interventionistName credentials npi licenseNumber licenseState
          serviceType
          sessionDate ifspServiceLocation timeFrom timeTo
          sessionDelivered icd10Code existingEipFormData isFullySigned
        }
      }
    ''',
      variables: {'sessionId': sessionId},
    );
    final data = result['data']?['sessionNoteFormContext'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Could not load session note context');
    }
    return data;
  }

  Future<bool> saveEipSessionNote(EipSessionNoteModel form) async {
    return saveSoapNote(
      sessionId: form.sessionId,
      subjective: form.toSoapSubjective(),
      objective: form.toSoapObjective(),
      assessment: form.toSoapAssessment(),
      plan: form.toSoapPlan(),
      eipFormData: jsonEncode(form.toJson()),
    );
  }

  Future<ProviderOnboardingChecklistModel> fetchOnboardingChecklist() async {
    const query = r'''
      query {
        providerOnboardingChecklist {
          identityComplete licenseComplete npiComplete taxIdComplete
          backgroundCheckComplete hipaaTrainingComplete
          confidentialityAgreementComplete agencyApprovalComplete
          isActive phiAccessApproved onboardingStatus
        }
      }
    ''';
    final result = await _graphql.query(query);
    final data = result['data']?['providerOnboardingChecklist'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Could not load onboarding checklist');
    }
    return ProviderOnboardingChecklistModel.fromJson(data);
  }

  Future<void> attestHipaaTraining() async {
    await _graphql.query(r'mutation { attestHipaaTraining { onboardingStatus } }');
  }

  Future<void> attestConfidentialityAgreement() async {
    await _graphql.query(
      r'mutation { attestConfidentialityAgreement { onboardingStatus } }',
    );
  }

  Future<void> submitProviderOnboarding() async {
    await _graphql.query(
      r'mutation { submitProviderOnboarding { onboardingStatus } }',
    );
  }
}

class ProviderOnboardingChecklistModel {
  const ProviderOnboardingChecklistModel({
    required this.identityComplete,
    required this.licenseComplete,
    required this.npiComplete,
    required this.hipaaTrainingComplete,
    required this.confidentialityAgreementComplete,
    required this.agencyApprovalComplete,
    required this.phiAccessApproved,
    required this.onboardingStatus,
  });

  final bool identityComplete;
  final bool licenseComplete;
  final bool npiComplete;
  final bool hipaaTrainingComplete;
  final bool confidentialityAgreementComplete;
  final bool agencyApprovalComplete;
  final bool phiAccessApproved;
  final String onboardingStatus;

  factory ProviderOnboardingChecklistModel.fromJson(Map<String, dynamic> json) {
    return ProviderOnboardingChecklistModel(
      identityComplete: json['identityComplete'] as bool? ?? false,
      licenseComplete: json['licenseComplete'] as bool? ?? false,
      npiComplete: json['npiComplete'] as bool? ?? false,
      hipaaTrainingComplete: json['hipaaTrainingComplete'] as bool? ?? false,
      confidentialityAgreementComplete:
          json['confidentialityAgreementComplete'] as bool? ?? false,
      agencyApprovalComplete: json['agencyApprovalComplete'] as bool? ?? false,
      phiAccessApproved: json['phiAccessApproved'] as bool? ?? false,
      onboardingStatus: json['onboardingStatus'] as String? ?? 'PENDING',
    );
  }
}
