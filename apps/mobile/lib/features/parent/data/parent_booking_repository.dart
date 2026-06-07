import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/graphql_client.dart';
import '../../../core/utils/file_download.dart';

class ChildModel {
  const ChildModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
  });

  final String id;
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;

  String get displayName => '$firstName $lastName';
}

class TherapistModel {
  const TherapistModel({
    required this.id,
    required this.displayName,
    required this.rating,
    this.matchScore,
  });

  final String id;
  final String displayName;
  final double rating;
  final double? matchScore;
}

class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.rating,
    required this.therapistName,
    this.title,
    this.comment,
    this.createdAt,
  });

  final String id;
  final int rating;
  final String therapistName;
  final String? title;
  final String? comment;
  final DateTime? createdAt;
}

class ScreeningTemplateModel {
  const ScreeningTemplateModel({
    required this.id,
    required this.name,
    required this.therapyType,
    this.questionsJson,
  });

  final String id;
  final String name;
  final String therapyType;
  final String? questionsJson;
}

class ScreeningHistoryModel {
  const ScreeningHistoryModel({
    required this.id,
    required this.completedAt,
    required this.templateName,
    required this.childName,
    this.score,
    this.riskLevel,
  });

  final String id;
  final DateTime completedAt;
  final String templateName;
  final String childName;
  final double? score;
  final String? riskLevel;
}

class ParentProfileModel {
  const ParentProfileModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.addressLine1,
    this.city,
    this.state,
    this.zipCode,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.insuranceProvider,
    this.insuranceMemberId,
    this.insuranceGroupNumber,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? addressLine1;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? insuranceProvider;
  final String? insuranceMemberId;
  final String? insuranceGroupNumber;

  String get fullName => '$firstName $lastName';
}

class SessionHistoryModel {
  const SessionHistoryModel({
    required this.id,
    required this.status,
    required this.childName,
    required this.therapistName,
    required this.therapyType,
    this.completedAt,
    this.durationMinutes,
    this.progressNoteSummary,
    this.hasProgressNote = false,
    this.parentFeedback,
  });

  final String id;
  final String status;
  final String childName;
  final String therapistName;
  final String therapyType;
  final DateTime? completedAt;
  final int? durationMinutes;
  final String? progressNoteSummary;
  final bool hasProgressNote;
  final String? parentFeedback;

  String get statusLabel {
    switch (status) {
      case 'COMPLETED':
        return 'Completed';
      case 'IN_PROGRESS':
        return 'In progress';
      case 'PENDING_DOCUMENTATION':
        return 'Awaiting notes';
      default:
        return status;
    }
  }
}

class AppointmentModel {
  const AppointmentModel({
    required this.id,
    required this.status,
    required this.therapyType,
    required this.scheduledStart,
    required this.childName,
    required this.therapistName,
    this.locationType,
  });

  final String id;
  final String status;
  final String therapyType;
  final DateTime scheduledStart;
  final String childName;
  final String therapistName;
  final String? locationType;

  bool get isTelehealth => locationType == 'TELEHEALTH';
}

class ParentDashboardModel {
  const ParentDashboardModel({
    required this.childrenCount,
    required this.upcomingAppointments,
    required this.appointmentsToday,
    required this.pendingReviews,
    required this.openClaimsCount,
    this.lastSessionSummary,
    this.nextTelehealthAppointmentId,
    this.actionItems = const [],
    this.onboardingStepsCompleted = 4,
    this.onboardingStepsTotal = 4,
    this.onboardingComplete = true,
    this.hasChild = true,
    this.hasScreening = true,
    this.hasBookedTherapist = true,
  });

  final int childrenCount;
  final int upcomingAppointments;
  final int appointmentsToday;
  final int pendingReviews;
  final int openClaimsCount;
  final String? lastSessionSummary;
  final String? nextTelehealthAppointmentId;
  final List<Map<String, dynamic>> actionItems;
  final int onboardingStepsCompleted;
  final int onboardingStepsTotal;
  final bool onboardingComplete;
  final bool hasChild;
  final bool hasScreening;
  final bool hasBookedTherapist;
}

class ParentBookingRepository {
  ParentBookingRepository(this._graphql, this._api);

  final GraphqlClient _graphql;
  final ApiClient _api;

