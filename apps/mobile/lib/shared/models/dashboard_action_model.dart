class DashboardActionModel {
  const DashboardActionModel({
    required this.id,
    required this.title,
    required this.actionType,
    this.subtitle,
    this.priority,
    this.threadId,
    this.appointmentId,
    this.sessionId,
    this.claimId,
    this.therapistId,
    this.marketplaceRequestId,
    this.paymentId,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String actionType;
  final int? priority;
  final String? threadId;
  final String? appointmentId;
  final String? sessionId;
  final String? claimId;
  final String? therapistId;
  final String? marketplaceRequestId;
  final String? paymentId;

  factory DashboardActionModel.fromJson(Map<String, dynamic> json) {
    return DashboardActionModel(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      actionType: json['actionType'] as String,
      priority: json['priority'] as int?,
      threadId: json['threadId'] as String?,
      appointmentId: json['appointmentId'] as String?,
      sessionId: json['sessionId'] as String?,
      claimId: json['claimId'] as String?,
      therapistId: json['therapistId'] as String?,
      marketplaceRequestId: json['marketplaceRequestId'] as String?,
      paymentId: json['paymentId'] as String?,
    );
  }
}

List<DashboardActionModel> parseActionItems(List<dynamic>? raw) {
  if (raw == null) return const [];
  return raw
      .map((e) => DashboardActionModel.fromJson(e as Map<String, dynamic>))
      .toList();
}
