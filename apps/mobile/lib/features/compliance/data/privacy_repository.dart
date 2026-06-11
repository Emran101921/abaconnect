import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/security/device_identity.dart';

class PrivacyNoticeSummaryModel {
  const PrivacyNoticeSummaryModel({
    required this.id,
    required this.versionNumber,
    required this.title,
    required this.effectiveDate,
    required this.shortAcknowledgmentText,
    required this.checkboxText,
  });

  final String id;
  final String versionNumber;
  final String title;
  final DateTime effectiveDate;
  final String shortAcknowledgmentText;
  final String checkboxText;

  factory PrivacyNoticeSummaryModel.fromJson(Map<String, dynamic> json) {
    return PrivacyNoticeSummaryModel(
      id: json['id'] as String,
      versionNumber: json['versionNumber'] as String,
      title: json['title'] as String,
      effectiveDate: DateTime.parse(json['effectiveDate'] as String),
      shortAcknowledgmentText: json['shortAcknowledgmentText'] as String,
      checkboxText: json['checkboxText'] as String,
    );
  }
}

class PrivacyDocumentModel {
  const PrivacyDocumentModel({
    required this.id,
    required this.versionNumber,
    required this.effectiveDate,
    required this.body,
    this.title,
  });

  final String id;
  final String versionNumber;
  final DateTime effectiveDate;
  final String body;
  final String? title;

  factory PrivacyDocumentModel.fromNoticeJson(Map<String, dynamic> json) {
    return PrivacyDocumentModel(
      id: json['id'] as String,
      versionNumber: json['versionNumber'] as String,
      title: json['title'] as String?,
      effectiveDate: DateTime.parse(json['effectiveDate'] as String),
      body: json['fullNoticeText'] as String,
    );
  }

  factory PrivacyDocumentModel.fromPolicyJson(Map<String, dynamic> json) {
    return PrivacyDocumentModel(
      id: json['id'] as String,
      versionNumber: json['versionNumber'] as String,
      effectiveDate: DateTime.parse(json['effectiveDate'] as String),
      body: json['privacyPolicyText'] as String,
    );
  }
}

class AcknowledgmentStatusModel {
  const AcknowledgmentStatusModel({
    required this.required,
    required this.acknowledged,
    this.activeVersion,
    this.acknowledgedAt,
  });

  final bool required;
  final bool acknowledged;
  final String? activeVersion;
  final DateTime? acknowledgedAt;

  factory AcknowledgmentStatusModel.fromJson(Map<String, dynamic> json) {
    return AcknowledgmentStatusModel(
      required: json['required'] as bool? ?? true,
      acknowledged: json['acknowledged'] as bool? ?? false,
      activeVersion: json['activeVersion'] as String?,
      acknowledgedAt: json['acknowledgedAt'] != null
          ? DateTime.parse(json['acknowledgedAt'] as String)
          : null,
    );
  }
}

class PrivacyRightsRequestModel {
  const PrivacyRightsRequestModel({
    required this.id,
    required this.requestType,
    required this.status,
    required this.submittedAt,
  });

  final String id;
  final String requestType;
  final String status;
  final DateTime submittedAt;

  factory PrivacyRightsRequestModel.fromJson(Map<String, dynamic> json) {
    return PrivacyRightsRequestModel(
      id: json['id'] as String,
      requestType: json['requestType'] as String,
      status: json['status'] as String,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
    );
  }
}

class HipaaAcknowledgmentRecordModel {
  const HipaaAcknowledgmentRecordModel({
    required this.id,
    required this.noticeVersion,
    required this.acknowledgedAt,
    this.ipAddress,
    this.platform,
    this.appVersion,
  });

  final String id;
  final String noticeVersion;
  final DateTime acknowledgedAt;
  final String? ipAddress;
  final String? platform;
  final String? appVersion;

  factory HipaaAcknowledgmentRecordModel.fromJson(Map<String, dynamic> json) {
    return HipaaAcknowledgmentRecordModel(
      id: json['id'] as String,
      noticeVersion: json['noticeVersion'] as String,
      acknowledgedAt: DateTime.parse(json['acknowledgedAt'] as String),
      ipAddress: json['ipAddress'] as String?,
      platform: json['platform'] as String?,
      appVersion: json['appVersion'] as String?,
    );
  }
}

class AdminAcknowledgmentModel {
  const AdminAcknowledgmentModel({
    required this.id,
    required this.noticeVersion,
    required this.acknowledgedAt,
    required this.userEmail,
    required this.userName,
  });

  final String id;
  final String noticeVersion;
  final DateTime acknowledgedAt;
  final String userEmail;
  final String userName;

  factory AdminAcknowledgmentModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    return AdminAcknowledgmentModel(
      id: json['id'] as String,
      noticeVersion: json['noticeVersion'] as String,
      acknowledgedAt: DateTime.parse(json['acknowledgedAt'] as String),
      userEmail: user['email'] as String? ?? '',
      userName:
          '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim(),
    );
  }
}