  static const _myChildrenQuery = r'''
    query MyChildren {
      myChildren {
        id
        firstName
        lastName
        dateOfBirth
      }
    }
  ''';

  static const _parentDashboardQuery = r'''
    query ParentDashboard {
      parentDashboard {
        childrenCount
        upcomingAppointments
        appointmentsToday
        pendingReviews
        openClaimsCount
        lastSessionSummary
        nextTelehealthAppointmentId
        onboardingStepsCompleted onboardingStepsTotal onboardingComplete
        hasChild hasScreening hasBookedTherapist
        actionItems {
          id title subtitle actionType priority
          threadId appointmentId sessionId claimId
        }
      }
    }
  ''';

  static const _myAppointmentsQuery = r'''
    query MyAppointments {
      myAppointments {
        id
        status
        therapyType
        scheduledStart
        locationType
        child { firstName lastName }
        therapist { user { firstName lastName } }
      }
    }
  ''';

  static const _recommendedTherapistsQuery = r'''
    query Recommended($therapyType: TherapyType) {
      recommendedTherapists(input: { therapyType: $therapyType }) {
        id
        ratingAverage
        matchScore
        user { firstName lastName }
      }
    }
  ''';

  static const _bookMutation = r'''
    mutation Book($input: BookAppointmentInput!) {
      bookAppointment(input: $input) {
        id
        status
        scheduledStart
      }
    }
  ''';

  static const _bookRecurringMutation = r'''
    mutation BookRecurring($input: BookRecurringAppointmentsInput!) {
      bookRecurringAppointments(input: $input) {
        id
        status
        scheduledStart
      }
    }
  ''';

  static const _pendingReviewQuery = r'''
    query PendingReview {
      pendingReviewTherapists {
        id
        ratingAverage
        user { firstName lastName }
      }
    }
  ''';

  Future<ParentProfileModel> fetchParentProfile() async {
    const query = r'''
      query {
        myParentProfile {
          id email firstName lastName
          addressLine1 city state zipCode
          emergencyContactName emergencyContactPhone
          insuranceProvider insuranceMemberId insuranceGroupNumber
        }
      }
    ''';
    final result = await _graphql.query(query);
    final e = result['data']?['myParentProfile'] as Map<String, dynamic>?;
    if (e == null) throw Exception('Profile not found');
    return ParentProfileModel(
      id: e['id'] as String,
      email: e['email'] as String,
      firstName: e['firstName'] as String,
      lastName: e['lastName'] as String,
      addressLine1: e['addressLine1'] as String?,
      city: e['city'] as String?,
      state: e['state'] as String?,
      zipCode: e['zipCode'] as String?,
      emergencyContactName: e['emergencyContactName'] as String?,
      emergencyContactPhone: e['emergencyContactPhone'] as String?,
      insuranceProvider: e['insuranceProvider'] as String?,
      insuranceMemberId: e['insuranceMemberId'] as String?,
      insuranceGroupNumber: e['insuranceGroupNumber'] as String?,
    );
  }

  Future<void> updateParentProfile({
    String? addressLine1,
    String? city,
    String? state,
    String? zipCode,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? insuranceProvider,
    String? insuranceMemberId,
    String? insuranceGroupNumber,
  }) async {
    await _graphql.query(
      r'''
      mutation Update($input: UpdateParentProfileInput!) {
        updateParentProfile(input: $input) { id }
      }
    ''',
      variables: {
        'input': {
          if (addressLine1 != null) 'addressLine1': addressLine1,
          if (city != null) 'city': city,
          if (state != null) 'state': state,
          if (zipCode != null) 'zipCode': zipCode,
          if (emergencyContactName != null) 'emergencyContactName': emergencyContactName,
          if (emergencyContactPhone != null) 'emergencyContactPhone': emergencyContactPhone,
          if (insuranceProvider != null) 'insuranceProvider': insuranceProvider,
          if (insuranceMemberId != null) 'insuranceMemberId': insuranceMemberId,
          if (insuranceGroupNumber != null) 'insuranceGroupNumber': insuranceGroupNumber,
        },
      },
    );
  }

