import 'dart:async';
import 'package:flutter/material.dart';
import '../models/messaging_models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/sse_notification_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final VoidCallback? onSwitchMode;

  const NotificationsScreen({super.key, this.onSwitchMode});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<NotificationModel> _notifications = [];
  List<AnnouncementModel> _announcements = [];
  bool _loading = true;
  String? _error;
  StreamSubscription<NotificationModel>? _sseSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _sseSub = SseNotificationService.onNotification.listen((newNotif) {
      if (mounted) {
        setState(() {
          _notifications.removeWhere((n) => n.id == newNotif.id);
          _notifications.insert(0, newNotif);
        });
      }
    });
    SseNotificationService.startListening();
  }

  @override
  void dispose() {
    _sseSub?.cancel();
    SseNotificationService.stopListening();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = await StorageService.getToken();
    if (token == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'AUTH_REQUIRED';
        });
      }
      return;
    }

    try {
      final notifs = await ApiService.getNotifications();
      final anns = await ApiService.getParentAnnouncements();
      if (mounted) {
        setState(() {
          _notifications = notifs;
          _announcements = anns;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadNotifs = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parent Communications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'သတိပေးချက်များနှင့် ဆရာများနှင့် စကားပြောဆိုမှု',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Notifications'),
                  if (unreadNotifs > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unreadNotifs',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Class Notices'),
                  if (_announcements.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_announcements.length}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _error == 'AUTH_REQUIRED' ? Icons.lock_outline : Icons.error_outline,
                          size: 48,
                          color: _error == 'AUTH_REQUIRED' ? AppTheme.primary : Colors.red.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error == 'AUTH_REQUIRED'
                              ? 'Please sign in to view parent communications and notifications.'
                              : _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        if (_error == 'AUTH_REQUIRED')
                          ElevatedButton.icon(
                            icon: const Icon(Icons.login),
                            label: const Text('Sign In'),
                            onPressed: () async {
                              final res = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              );
                              if (res == true) {
                                _loadData();
                              }
                            },
                          )
                        else
                          ElevatedButton(
                            onPressed: _loadData,
                            child: const Text('Try Again'),
                          ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNotificationsList(),
                    _buildAnnouncementsList(),
                  ],
                ),
    );
  }

  Widget _buildNotificationsList() {
    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No notifications right now',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Absence triggers and messages will appear here.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        separatorBuilder: (_, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final notif = _notifications[index];
          final isAbsence = notif.type == 'absence_alert';
          final isMessage = notif.type == 'message';

          return Card(
            elevation: notif.isRead ? 0 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isAbsence
                    ? Colors.red.shade300
                    : notif.isRead
                        ? Colors.grey.shade200
                        : AppTheme.primary.withValues(alpha: 0.3),
                width: isAbsence ? 1.5 : 1,
              ),
            ),
            color: isAbsence
                ? Colors.red.shade50
                : notif.isRead
                    ? Colors.white
                    : AppTheme.primary.withValues(alpha: 0.04),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                if (!notif.isRead) {
                  await ApiService.markNotificationRead(notif.id);
                  setState(() => notif.data['is_read'] = true);
                }
                if (isMessage && notif.data['conversation_id'] != null) {
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversationId: notif.data['conversation_id'],
                          title: notif.title,
                          subtitle: 'Parent-Teacher Conversation',
                        ),
                      ),
                    );
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isAbsence
                                ? Colors.red.shade100
                                : isMessage
                                    ? Colors.green.shade100
                                    : AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isAbsence
                                ? Icons.warning_amber_rounded
                                : isMessage
                                    ? Icons.chat_bubble
                                    : Icons.notifications,
                            color: isAbsence
                                ? Colors.red.shade700
                                : isMessage
                                    ? Colors.teal.shade800
                                    : AppTheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isAbsence)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade700,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'URGENT ABSENCE ALERT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              Text(
                                notif.title,
                                style: TextStyle(
                                  fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                                  fontSize: 13,
                                  color: isAbsence ? Colors.red.shade900 : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                MessageModel.formatPreview(notif.body),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isAbsence ? Colors.red.shade900 : Colors.grey.shade700,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isAbsence) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            icon: const Icon(Icons.chat, size: 14),
                            label: const Text('Message Teacher'),
                            onPressed: () {
                              final studentId = notif.data['student_id'] as String?;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    teacherId: notif.data['teacher_id'] as String?,
                                    studentId: studentId,
                                    title: 'Teacher Conversation',
                                    subtitle: 'Parent-Teacher Conversation',
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnnouncementsList() {
    if (_announcements.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No class notices yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'School broadcasts and teacher notices will show here.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _announcements.length,
        separatorBuilder: (_, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final ann = _announcements[index];
          final isUrgent = ann.priority == 'urgent';
          final isImportant = ann.priority == 'important';

          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isUrgent
                    ? Colors.red.shade300
                    : isImportant
                        ? Colors.amber.shade400
                        : Colors.grey.shade200,
              ),
            ),
            color: isUrgent
                ? Colors.red.shade50.withValues(alpha: 0.5)
                : isImportant
                    ? Colors.amber.shade50.withValues(alpha: 0.4)
                    : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isUrgent
                              ? Colors.red.shade700
                              : isImportant
                                  ? Colors.amber.shade700
                                  : Colors.grey.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ann.priority.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ann.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ann.content,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Class: ${ann.className}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Teacher: ${ann.teacherName}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
