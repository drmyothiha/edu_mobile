import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/messaging_models.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../services/sse_notification_service.dart';
import '../../theme/app_theme.dart';
import '../../screens/chat_screen.dart';

class ParentConversationsScreen extends StatefulWidget {
  const ParentConversationsScreen({super.key});

  @override
  State<ParentConversationsScreen> createState() =>
      _ParentConversationsScreenState();
}

class _ParentConversationsScreenState extends State<ParentConversationsScreen> {
  List<ConversationModel> _conversations = [];
  bool _loading = true;
  String? _error;
  StreamSubscription<NotificationModel>? _sseSub;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    SseNotificationService.startListening();
    _sseSub = SseNotificationService.onNotification.listen((notif) {
      if (mounted && notif.type == 'message') {
        _loadConversations(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _sseSub?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      var convs = await ApiService.getConversations();

      // Also discover school teachers from classes so parent-teacher conversations
      // are available directly without tying to individual students.
      try {
        final classes = await ApiService.getSchoolClasses();
        final existingTeacherIds = convs.map((c) => c.teacherId).toSet();
        final teacherIdsToInit = <String>{};

        for (final cls in classes) {
          final tid = cls['teacher_id']?.toString() ?? '';
          if (tid.isNotEmpty && !existingTeacherIds.contains(tid)) {
            teacherIdsToInit.add(tid);
          }
        }

        for (final tid in teacherIdsToInit) {
          try {
            final created = await ApiService.getOrCreateConversation(
              teacherId: tid,
            );
            convs.add(created);
            existingTeacherIds.add(tid);
          } catch (_) {}
        }
      } catch (_) {}

      // Fallback if still empty: resolve teacher from enrolled children
      if (convs.isEmpty) {
        try {
          final children = await StorageService.getGuardianChildren();
          for (final child in children) {
            if (child.id.isNotEmpty) {
              try {
                final created = await ApiService.getOrCreateConversation(
                  studentId: child.id,
                );
                convs.add(created);
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      // Deduplicate by teacherId so each teacher is a single Parent-Teacher conversation
      final byTeacher = <String, ConversationModel>{};
      for (final c in convs) {
        final existing = byTeacher[c.teacherId];
        if (existing == null ||
            (c.latestMessageContent.isNotEmpty &&
                existing.latestMessageContent.isEmpty) ||
            c.latestMessageAt.isAfter(existing.latestMessageAt)) {
          byTeacher[c.teacherId] = c;
        }
      }

      final deduped = byTeacher.values.toList()
        ..sort((a, b) => b.latestMessageAt.compareTo(a.latestMessageAt));

      if (mounted) {
        setState(() {
          _conversations = deduped;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _openConversation(ConversationModel conv) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conv.id,
          teacherId: conv.teacherId,
          title: conv.teacherName,
          subtitle: 'Parent-Teacher Conversation',
        ),
      ),
    );
    _loadConversations(silent: true);
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _conversations.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 44,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadConversations,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadConversations(silent: false),
                  child: _conversations.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(32),
                          children: [
                            const SizedBox(height: 80),
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No teacher conversations yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pull down to refresh parent-teacher conversations.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _conversations.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final conv = _conversations[index];
                            final hasUnread = conv.unreadCount > 0;

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: hasUnread
                                      ? AppTheme.primary.withValues(alpha: 0.4)
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _openConversation(conv),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: AppTheme.primary
                                            .withValues(alpha: 0.1),
                                        child: Text(
                                          conv.teacherName.isNotEmpty
                                              ? conv.teacherName[0]
                                                  .toUpperCase()
                                              : 'T',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    conv.teacherName,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: AppTheme.textMain,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _formatTime(
                                                      conv.latestMessageAt),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              conv.latestMessagePreview
                                                      .isNotEmpty
                                                  ? conv.latestMessagePreview
                                                  : 'Tap to start parent-teacher conversation',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: hasUnread
                                                    ? AppTheme.textMain
                                                    : Colors.grey.shade600,
                                                fontWeight: hasUnread
                                                    ? FontWeight.w700
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (hasUnread)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${conv.unreadCount}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      else
                                        Icon(
                                          Icons.chevron_right,
                                          color: Colors.grey.shade400,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