  Future<List<SessionHistoryModel>> fetchSessionHistory() async {
    const query = r'''
      query {
        mySessionHistory {
          id status childName therapistName therapyType
          completedAt durationMinutes
          progressNoteSummary hasProgressNote parentFeedback
        }
      }
    ''';
    final result = await _graphql.query(query);
    final list = result['data']?['mySessionHistory'] as List<dynamic>? ?? [];
    return list.map((e) {
      return SessionHistoryModel(
        id: e['id'] as String,
        status: e['status'] as String? ?? '',
        childName: e['childName'] as String? ?? '',
        therapistName: e['therapistName'] as String? ?? '',
        therapyType: e['therapyType'] as String? ?? '',
        completedAt: DateTime.tryParse(e['completedAt'] as String? ?? ''),
        durationMinutes: e['durationMinutes'] as int?,
        progressNoteSummary: e['progressNoteSummary'] as String?,
        hasProgressNote: e['hasProgressNote'] as bool? ?? false,
        parentFeedback: e['parentFeedback'] as String?,
      );
    }).toList();
  }

  Future<List<ChildModel>> fetchChildren() async {
    final result = await _graphql.query(_myChildrenQuery);
    final list = result['data']?['myChildren'] as List<dynamic>? ?? [];
    return list.map(_mapChild).toList();
  }

  ChildModel _mapChild(dynamic e) {
    final dobRaw = e['dateOfBirth'] as String?;
    return ChildModel(
      id: e['id'] as String,
      firstName: e['firstName'] as String,
      lastName: e['lastName'] as String,
      dateOfBirth: dobRaw != null
          ? DateTime.parse(dobRaw)
          : DateTime(2018, 1, 1),
    );
  }

