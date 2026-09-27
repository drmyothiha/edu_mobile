class ConversationModel {
  final String id;
  final String? schoolId;
  final String teacherId;
  final String parentId;
  final String? studentId;
  final String teacherName;
  final String teacherEmail;
  final String parentName;
  final String parentEmail;
  final String studentName;
  final String latestMessageContent;
  final DateTime latestMessageAt;
  final int unreadCount;
  final DateTime createdAt;

  ConversationModel({
    required this.id,
    this.schoolId,
    required this.teacherId,
    required this.parentId,
    this.studentId,
    required this.teacherName,
    required this.teacherEmail,
    required this.parentName,
    required this.parentEmail,
    required this.studentName,
    required this.latestMessageContent,
    required this.latestMessageAt,
    required this.unreadCount,
    required this.createdAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String?,
      teacherId: json['teacher_id'] as String,
      parentId: json['parent_id'] as String,
      studentId: json['student_id'] as String?,
      teacherName: json['teacher_name'] as String? ?? 'Teacher',
      teacherEmail: json['teacher_email'] as String? ?? '',
      parentName: json['parent_name'] as String? ?? 'Parent',
      parentEmail: json['parent_email'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      latestMessageContent: json['latest_message_content'] as String? ?? '',
      latestMessageAt: DateTime.tryParse(json['latest_message_at'] as String? ?? '') ?? DateTime.now(),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String? ?? 'User',
      senderRole: json['sender_role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class AnnouncementModel {
  final String id;
  final String classId;
  final String teacherId;
  final String teacherName;
  final String className;
  final String? studentName;
  final String title;
  final String content;
  final String priority;
  final DateTime createdAt;

  AnnouncementModel({
    required this.id,
    required this.classId,
    required this.teacherId,
    required this.teacherName,
    required this.className,
    this.studentName,
    required this.title,
    required this.content,
    required this.priority,
    required this.createdAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] as String,
      classId: json['class_id'] as String,
      teacherId: json['teacher_id'] as String,
      teacherName: json['teacher_name'] as String? ?? 'Teacher',
      className: json['class_name'] as String? ?? 'Class',
      studentName: json['student_name'] as String?,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      priority: json['priority'] as String? ?? 'normal',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String? ?? 'general',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
