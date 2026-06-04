import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/graphql_client.dart';
import '../../../core/utils/file_download.dart';

class TelehealthSessionModel {
  const TelehealthSessionModel({
    required this.id,
    required this.roomId,
    this.joinUrl,
    this.appointmentLabel,
    this.vendor,
  });

  final String id;
  final String roomId;
  final String? joinUrl;
  final String? appointmentLabel;
  final String? vendor;
}

class DocumentItemModel {
  const DocumentItemModel({
    required this.id,
    required this.title,
    required this.fileName,
    required this.type,
    required this.fileSize,
  });

  final String id;
  final String title;
  final String fileName;
  final String type;
  final int fileSize;
}

class NotificationItemModel {
  const NotificationItemModel({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
  });

  final String id;
  final String title;
  final String body;
  final bool isRead;
}

class InsuranceClaimItemModel {
  const InsuranceClaimItemModel({
    required this.id,
    required this.payerName,
    required this.status,
    required this.billedAmount,
    this.childName,
  });

  final String id;
  final String payerName;
  final String status;
  final double billedAmount;
  final String? childName;
}

class ConsentItemModel {
  const ConsentItemModel({
    required this.id,
    required this.consentType,
    required this.version,
    required this.granted,
  });

  final String id;
  final String consentType;
  final String version;
  final bool granted;
}

class PlatformRepository {
  PlatformRepository(this._graphql, this._api);

  final GraphqlClient _graphql;
  final ApiClient _api;

  Future<List<TelehealthSessionModel>> fetchTelehealthSessions() async {
    final result = await _graphql.query(r'''
      query { myTelehealthSessions { id roomId joinUrl appointmentLabel vendor } }
    ''');
    final list = result['data']?['myTelehealthSessions'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => TelehealthSessionModel(
            id: e['id'] as String,
            roomId: e['roomId'] as String,
            joinUrl: e['joinUrl'] as String?,
            appointmentLabel: e['appointmentLabel'] as String?,
            vendor: e['vendor'] as String?,
          ),
        )
        .toList();
  }

  Future<TelehealthSessionModel> joinTelehealth(String appointmentId) async {
    final result = await _graphql.query(
      r'''
      mutation Join($id: ID!) {
        joinTelehealth(appointmentId: $id) { id roomId joinUrl vendor }
      }
    ''',
      variables: {'id': appointmentId},
    );
    final e = result['data']?['joinTelehealth'] as Map<String, dynamic>?;
    if (e == null) throw Exception('Join failed');
    return TelehealthSessionModel(
      id: e['id'] as String,
      roomId: e['roomId'] as String,
      joinUrl: e['joinUrl'] as String?,
      vendor: e['vendor'] as String?,
    );
  }

  Future<List<DocumentItemModel>> fetchDocuments() async {
    final result = await _graphql.query(r'''
      query { myDocuments { id title fileName type fileSize } }
    ''');
    final list = result['data']?['myDocuments'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => DocumentItemModel(
            id: e['id'] as String,
            title: e['title'] as String,
            fileName: e['fileName'] as String,
            type: e['type'] as String? ?? 'OTHER',
            fileSize: e['fileSize'] as int? ?? 0,
          ),
        )
        .toList();
  }

  Future<void> registerDocument({
    required String title,
    required String fileName,
    required String type,
  }) async {
    await _graphql.query(
      r'''
      mutation Reg($input: RegisterDocumentInput!) {
        registerDocument(input: $input) { id }
      }
    ''',
      variables: {
        'input': {
          'title': title,
          'fileName': fileName,
          'mimeType': 'application/pdf',
          'fileSize': 1024,
          'type': type,
        },
      },
    );
  }

