import '../../../core/network/graphql_client.dart';

class MessageThreadModel {
  const MessageThreadModel({
    required this.id,
    required this.otherParticipantName,
    required this.updatedAt,
    this.subject,
    this.lastMessageBody,
    this.lastMessageAt,
  });

  final String id;
  final String? subject;
  final String otherParticipantName;
  final String? lastMessageBody;
  final DateTime? lastMessageAt;
  final DateTime updatedAt;
}

class ParentContactModel {
  const ParentContactModel({
    required this.parentId,
    required this.displayName,
    this.childSummary,
  });

  final String parentId;
  final String displayName;
  final String? childSummary;
}

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.body,
    required this.sentAt,
    required this.senderName,
    required this.isMine,
  });

  final String id;
  final String body;
  final DateTime sentAt;
  final String senderName;
  final bool isMine;
}

class MessagingRepository {
  MessagingRepository(this._graphql);

  final GraphqlClient _graphql;

  static const _threadsQuery = r'''
    query MyThreads {
      myMessageThreads {
        id
        subject
        otherParticipantName
        lastMessageBody
        lastMessageAt
        updatedAt
      }
    }
  ''';

  static const _messagesQuery = r'''
    query ThreadMessages($threadId: ID!) {
      threadMessages(threadId: $threadId) {
        id
        body
        sentAt
        senderName
        isMine
      }
    }
  ''';

  static const _sendMutation = r'''
    mutation SendMessage($input: SendMessageInput!) {
      sendMessage(input: $input) {
        id
        body
        sentAt
        senderName
        isMine
      }
    }
  ''';

  static const _startConversationMutation = r'''
    mutation StartConversation($therapistId: ID!) {
      startTherapistConversation(therapistId: $therapistId) {
        id
        otherParticipantName
      }
    }
  ''';

  static const _parentContactsQuery = r'''
    query ParentContacts {
      myTherapistParentContacts {
        parentId
        displayName
        childSummary
      }
    }
  ''';

  static const _startParentConversationMutation = r'''
    mutation StartParentChat($parentId: ID!) {
      startParentConversation(parentId: $parentId) {
        id
        otherParticipantName
      }
    }
  ''';

  Future<List<MessageThreadModel>> fetchThreads() async {
    final result = await _graphql.query(_threadsQuery);
    final list = result['data']?['myMessageThreads'] as List<dynamic>? ?? [];
    return list.map(_mapThread).toList();
  }

  Future<List<ChatMessageModel>> fetchMessages(String threadId) async {
    final result = await _graphql.query(
      _messagesQuery,
      variables: {'threadId': threadId},
    );
    final list = result['data']?['threadMessages'] as List<dynamic>? ?? [];
    return list.map(_mapMessage).toList();
  }

  Future<ChatMessageModel> sendMessage({
    required String threadId,
    required String body,
  }) async {
    final result = await _graphql.query(
      _sendMutation,
      variables: {
        'input': {'threadId': threadId, 'body': body},
      },
    );
    final e = result['data']?['sendMessage'] as Map<String, dynamic>?;
    if (e == null) throw Exception('Send failed');
    return _mapMessage(e);
  }

  Future<List<ParentContactModel>> fetchParentContacts() async {
    final result = await _graphql.query(_parentContactsQuery);
    final list =
        result['data']?['myTherapistParentContacts'] as List<dynamic>? ?? [];
    return list
        .map(
          (e) => ParentContactModel(
            parentId: e['parentId'] as String,
            displayName: e['displayName'] as String? ?? 'Parent',
            childSummary: e['childSummary'] as String?,
          ),
        )
        .toList();
  }

  Future<String> startParentConversation(String parentId) async {
    final result = await _graphql.query(
      _startParentConversationMutation,
      variables: {'parentId': parentId},
    );
    final e = result['data']?['startParentConversation'] as Map<String, dynamic>?;
    if (e == null) throw Exception('Could not start conversation');
    return e['id'] as String;
  }

  Future<String> startTherapistConversation(String therapistId) async {
    final result = await _graphql.query(
      _startConversationMutation,
      variables: {'therapistId': therapistId},
    );
    final e = result['data']?['startTherapistConversation'] as Map<String, dynamic>?;
    if (e == null) throw Exception('Could not start conversation');
    return e['id'] as String;
  }

  MessageThreadModel _mapThread(dynamic e) {
    return MessageThreadModel(
      id: e['id'] as String,
      subject: e['subject'] as String?,
      otherParticipantName: e['otherParticipantName'] as String? ?? 'Chat',
      lastMessageBody: e['lastMessageBody'] as String?,
      lastMessageAt: DateTime.tryParse(e['lastMessageAt'] as String? ?? ''),
      updatedAt: DateTime.parse(e['updatedAt'] as String),
    );
  }

  ChatMessageModel _mapMessage(dynamic e) {
    return ChatMessageModel(
      id: e['id'] as String,
      body: e['body'] as String,
      sentAt: DateTime.parse(e['sentAt'] as String),
      senderName: e['senderName'] as String? ?? '',
      isMine: e['isMine'] as bool? ?? false,
    );
  }
}
