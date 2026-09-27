import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import '../models/messaging_models.dart';

class SseNotificationService {
  static http.Client? _client;
  static StreamSubscription? _subscription;
  static Timer? _reconnectTimer;
  static final StreamController<NotificationModel> _controller =
      StreamController<NotificationModel>.broadcast();

  static Stream<NotificationModel> get onNotification => _controller.stream;

  /// Starts listening to the Go backend SSE notification stream
  static Future<void> startListening() async {
    stopListening();

    final baseUrl = await StorageService.getServerUrl();
    final token = await StorageService.getToken();
    if (token == null) return;

    final uri = Uri.parse('$baseUrl/api/v1/notifications/stream?token=${Uri.encodeComponent(token)}');

    _client = http.Client();
    final request = http.Request('GET', uri)
      ..headers['Accept'] = 'text/event-stream';

    try {
      final response = await _client!.send(request);
      _subscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.startsWith('data: ')) {
          final dataStr = line.substring(6).trim();
          try {
            final jsonMap = json.decode(dataStr);
            if (jsonMap is Map<String, dynamic>) {
              _controller.add(NotificationModel.fromJson(jsonMap));
            }
          } catch (_) {}
        }
      }, onError: (err) {
        // Automatically attempt reconnection on network interruptions
        _scheduleReconnect();
      }, onDone: () {
        // Reconnect if server closes connection
        _scheduleReconnect();
      });
    } catch (_) {
      _scheduleReconnect();
    }
  }

  static void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () => startListening());
  }

  /// Cancels SSE subscription and closes client connection
  static void stopListening() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
  }
}