  Future<void> uploadDocumentFile({
    required String title,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String type = 'OTHER',
    String? childId,
  }) async {
    final formData = FormData.fromMap({
      'title': title,
      'type': type,
      if (childId != null) 'childId': childId,
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    await _api.dio.post('/documents/upload', data: formData);
  }

  Future<void> deleteDocument(String documentId) async {
    await _graphql.query(
      r'''
      mutation Del($documentId: ID!) {
        deleteMyDocument(documentId: $documentId)
      }
    ''',
      variables: {'documentId': documentId},
    );
  }

  Future<String> downloadDocumentFile(String documentId, String fileName) async {
    final response = await _api.dio.get<List<int>>(
      '/documents/$documentId/file',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(response.data ?? []);
    return downloadBytes(bytes, fileName);
  }

  Future<int> fetchUnreadNotificationCount() async {
    final result = await _graphql.query(r'''
      query { myUnreadNotificationCount }
    ''');
    return result['data']?['myUnreadNotificationCount'] as int? ?? 0;
  }

  Future<List<NotificationItemModel>> fetchNotifications() async {
    final result = await _graphql.query(r'''
      query { myNotifications { id title body readAt } }
    ''');
    final list = result['data']?['myNotifications'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => NotificationItemModel(
            id: e['id'] as String,
            title: e['title'] as String,
            body: e['body'] as String,
            isRead: e['readAt'] != null,
          ),
        )
        .toList();
  }

  Future<int> markAllNotificationsRead() async {
    final result = await _graphql.query(r'''
      mutation { markAllNotificationsRead }
    ''');
    return result['data']?['markAllNotificationsRead'] as int? ?? 0;
  }

  Future<void> markNotificationRead(String id) async {
    await _graphql.query(
      r'''
      mutation Mark($id: ID!) { markNotificationRead(id: $id) { id } }
    ''',
      variables: {'id': id},
    );
  }

  Future<List<InsuranceClaimItemModel>> fetchClaims() async {
    final result = await _graphql.query(r'''
      query {
        myInsuranceClaims {
          id payerName status billedAmount childName
        }
      }
    ''');
    final list = result['data']?['myInsuranceClaims'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => InsuranceClaimItemModel(
            id: e['id'] as String,
            payerName: e['payerName'] as String,
            status: e['status'] as String? ?? '',
            billedAmount: (e['billedAmount'] as num?)?.toDouble() ?? 0,
            childName: e['childName'] as String?,
          ),
        )
        .toList();
  }

  Future<void> submitClaim({
    required String childId,
    required String payerName,
    required double amount,
  }) async {
    await _graphql.query(
      r'''
      mutation Claim($input: SubmitInsuranceClaimInput!) {
        submitInsuranceClaim(input: $input) { id }
      }
    ''',
      variables: {
        'input': {
          'childId': childId,
          'payerName': payerName,
          'billedAmount': amount,
          'serviceDate': DateTime.now().toIso8601String(),
        },
      },
    );
  }

  Future<List<ConsentItemModel>> fetchConsents() async {
    final result = await _graphql.query(r'''
      query { myConsents { id consentType version granted } }
    ''');
    final list = result['data']?['myConsents'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => ConsentItemModel(
            id: e['id'] as String,
            consentType: e['consentType'] as String,
            version: e['version'] as String,
            granted: e['granted'] as bool? ?? false,
          ),
        )
        .toList();
  }

  Future<void> grantConsent(String type, String version) async {
    await _graphql.query(
      r'''
      mutation Grant($input: GrantConsentInput!) {
        grantConsent(input: $input) { id }
      }
    ''',
      variables: {
        'input': {'consentType': type, 'version': version},
      },
    );
  }

  Future<void> recordEvv({
    required String sessionId,
    required double lat,
    required double lng,
    required String eventType,
  }) async {
    await _graphql.query(
      r'''
      mutation Evv($input: RecordEvvInput!) {
        recordEvvCheckIn(input: $input)
      }
    ''',
      variables: {
        'input': {
          'sessionId': sessionId,
          'latitude': lat,
          'longitude': lng,
          'eventType': eventType,
        },
      },
    );
  }

  Future<Map<String, String>> suggestSoap({String? childName}) async {
    final result = await _graphql.query(
      r'''
      query Suggest($input: SoapAssistInput) {
        suggestSoapNote(input: $input) {
          subjective objective assessment plan
        }
      }
    ''',
      variables: {
        if (childName != null) 'input': {'childName': childName},
      },
    );
    final e = result['data']?['suggestSoapNote'] as Map<String, dynamic>?;
    if (e == null) throw Exception('AI assist failed');
    return {
      'subjective': e['subjective'] as String? ?? '',
      'objective': e['objective'] as String? ?? '',
      'assessment': e['assessment'] as String? ?? '',
      'plan': e['plan'] as String? ?? '',
    };
  }

  Future<List<Map<String, dynamic>>> fetchTenantAnalytics() async {
    final result = await _graphql.query(r'''
      query { tenantAnalytics { metricKey metricValue } }
    ''');
    final list = result['data']?['tenantAnalytics'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => {
            'key': e['metricKey'] as String? ?? '',
            'value': (e['metricValue'] as num?)?.toDouble() ?? 0,
          },
        )
        .toList();
  }

  Future<void> fileComplaint({
    required String category,
    required String subject,
    required String description,
  }) async {
    await _graphql.query(
      r'''
      mutation File($input: FileComplaintInput!) {
        fileComplaint(input: $input) { id }
      }
    ''',
      variables: {
        'input': {
          'category': category,
          'subject': subject,
          'description': description,
        },
      },
    );
  }

  List<Map<String, dynamic>> parseQuestions(dynamic questions) {
    if (questions is List) {
      return questions.cast<Map<String, dynamic>>();
    }
    if (questions is String) {
      final decoded = jsonDecode(questions);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }
}