class PrivacyRepository {
  PrivacyRepository(this._api);

  final ApiClient _api;

  Future<PrivacyNoticeSummaryModel> fetchNoticeSummary() async {
    final res = await _api.get<Map<String, dynamic>>(
      '/compliance/me/privacy/notice/summary',
    );
    return PrivacyNoticeSummaryModel.fromJson(res.data!);
  }

  Future<PrivacyDocumentModel> fetchFullNotice() async {
    final res = await _api.get<Map<String, dynamic>>(
      '/compliance/me/privacy/notice/full',
    );
    return PrivacyDocumentModel.fromNoticeJson(res.data!);
  }

  Future<PrivacyDocumentModel> fetchPrivacyPolicy() async {
    final res = await _api.get<Map<String, dynamic>>(
      '/compliance/me/privacy/policy',
    );
    return PrivacyDocumentModel.fromPolicyJson(res.data!);
  }

  Future<AcknowledgmentStatusModel> fetchAcknowledgmentStatus() async {
    final res = await _api.get<Map<String, dynamic>>(
      '/compliance/me/privacy/acknowledgment-status',
    );
    return AcknowledgmentStatusModel.fromJson(res.data!);
  }

  Future<void> acknowledgeNotice() async {
    final device = await DeviceIdentity.resolve();
    String platform = device.platform;
    if (!kIsWeb) {
      if (Platform.isIOS) platform = 'iOS';
      if (Platform.isAndroid) platform = 'Android';
    } else {
      platform = 'Web';
    }
    await _api.post(
      '/compliance/me/privacy/acknowledge',
      data: {
        'appVersion': 'mobile',
        'platform': platform,
        'deviceId': device.deviceId,
      },
    );
  }

  Future<Map<String, dynamic>> downloadAcknowledgment() async {
    final res = await _api.get<Map<String, dynamic>>(
      '/compliance/me/privacy/acknowledgment/download',
    );
    return res.data ?? {};
  }

  Future<PrivacyRightsRequestModel> submitRightsRequest({
    required String requestType,
    required Map<String, dynamic> payload,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/compliance/me/privacy/rights-requests',
      data: {'requestType': requestType, 'payload': payload},
    );
    return PrivacyRightsRequestModel.fromJson(res.data!);
  }

  Future<List<PrivacyRightsRequestModel>> listRightsRequests() async {
    final res = await _api.get<List<dynamic>>(
      '/compliance/me/privacy/rights-requests',
    );
    return (res.data ?? [])
        .map((e) => PrivacyRightsRequestModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminAcknowledgmentModel>> adminListAcknowledgments({
    String? email,
  }) async {
    final res = await _api.get<List<dynamic>>(
      '/admin/compliance/acknowledgments',
      queryParameters: email != null && email.isNotEmpty
          ? {'email': email}
          : null,
    );
    return (res.data ?? [])
        .map(
          (e) => AdminAcknowledgmentModel.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> adminListNoticeVersions() async {
    final res = await _api.get<List<dynamic>>(
      '/admin/compliance/notice-versions',
    );
    return (res.data ?? []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> adminListPrivacyRequests() async {
    final res = await _api.get<List<dynamic>>(
      '/admin/compliance/privacy-requests',
    );
    return (res.data ?? []).cast<Map<String, dynamic>>();
  }

  Future<void> adminPublishNoticeVersion(String id) async {
    await _api.patch('/admin/compliance/notice-versions/$id/publish');
  }

  Future<void> adminUpdatePrivacyRequest(
    String id, {
    required String status,
    String? internalNotes,
  }) async {
    await _api.patch(
      '/admin/compliance/privacy-requests/$id',
      data: {
        'status': status,
        if (internalNotes != null) 'internalNotes': internalNotes,
      },
    );
  }

  Future<List<Map<String, dynamic>>> adminListAuditLogs() async {
    final res = await _api.get<List<dynamic>>(
      '/admin/compliance/audit-logs',
    );
    return (res.data ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> adminSecurityDashboard() async {
    final res = await _api.get<Map<String, dynamic>>(
      '/admin/security/dashboard',
    );
    return res.data ?? {};
  }

  Future<List<Map<String, dynamic>>> listPendingLegalDocuments() async {
    final res = await _api.get<List<dynamic>>(
      '/compliance/documents/me/pending',
    );
    return (res.data ?? []).cast<Map<String, dynamic>>();
  }

  Future<void> acceptLegalDocument(String documentId) async {
    await _api.post('/compliance/documents/$documentId/accept', data: {});
  }

  Future<void> adminDisableUser(String userId) async {
    await _api.post('/admin/security/users/$userId/disable');
  }

  Future<void> adminForcePasswordReset(String userId) async {
    await _api.post('/admin/security/users/$userId/force-password-reset');
  }

  Future<void> adminResetMfa(String userId) async {
    await _api.post('/admin/security/users/$userId/reset-mfa');
  }
}