  Future<ParentDashboardModel> fetchDashboard() async {
    final result = await _graphql.query(_parentDashboardQuery);
    final d = result['data']?['parentDashboard'] as Map<String, dynamic>?;
    if (d == null) {
      throw Exception('parentDashboard unavailable');
    }
    return ParentDashboardModel(
      childrenCount: d['childrenCount'] as int? ?? 0,
      upcomingAppointments: d['upcomingAppointments'] as int? ?? 0,
      appointmentsToday: d['appointmentsToday'] as int? ?? 0,
      pendingReviews: d['pendingReviews'] as int? ?? 0,
      openClaimsCount: d['openClaimsCount'] as int? ?? 0,
      lastSessionSummary: d['lastSessionSummary'] as String?,
      nextTelehealthAppointmentId:
          d['nextTelehealthAppointmentId'] as String?,
      onboardingStepsCompleted:
          d['onboardingStepsCompleted'] as int? ?? 0,
      onboardingStepsTotal: d['onboardingStepsTotal'] as int? ?? 4,
      onboardingComplete: d['onboardingComplete'] as bool? ?? false,
      hasChild: d['hasChild'] as bool? ?? false,
      hasScreening: d['hasScreening'] as bool? ?? false,
      hasBookedTherapist: d['hasBookedTherapist'] as bool? ?? false,
      actionItems: (d['actionItems'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>(),
    );
  }

  Future<List<AppointmentModel>> fetchAppointments() async {
    final result = await _graphql.query(_myAppointmentsQuery);
    final list = result['data']?['myAppointments'] as List<dynamic>? ?? [];
    return list.map(_mapAppointment).toList();
  }

  Future<List<TherapistModel>> fetchTherapists({String? therapyType}) async {
    final result = await _graphql.query(
      _recommendedTherapistsQuery,
      variables: therapyType != null ? {'therapyType': therapyType} : null,
    );
    final list =
        result['data']?['recommendedTherapists'] as List<dynamic>? ?? [];
    return list.map((e) {
      final user = e['user'] as Map<String, dynamic>?;
      final name = user != null
          ? '${user['firstName']} ${user['lastName']}'
          : 'Therapist';
      return TherapistModel(
        id: e['id'] as String,
        displayName: name,
        rating: (e['ratingAverage'] as num?)?.toDouble() ?? 0,
        matchScore: (e['matchScore'] as num?)?.toDouble(),
      );
    }).toList();
  }

  static const _addChildMutation = r'''
    mutation AddChild($input: AddChildInput!) {
      addChild(input: $input) {
        id
        firstName
        lastName
      }
    }
  ''';

  static const _myReviewsQuery = r'''
    query MyReviews {
      myReviews {
        id
        rating
        title
        comment
        createdAt
        therapistUser { firstName lastName }
      }
    }
  ''';

  static const _submitReviewMutation = r'''
    mutation SubmitReview($input: SubmitReviewInput!) {
      submitReview(input: $input) {
        id
        rating
      }
    }
  ''';

  static const _screeningTemplatesQuery = r'''
    query ScreeningTemplates {
      screeningTemplates {
        id
        name
        therapyType
        version
        questionsJson
      }
    }
  ''';

  static const _submitScreeningMutation = r'''
    mutation SubmitScreening($input: SubmitScreeningInput!) {
      submitScreening(input: $input) {
        id
        completedAt
      }
    }
  ''';

  Future<ChildModel> addChild({
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    String? gender,
  }) async {
    final result = await _graphql.query(
      _addChildMutation,
      variables: {
        'input': {
          'firstName': firstName,
          'lastName': lastName,
          'dateOfBirth': _dateOnlyIso(dateOfBirth),
          if (gender != null) 'gender': gender,
        },
      },
    );
    final e = result['data']?['addChild'] as Map<String, dynamic>?;
    if (e == null) {
      throw Exception('Failed to add child');
    }
    return _mapChild(e);
  }

  Future<List<ReviewModel>> fetchReviews() async {
    final result = await _graphql.query(_myReviewsQuery);
    final list = result['data']?['myReviews'] as List<dynamic>? ?? [];
    return list.map((e) {
      final user = e['therapistUser'] as Map<String, dynamic>?;
      final name = user != null
          ? '${user['firstName']} ${user['lastName']}'
          : 'Therapist';
      return ReviewModel(
        id: e['id'] as String,
        rating: e['rating'] as int? ?? 0,
        title: e['title'] as String?,
        comment: e['comment'] as String?,
        therapistName: name,
        createdAt: DateTime.tryParse(e['createdAt'] as String? ?? ''),
      );
    }).toList();
  }

  Future<void> submitReview({
    required String therapistId,
    required int rating,
    String? title,
    String? comment,
  }) async {
    await _graphql.query(
      _submitReviewMutation,
      variables: {
        'input': {
          'therapistId': therapistId,
          'rating': rating,
          if (title != null) 'title': title,
          if (comment != null) 'comment': comment,
        },
      },
    );
  }

  Future<List<ScreeningHistoryModel>> fetchScreeningHistory() async {
    const query = r'''
      query {
        myScreeningHistory {
          id completedAt childName templateName score riskLevel
        }
      }
    ''';
    final result = await _graphql.query(query);
    final list = result['data']?['myScreeningHistory'] as List<dynamic>? ?? [];
    return list.map((e) {
      final completed = e['completedAt'] as String?;
      return ScreeningHistoryModel(
        id: e['id'] as String,
        completedAt: completed != null
            ? DateTime.parse(completed)
            : DateTime.now(),
        templateName: e['templateName'] as String? ?? 'Screening',
        childName: e['childName'] as String? ?? '',
        score: (e['score'] as num?)?.toDouble(),
        riskLevel: e['riskLevel'] as String?,
      );
    }).toList();
  }

  Future<List<ScreeningTemplateModel>> fetchScreeningTemplates() async {
    final result = await _graphql.query(_screeningTemplatesQuery);
    final list = result['data']?['screeningTemplates'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => ScreeningTemplateModel(
            id: e['id'] as String,
            name: e['name'] as String,
            therapyType: e['therapyType'] as String? ?? '',
            questionsJson: e['questionsJson'] as String?,
          ),
        )
        .toList();
  }

  Future<void> submitScreening({
    required String templateId,
    required String childId,
    required Map<String, dynamic> responses,
  }) async {
    await _graphql.query(
      _submitScreeningMutation,
      variables: {
        'input': {
          'templateId': templateId,
          'childId': childId,
          'responsesJson': jsonEncode(responses),
        },
      },
    );
  }

  Future<void> bookAppointment({
    required String childId,
    required String therapistId,
    required String therapyType,
    required DateTime start,
    required DateTime end,
    String? locationType,
  }) async {
    await _graphql.query(
      _bookMutation,
      variables: {
        'input': {
          'childId': childId,
          'therapistId': therapistId,
          'therapyType': therapyType,
          'scheduledStart': start.toIso8601String(),
          'scheduledEnd': end.toIso8601String(),
          if (locationType != null) 'locationType': locationType,
        },
      },
    );
  }

  Future<int> bookRecurringAppointments({
    required String childId,
    required String therapistId,
    required String therapyType,
    required DateTime start,
    required DateTime end,
    required int weeks,
    String? locationType,
  }) async {
    final result = await _graphql.query(
      _bookRecurringMutation,
      variables: {
        'input': {
          'childId': childId,
          'therapistId': therapistId,
          'therapyType': therapyType,
          'scheduledStart': start.toIso8601String(),
          'scheduledEnd': end.toIso8601String(),
          'weeks': weeks,
          if (locationType != null) 'locationType': locationType,
        },
      },
    );
    final list =
        result['data']?['bookRecurringAppointments'] as List<dynamic>? ?? [];
    return list.length;
  }

  static const _rescheduleMutation = r'''
    mutation Reschedule($input: RescheduleAppointmentInput!) {
      rescheduleAppointment(input: $input) {
        id
        status
        scheduledStart
      }
    }
  ''';

  Future<void> rescheduleAppointment({
    required String appointmentId,
    required DateTime start,
    required DateTime end,
  }) async {
    await _graphql.query(
      _rescheduleMutation,
      variables: {
        'input': {
          'appointmentId': appointmentId,
          'scheduledStart': start.toIso8601String(),
          'scheduledEnd': end.toIso8601String(),
        },
      },
    );
  }

  static const _cancelMutation = r'''
    mutation Cancel($id: ID!, $reason: String) {
      cancelAppointment(id: $id, reason: $reason) {
        id
        status
      }
    }
  ''';

  Future<void> cancelAppointment({
    required String appointmentId,
    String? reason,
  }) async {
    await _graphql.query(
      _cancelMutation,
      variables: {
        'id': appointmentId,
        if (reason != null) 'reason': reason,
      },
    );
  }

  Future<void> updateChild({
    required String childId,
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
  }) async {
    await _graphql.query(
      r'''
      mutation UpdateChild($input: UpdateChildInput!) {
        updateChild(input: $input) { id dateOfBirth }
      }
    ''',
      variables: {
        'input': {
          'childId': childId,
          if (firstName != null) 'firstName': firstName,
          if (lastName != null) 'lastName': lastName,
          if (dateOfBirth != null)
            'dateOfBirth': _dateOnlyIso(dateOfBirth),
        },
      },
    );
  }

  static String _dateOnlyIso(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.toIso8601String().split('T').first;
  }

  Future<String> downloadAppointmentsIcal() async {
    final response = await _api.dio.get<List<int>>(
      '/parent/appointments/ical',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(response.data ?? []);
    const filename = 'abaconnect-appointments.ics';
    return downloadBytes(bytes, filename);
  }

  Future<List<TherapistModel>> fetchPendingReviewTherapists() async {
    final result = await _graphql.query(_pendingReviewQuery);
    final list =
        result['data']?['pendingReviewTherapists'] as List<dynamic>? ?? [];
    return list.map((e) {
      final user = e['user'] as Map<String, dynamic>?;
      final name = user != null
          ? '${user['firstName']} ${user['lastName']}'
          : 'Therapist';
      return TherapistModel(
        id: e['id'] as String,
        displayName: name,
        rating: (e['ratingAverage'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  AppointmentModel _mapAppointment(dynamic e) {
    final child = e['child'] as Map<String, dynamic>?;
    final therapist = e['therapist'] as Map<String, dynamic>?;
    final user = therapist?['user'] as Map<String, dynamic>?;
    return AppointmentModel(
      id: e['id'] as String,
      status: e['status'] as String? ?? '',
      therapyType: e['therapyType'] as String? ?? '',
      scheduledStart: DateTime.parse(e['scheduledStart'] as String),
      childName: child != null
          ? '${child['firstName']} ${child['lastName']}'
          : 'Child',
      therapistName: user != null
          ? '${user['firstName']} ${user['lastName']}'
          : 'Therapist',
      locationType: e['locationType'] as String?,
    );
  }
}
