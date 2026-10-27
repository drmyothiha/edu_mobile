import 'dart:async';
import 'package:flutter/services.dart';

class VoiceRecordingResult {
  final String base64Audio;
  final int durationSeconds;

  VoiceRecordingResult({
    required this.base64Audio,
    required this.durationSeconds,
  });

  String toMessagePayload() {
    return '[VOICE:$durationSeconds:$base64Audio]';
  }
}

class VoiceAudioService {
  static const MethodChannel _channel =
      MethodChannel('com.edu.platform.edu_mobile/voice_audio');

  static final StreamController<String> _completionController =
      StreamController<String>.broadcast();
  static bool _initialized = false;
  static DateTime? _fallbackStartTime;

  static Stream<String> get onPlaybackComplete {
    _ensureInitialized();
    return _completionController.stream;
  }

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPlaybackComplete') {
        final msgId = call.arguments?.toString() ?? '';
        _completionController.add(msgId);
      }
    });
  }

  static Future<bool> ensurePermission() async {
    _ensureInitialized();
    try {
      final res = await _channel.invokeMethod<bool>('ensurePermission');
      return res ?? true;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> startRecording() async {
    _ensureInitialized();
    _fallbackStartTime = DateTime.now();
    try {
      final res = await _channel.invokeMethod<bool>('startRecording');
      return res ?? false;
    } on MissingPluginException {
      // Fallback for non-Android / unit tests
      return true;
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<VoiceRecordingResult?> stopRecording() async {
    _ensureInitialized();
    final fallbackSec = _fallbackStartTime != null
        ? DateTime.now()
            .difference(_fallbackStartTime!)
            .inSeconds
            .clamp(1, 60)
        : 2;
    _fallbackStartTime = null;

    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('stopRecording');
      if (res != null) {
        final b64 = res['base64']?.toString() ?? '';
        final durationMs = (res['durationMs'] as num?)?.toInt() ?? 1000;
        final sec = (durationMs / 1000).round().clamp(1, 60);
        if (b64.isNotEmpty) {
          return VoiceRecordingResult(
            base64Audio: b64,
            durationSeconds: sec,
          );
        }
      }
      return null;
    } on MissingPluginException {
      return VoiceRecordingResult(
        base64Audio: 'SIMULATED_VOICE_AUDIO',
        durationSeconds: fallbackSec,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> cancelRecording() async {
    _ensureInitialized();
    _fallbackStartTime = null;
    try {
      await _channel.invokeMethod('cancelRecording');
    } catch (_) {}
  }

  static Future<bool> playAudio({
    required String messageId,
    required String base64Audio,
    required int durationSeconds,
  }) async {
    _ensureInitialized();
    if (base64Audio.isEmpty || base64Audio == 'SIMULATED_VOICE_AUDIO') {
      Future.delayed(Duration(seconds: durationSeconds.clamp(1, 5)), () {
        _completionController.add(messageId);
      });
      return true;
    }
    try {
      final ok = await _channel.invokeMethod<bool>('playAudio', {
        'id': messageId,
        'base64': base64Audio,
      });
      return ok ?? false;
    } on MissingPluginException {
      Future.delayed(Duration(seconds: durationSeconds.clamp(1, 5)), () {
        _completionController.add(messageId);
      });
      return true;
    } catch (_) {
      _completionController.add(messageId);
      return false;
    }
  }

  static Future<void> stopAudio() async {
    _ensureInitialized();
    try {
      await _channel.invokeMethod('stopAudio');
    } catch (_) {}
  }
}
