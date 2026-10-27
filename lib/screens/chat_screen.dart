import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/messaging_models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/sse_notification_service.dart';
import '../services/voice_audio_service.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final String? conversationId;
  final String? studentId;
  final String? teacherId;
  final String? parentId;
  final String title;
  final String subtitle;

  const ChatScreen({
    super.key,
    this.conversationId,
    this.studentId,
    this.teacherId,
    this.parentId,
    required this.title,
    required this.subtitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  ConversationModel? _conversation;
  List<MessageModel> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _currentUserId;
  String _baseUrl = StorageService.defaultServerUrl;

  // WeChat Voice Mode, Media Tray & Recording State
  bool _isVoiceMode = false;
  bool _showMediaPanel = false;
  bool _isRecording = false;
  bool _isCancellingRecord = false;
  int _recordingSeconds = 0;
  Timer? _recordTimer;
  String? _playingMessageId;
  int _waveTick = 0;
  Timer? _waveTimer;

  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollingTimer;
  StreamSubscription<NotificationModel>? _sseSub;
  StreamSubscription<String>? _playbackSub;

  // Embedded valid 64x64 colorful PNG (for instant sample photo sharing & web testing)
  static const String _samplePngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAACXBIWXMAAAsTAAALEwEAmpwY'
      'AAAAbUlEQVRo3u3PQRGAMAwEsU96/5XDBw4J0MxmZ2fV1d494JkBBoYBMzAwDJiBgWHADAwM'
      'A2ZgYBgwAwPDgBkYGAbMwMAwYAYGhgEzMDAMmIGBYcAMDAwDZmBgGDADA8OAGRgYBszAwDBg'
      'r7sB8TcD9c7q/tAAAAAASUVORK5CYII=';

  // Embedded compact MP4 header payload for sample video clips
  static const String _sampleMp4Base64 =
      'AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAAAIZnJlZQAAAu1tZGF0AAACrgYF'
      '//+q3EXpvebZSLeWLNgg2SPu73gyNjQgLSBjb3JlIDE2NCByMzEwOCAzMWUxOWY5IC0gSC4y';

  @override
  void initState() {
    super.initState();
    _initChat();
    _playbackSub = VoiceAudioService.onPlaybackComplete.listen((msgId) {
      if (mounted && _playingMessageId == msgId) {
        _stopWaveAnimation();
        setState(() {
          _playingMessageId = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _recordTimer?.cancel();
    _waveTimer?.cancel();
    _sseSub?.cancel();
    _playbackSub?.cancel();
    VoiceAudioService.stopAudio();
    if (_isRecording) {
      VoiceAudioService.cancelRecording();
    }
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    final user = await StorageService.getUser();
    final serverUrl = await StorageService.getServerUrl();
    if (mounted) {
      setState(() {
        _currentUserId = user?['id'] as String?;
        _baseUrl = serverUrl;
      });
    }

    await _loadConversation();

    // Real-time SSE listener for instant incoming message delivery (0 extra DB queries when payload is present)
    SseNotificationService.startListening();
    _sseSub = SseNotificationService.onNotification.listen((notif) {
      if (!mounted || _conversation == null) return;
      if (notif.type == 'message') {
        final convId = notif.data['conversation_id']?.toString();
        if (convId == null || convId == _conversation!.id) {
          final msgId = notif.data['message_id']?.toString();
          final content = notif.data['content']?.toString();
          if (msgId != null &&
              content != null &&
              !_messages.any((m) => m.id == msgId)) {
            final wasAtBottom = _isAtBottom();
            setState(() {
              _messages.add(
                MessageModel(
                  id: msgId,
                  conversationId: _conversation!.id,
                  senderId: notif.data['sender_id']?.toString() ?? '',
                  senderName: notif.data['sender_name']?.toString() ?? 'User',
                  senderRole: notif.data['sender_role']?.toString() ?? 'user',
                  content: content,
                  isRead: true,
                  createdAt: DateTime.tryParse(
                        notif.data['created_at']?.toString() ?? '',
                      ) ??
                      DateTime.now(),
                ),
              );
            });
            if (wasAtBottom) _scrollToBottom();
          } else {
            _syncNewMessagesDelta();
          }
        }
      }
    });

    // Lightweight 15s incremental delta sync fallback (fetches ONLY messages newer than last timestamp)
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_conversation != null && mounted) {
        _syncNewMessagesDelta();
      }
    });
  }

  Future<void> _loadConversation() async {
    setState(() => _loading = true);
    try {
      ConversationModel conv;
      if (widget.conversationId != null) {
        final convs = await ApiService.getConversations();
        conv = convs.firstWhere(
          (c) => c.id == widget.conversationId,
          orElse: () => throw Exception('Conversation not found'),
        );
      } else if (widget.teacherId != null) {
        final convs = await ApiService.getConversations();
        final existing =
            convs.where((c) => c.teacherId == widget.teacherId).toList();
        if (existing.isNotEmpty) {
          conv = existing.first;
        } else {
          conv = await ApiService.getOrCreateConversation(
            teacherId: widget.teacherId,
            parentId: widget.parentId,
          );
        }
      } else if (widget.parentId != null) {
        final convs = await ApiService.getConversations();
        final existing =
            convs.where((c) => c.parentId == widget.parentId).toList();
        if (existing.isNotEmpty) {
          conv = existing.first;
        } else {
          conv = await ApiService.getOrCreateConversation(
            parentId: widget.parentId,
            teacherId: widget.teacherId,
          );
        }
      } else {
        conv = await ApiService.getOrCreateConversation(
          studentId: widget.studentId,
          teacherId: widget.teacherId,
          parentId: widget.parentId,
        );
      }

      if (mounted) {
        setState(() {
          _conversation = conv;
        });
      }
      await _loadMessages(silent: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chat: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (_conversation == null) return;
    try {
      final msgs = await ApiService.getMessages(_conversation!.id, limit: 50);
      if (mounted) {
        final countChanged = msgs.length != _messages.length;
        final wasAtBottom = _isAtBottom();
        setState(() {
          _messages = msgs;
        });
        if (!silent || (countChanged && wasAtBottom)) {
          _scrollToBottom();
        }
      }
    } catch (_) {}
  }

  /// Incremental cursor delta sync: queries only messages created strictly after the latest loaded message.
  Future<void> _syncNewMessagesDelta() async {
    if (_conversation == null) return;
    if (_messages.isEmpty) {
      await _loadMessages(silent: true);
      return;
    }
    try {
      final lastTime = _messages.last.createdAt;
      final delta = await ApiService.getMessages(
        _conversation!.id,
        after: lastTime,
        limit: 50,
      );
      if (!mounted || delta.isEmpty) return;

      final existingIds = _messages.map((m) => m.id).toSet();
      final newItems =
          delta.where((m) => !existingIds.contains(m.id)).toList();
      if (newItems.isEmpty) return;

      final wasAtBottom = _isAtBottom();
      setState(() {
        _messages.addAll(newItems);
      });
      if (wasAtBottom) {
        _scrollToBottom();
      }
    } catch (_) {}
  }

  bool _isAtBottom() {
    if (!_scrollController.hasClients) return true;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    return (maxScroll - currentScroll) <= 100;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _conversation == null || _sending) return;

    await _sendRawContent(text, clearTextField: true);
  }

  Future<void> _sendRawContent(
    String content, {
    bool clearTextField = false,
  }) async {
    if (_conversation == null || _sending) return;

    setState(() => _sending = true);
    try {
      final sentMsg = await ApiService.sendMessage(_conversation!.id, content);
      if (clearTextField) {
        _textController.clear();
      }
      if (mounted) {
        setState(() {
          _messages.add(sentMsg);
          _showMediaPanel = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // =========================================================
  // WeChat-style Image & Video File Sending
  // =========================================================

  String _sanitizeFileName(String rawName, String fallback) {
    final clean = rawName.replaceAll(':', '_').replaceAll(']', '_').trim();
    return clean.isEmpty ? fallback : clean;
  }

  Future<void> _pickAndSendImageFile({
    ImageSource source = ImageSource.gallery,
  }) async {
    if (_conversation == null || _sending) return;
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 960,
        maxHeight: 960,
        imageQuality: 72,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final fileName = _sanitizeFileName(picked.name, 'photo.jpg');
      final ext = fileName.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      final mediaUrl = await ApiService.uploadChatMedia(
        bytes: bytes,
        filename: fileName,
        fallbackMimeType: 'image/$ext',
      );
      await _sendRawContent('[IMAGE:$fileName:$mediaUrl]');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image file: $e')),
        );
      }
    }
  }

  Future<void> _pickAndSendVideoFile({
    ImageSource source = ImageSource.gallery,
  }) async {
    if (_conversation == null || _sending) return;
    try {
      final picked = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 60),
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      // Cap embedded payload size if a very large raw video is selected
      final cappedBytes =
          bytes.length > 1500000 ? bytes.sublist(0, 1500000) : bytes;
      final fileName = _sanitizeFileName(picked.name, 'video_clip.mp4');
      final estSeconds = (bytes.length / 45000).round().clamp(3, 60);
      final mediaUrl = await ApiService.uploadChatMedia(
        bytes: Uint8List.fromList(cappedBytes),
        filename: fileName,
        fallbackMimeType: 'video/mp4',
      );
      await _sendRawContent('[VIDEO:$fileName:$estSeconds:$mediaUrl]');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick video file: $e')),
        );
      }
    }
  }

  Future<void> _sendSampleImageFile() async {
    if (_conversation == null || _sending) return;
    const fileName = 'classroom_report_photo.png';
    final mediaUrl = await ApiService.uploadChatMedia(
      bytes: base64Decode(_samplePngBase64),
      filename: fileName,
      fallbackMimeType: 'image/png',
    );
    await _sendRawContent('[IMAGE:$fileName:$mediaUrl]');
  }

  Future<void> _sendSampleVideoFile() async {
    if (_conversation == null || _sending) return;
    const fileName = 'classroom_activity_clip.mp4';
    final mediaUrl = await ApiService.uploadChatMedia(
      bytes: base64Decode(_sampleMp4Base64),
      filename: fileName,
      fallbackMimeType: 'video/mp4',
    );
    await _sendRawContent('[VIDEO:$fileName:12:$mediaUrl]');
  }

  // =========================================================
  // WeChat-style Hold-to-Talk Voice Recording & Playback
  // =========================================================

  Future<void> _startHoldRecording() async {
    if (_conversation == null || _sending || _isRecording) return;

    // Stop any playing audio first
    if (_playingMessageId != null) {
      await VoiceAudioService.stopAudio();
      _stopWaveAnimation();
      setState(() => _playingMessageId = null);
    }

    final started = await VoiceAudioService.startRecording();
    if (!started) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please allow Microphone permission and hold to talk again.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() {
      _isRecording = true;
      _isCancellingRecord = false;
      _recordingSeconds = 0;
    });

    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isRecording) {
        timer.cancel();
        return;
      }
      setState(() {
        _recordingSeconds++;
      });
      // Auto-send at 60s max like WeChat
      if (_recordingSeconds >= 60) {
        _finishHoldRecording();
      }
    });
  }

  void _updateHoldDrag(Offset localPosition) {
    if (!_isRecording) return;
    // If finger slides up above the button by > 55px, mark as cancel
    final shouldCancel = localPosition.dy < -55;
    if (shouldCancel != _isCancellingRecord) {
      setState(() {
        _isCancellingRecord = shouldCancel;
      });
    }
  }

  Future<void> _finishHoldRecording() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();

    final wasCancelling = _isCancellingRecord;
    setState(() {
      _isRecording = false;
      _isCancellingRecord = false;
    });

    if (wasCancelling) {
      await VoiceAudioService.cancelRecording();
      return;
    }

    final result = await VoiceAudioService.stopRecording();
    if (result == null || result.base64Audio.isEmpty) {
      return;
    }

    await _sendRawContent(result.toMessagePayload());
  }

  Future<void> _togglePlayVoiceMessage(MessageModel msg) async {
    if (_playingMessageId == msg.id) {
      await VoiceAudioService.stopAudio();
      _stopWaveAnimation();
      setState(() {
        _playingMessageId = null;
      });
      return;
    }

    await VoiceAudioService.stopAudio();
    _startWaveAnimation();
    setState(() {
      _playingMessageId = msg.id;
    });

    await VoiceAudioService.playAudio(
      messageId: msg.id,
      base64Audio: msg.voiceBase64,
      durationSeconds: msg.voiceDurationSeconds,
    );
  }

  void _startWaveAnimation() {
    _waveTimer?.cancel();
    _waveTick = 0;
    _waveTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted && _playingMessageId != null) {
        setState(() {
          _waveTick = (_waveTick + 1) % 3;
        });
      }
    });
  }

  void _stopWaveAnimation() {
    _waveTimer?.cancel();
    _waveTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED), // WeChat clean chat backdrop
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textMain,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMain,
              ),
            ),
            Text(
              widget.subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _loadMessages(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Message Area
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _messages.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.chat_bubble_outline,
                                        color: AppTheme.primary,
                                        size: 36,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Parent-Teacher Conversation',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Send text, voice, image, or video messages directly.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final msg = _messages[index];
                                final isMe = msg.senderId == _currentUserId;

                                return _buildMessageRow(msg, isMe);
                              },
                            ),
                ),

                // WeChat Input Bar (Voice / Keyboard + Media Toggle)
                _buildWeChatInputBar(),

                // WeChat Expandable '+' Media Tray (Image & Video File Send)
                if (_showMediaPanel) _buildWeChatMediaPanel(),
              ],
            ),

            // WeChat Center Recording HUD Overlay
            if (_isRecording) _buildRecordingOverlayHUD(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageRow(MessageModel msg, bool isMe) {
    final timeStr =
        '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';

    Widget bubbleWidget;
    if (msg.isVoiceMessage) {
      bubbleWidget = _buildWeChatVoiceBubble(msg, isMe);
    } else if (msg.isImageMessage) {
      bubbleWidget = _buildWeChatImageBubble(msg, isMe);
    } else if (msg.isVideoMessage) {
      bubbleWidget = _buildWeChatVideoBubble(msg, isMe);
    } else {
      bubbleWidget = Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? const Color(0xFF95EC69) // WeChat green bubble
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          msg.content,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 15,
            height: 1.35,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
              child: Text(
                msg.senderName.isNotEmpty
                    ? msg.senderName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3, left: 2),
                    child: Text(
                      msg.senderName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                bubbleWidget,
                const SizedBox(height: 3),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeChatVoiceBubble(MessageModel msg, bool isMe) {
    final duration = msg.voiceDurationSeconds.clamp(1, 60);
    final isPlaying = _playingMessageId == msg.id;
    // Scale width proportionally to duration like WeChat (min 84, max 210)
    final bubbleWidth = (84.0 + (duration * 5.0)).clamp(84.0, 210.0);

    final waveIcon = isPlaying
        ? (_waveTick == 0
            ? Icons.volume_mute_rounded
            : _waveTick == 1
                ? Icons.volume_down_rounded
                : Icons.volume_up_rounded)
        : Icons.volume_up_rounded;

    return Semantics(
      button: true,
      label: 'Voice Message $duration seconds',
      onTap: () => _togglePlayVoiceMessage(msg),
      child: GestureDetector(
        onTap: () => _togglePlayVoiceMessage(msg),
      child: Container(
        width: bubbleWidth,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF95EC69) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: isPlaying
              ? Border.all(color: AppTheme.primary, width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: isMe
              ? [
                  Text(
                    '$duration"',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Transform.flip(
                    flipX: true,
                    child: Icon(
                      waveIcon,
                      size: 20,
                      color: Colors.black87,
                    ),
                  ),
                ]
              : [
                  Icon(
                    waveIcon,
                    size: 20,
                    color: Colors.black87,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$duration"',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
        ),
      ),
    ),
    );
  }

  Uint8List? _decodeDataUriBytes(String src) {
    try {
      if (src.startsWith('data:')) {
        final commaIdx = src.indexOf(',');
        if (commaIdx != -1) {
          return base64Decode(src.substring(commaIdx + 1));
        }
      } else if (!src.startsWith('http://') &&
          !src.startsWith('https://') &&
          src.isNotEmpty) {
        return base64Decode(src);
      }
    } catch (_) {}
    return null;
  }

  Widget _buildImagePreviewWidget(String src, {BoxFit fit = BoxFit.cover}) {
    final resolved = src.startsWith('/api/') ? '$_baseUrl$src' : src;
    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return Image.network(
        resolved,
        fit: fit,
        errorBuilder: (_, _, _) => _buildImagePlaceholder(),
      );
    }
    final bytes = _decodeDataUriBytes(resolved);
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: fit,
        errorBuilder: (_, _, _) => _buildImagePlaceholder(),
      );
    }
    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: const Color(0xFFE0E7FF),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_rounded,
        size: 42,
        color: AppTheme.primary,
      ),
    );
  }

  Widget _buildWeChatImageBubble(MessageModel msg, bool isMe) {
    final fileName = msg.imageFileName;
    final src = msg.imageSource;

    return Semantics(
      button: true,
      label: 'Image File $fileName',
      onTap: () => _showImagePreviewDialog(msg),
      child: GestureDetector(
        onTap: () => _showImagePreviewDialog(msg),
      child: Container(
        width: 190,
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF95EC69) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: SizedBox(
                width: double.infinity,
                height: 130,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImagePreviewWidget(src),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.photo_rounded,
                              color: Colors.white,
                              size: 11,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'IMAGE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: Row(
                children: [
                  const Icon(
                    Icons.insert_photo_outlined,
                    size: 14,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildWeChatVideoBubble(MessageModel msg, bool isMe) {
    final fileName = msg.videoFileName;
    final duration = msg.videoDurationSeconds.clamp(1, 3600);
    final mins = (duration ~/ 60).toString();
    final secs = (duration % 60).toString().padLeft(2, '0');

    return Semantics(
      button: true,
      label: 'Video File $fileName',
      onTap: () => _showVideoPlayerDialog(msg),
      child: GestureDetector(
        onTap: () => _showVideoPlayerDialog(msg),
      child: Container(
        width: 205,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF95EC69) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Container(
                width: double.infinity,
                height: 125,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Subtle film icon backdrop
                    Icon(
                      Icons.movie_creation_outlined,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    // Center Play Button
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.8),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    // Top-left VIDEO badge
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF07C160),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.videocam_rounded,
                              color: Colors.white,
                              size: 11,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'VIDEO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Bottom-right Duration badge
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$mins:$secs',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: Row(
                children: [
                  const Icon(
                    Icons.video_file_outlined,
                    size: 14,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  void _showImagePreviewDialog(MessageModel msg) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.image_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      msg.imageFileName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
             SizedBox(
              height: 320,
              width: double.infinity,
              child: InteractiveViewer(
                child: _buildImagePreviewWidget(
                  msg.imageSource,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showVideoPlayerDialog(MessageModel msg) {
    showDialog(
      context: context,
      builder: (ctx) => _VideoPlayerModal(message: msg),
    );
  }

  Widget _buildWeChatInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          // WeChat Voice / Keyboard Mode Toggle Button
          IconButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              setState(() {
                _isVoiceMode = !_isVoiceMode;
                if (_isVoiceMode) {
                  _showMediaPanel = false;
                }
              });
              if (_isVoiceMode) {
                VoiceAudioService.ensurePermission();
              }
            },
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black54, width: 1.4),
              ),
              child: Icon(
                _isVoiceMode ? Icons.keyboard_alt_outlined : Icons.mic_none,
                size: 20,
                color: Colors.black87,
              ),
            ),
            tooltip: _isVoiceMode ? 'Switch to Keyboard' : 'Switch to Voice',
          ),
          const SizedBox(width: 2),

          // Center Input: Either "Hold to Talk" Button or Text Field
          Expanded(
            child: _isVoiceMode
                ? Semantics(
                    button: true,
                    label: 'Hold to Talk',
                    onTap: () async {
                      if (_isRecording) {
                        await _finishHoldRecording();
                      } else {
                        await _startHoldRecording();
                        await Future.delayed(
                          const Duration(milliseconds: 1200),
                        );
                        if (mounted && _isRecording) {
                          await _finishHoldRecording();
                        }
                      }
                    },
                    child: GestureDetector(
                      onPanDown: (_) => _startHoldRecording(),
                      onPanUpdate: (details) =>
                          _updateHoldDrag(details.localPosition),
                      onPanEnd: (_) => _finishHoldRecording(),
                      onPanCancel: () => _finishHoldRecording(),
                      child: Container(
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _isRecording
                              ? (_isCancellingRecord
                                  ? Colors.red.shade100
                                  : Colors.grey.shade300)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isRecording && _isCancellingRecord
                                ? Colors.red.shade400
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          _isRecording
                              ? (_isCancellingRecord
                                  ? 'Release to Cancel'
                                  : 'Release to Send')
                              : 'Hold to Talk',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _isRecording && _isCancellingRecord
                                ? Colors.red.shade700
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  )
                : TextField(
                    controller: _textController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _handleSendText(),
                  ),
          ),

          // WeChat '+' Media Attachment Toggle Button (Image & Video files)
          IconButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              setState(() {
                _showMediaPanel = !_showMediaPanel;
              });
            },
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _showMediaPanel
                    ? AppTheme.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                border: Border.all(
                  color: _showMediaPanel ? AppTheme.primary : Colors.black54,
                  width: 1.4,
                ),
              ),
              child: Icon(
                _showMediaPanel ? Icons.close_rounded : Icons.add,
                size: 20,
                color: _showMediaPanel ? AppTheme.primary : Colors.black87,
              ),
            ),
            tooltip: 'Attach Image or Video',
          ),

          if (!_isVoiceMode) ...[
            SizedBox(
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF07C160), // WeChat Green
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _sending ? null : _handleSendText,
                child: _sending
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Send',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeChatMediaPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMediaActionTile(
            icon: Icons.photo_library_rounded,
            label: 'Image File',
            color: const Color(0xFF2563EB),
            onTap: () => _pickAndSendImageFile(source: ImageSource.gallery),
          ),
          _buildMediaActionTile(
            icon: Icons.videocam_rounded,
            label: 'Video File',
            color: const Color(0xFF7C3AED),
            onTap: () => _pickAndSendVideoFile(source: ImageSource.gallery),
          ),
          _buildMediaActionTile(
            icon: Icons.add_photo_alternate_rounded,
            label: 'Sample Image',
            color: const Color(0xFF059669),
            onTap: _sendSampleImageFile,
          ),
          _buildMediaActionTile(
            icon: Icons.smart_display_rounded,
            label: 'Sample Video',
            color: const Color(0xFFEA580C),
            onTap: _sendSampleVideoFile,
          ),
        ],
      ),
    );
  }

  Widget _buildMediaActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      onTap: _sending ? null : onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _sending ? null : onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingOverlayHUD() {
    return Center(
      child: Container(
        width: 165,
        height: 165,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isCancellingRecord ? Icons.undo_rounded : Icons.mic_rounded,
              color: _isCancellingRecord
                  ? Colors.redAccent
                  : const Color(0xFF95EC69),
              size: 52,
            ),
            const SizedBox(height: 8),
            Text(
              '0:${_recordingSeconds.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isCancellingRecord
                    ? Colors.red.shade700
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _isCancellingRecord
                    ? 'Release to cancel'
                    : 'Slide up to cancel',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPlayerModal extends StatefulWidget {
  final MessageModel message;

  const _VideoPlayerModal({required this.message});

  @override
  State<_VideoPlayerModal> createState() => _VideoPlayerModalState();
}

class _VideoPlayerModalState extends State<_VideoPlayerModal> {
  bool _isPlaying = true;
  int _elapsedSeconds = 0;
  Timer? _timer;

  int get _totalSeconds => widget.message.videoDurationSeconds.clamp(1, 3600);

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isPlaying) return;
      setState(() {
        if (_elapsedSeconds < _totalSeconds) {
          _elapsedSeconds++;
        } else {
          _isPlaying = false;
          _elapsedSeconds = 0;
        }
      });
    });
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        _totalSeconds > 0 ? (_elapsedSeconds / _totalSeconds).clamp(0.0, 1.0) : 0.0;

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.videocam_rounded,
                  color: Color(0xFF95EC69),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.message.videoFileName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 210,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isPlaying
                            ? Icons.motion_photos_on_rounded
                            : Icons.pause_circle_outline_rounded,
                        color: const Color(0xFF95EC69),
                        size: 56,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isPlaying ? 'Playing Video...' : 'Video Paused',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF07C160)),
              minHeight: 5,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _togglePlay,
                  icon: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                  ),
                  label: Text(
                    _isPlaying ? 'Pause' : 'Play',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                Text(
                  '0:${_elapsedSeconds.toString().padLeft(2, '0')} / 0:${_totalSeconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
