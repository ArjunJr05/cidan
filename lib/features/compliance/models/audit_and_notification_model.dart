class AuditEvent {
  final String id;
  final String bankId;
  final String actorId;
  final String actorEmail;
  final String actorRole;
  final String action;
  final String resourceType;
  final String resourceId;
  final Map<String, dynamic>? previousState;
  final Map<String, dynamic>? newState;
  final String? ipAddress;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  const AuditEvent({
    required this.id,
    required this.bankId,
    required this.actorId,
    required this.actorEmail,
    required this.actorRole,
    required this.action,
    required this.resourceType,
    required this.resourceId,
    this.previousState,
    this.newState,
    this.ipAddress,
    this.metadata = const {},
    this.createdAt,
  });

  factory AuditEvent.fromJson(Map<String, dynamic> json) {
    return AuditEvent(
      id: json['id'] as String? ?? '',
      bankId: json['bank_id'] as String? ?? '',
      actorId: json['actor_id'] as String? ?? '',
      actorEmail: json['actor_email'] as String? ?? '',
      actorRole: json['actor_role'] as String? ?? 'AUDITOR',
      action: json['action'] as String? ?? '',
      resourceType: json['resource_type'] as String? ?? '',
      resourceId: json['resource_id'] as String? ?? '',
      previousState: json['previous_state'] as Map<String, dynamic>?,
      newState: json['new_state'] as Map<String, dynamic>?,
      ipAddress: json['ip_address'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}

class NotificationRecord {
  final String id;
  final String bankId;
  final String recipientEmail;
  final String eventType;
  final String title;
  final String message;
  final String? resourceId;
  final String deliveryChannel;
  final String status;
  bool isRead;
  final DateTime? createdAt;

  NotificationRecord({
    required this.id,
    required this.bankId,
    required this.recipientEmail,
    required this.eventType,
    required this.title,
    required this.message,
    this.resourceId,
    this.deliveryChannel = 'IN_APP',
    this.status = 'SENT',
    this.isRead = false,
    this.createdAt,
  });

  factory NotificationRecord.fromJson(Map<String, dynamic> json) {
    return NotificationRecord(
      id: json['id'] as String? ?? '',
      bankId: json['bank_id'] as String? ?? '',
      recipientEmail: json['recipient_email'] as String? ?? '',
      eventType: json['event_type'] as String? ?? 'GENERAL',
      title: json['title'] as String? ?? 'Notification',
      message: json['message'] as String? ?? '',
      resourceId: json['resource_id'] as String?,
      deliveryChannel: json['delivery_channel'] as String? ?? 'IN_APP',
      status: json['status'] as String? ?? 'SENT',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}
