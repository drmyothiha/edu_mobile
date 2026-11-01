import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';
import 'api_service.dart';
import 'storage_service.dart';
import '../routes/app_router.dart';

/// Top-level background message handler for FCM.
/// Must be annotated with @pragma('vm:entry-point') so the Dart VM keeps it.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[FCM-Background] Received background message: ${message.messageId} | data: ${message.data}');
  } catch (e) {
    debugPrint('[FCM-Background] Error in background message handler: $e');
  }
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important school, system and chat notifications.',
    importance: Importance.high,
  );

  static bool _isInitialized = false;
  static StreamSubscription<String>? _tokenRefreshSub;
  static String? _currentDeviceToken;

  /// Initializes Firebase and FCM notification handlers
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize Firebase App
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 2. Register background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 3. Request permissions (Android 13+ and iOS)
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      // 4. Configure Local Notifications for foreground display on mobile
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
        const initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        const initializationSettingsDarwin = DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

        const initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
        );

        await _localNotifications.initialize(
          settings: initializationSettings,
          onDidReceiveNotificationResponse: (NotificationResponse response) {
            _onNotificationTapped(response.payload);
          },
        );

        // Create Android Notification Channel
        if (Platform.isAndroid) {
          await _localNotifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.createNotificationChannel(_channel);
        }

        // Set foreground presentation options for iOS
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // 5. Handle foreground FCM messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM-Foreground] Message received: ${message.notification?.title}');
        _showForegroundNotification(message);
      });

      // 6. Handle notification click when app is opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM] App opened from background via notification: ${message.data}');
        _handleNotificationRouting(message.data);
      });

      // 7. Handle notification click when app is launched from terminated state
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM] App launched from terminated state via notification: ${initialMessage.data}');
        _handleNotificationRouting(initialMessage.data);
      }

      _isInitialized = true;
      debugPrint('[FCM] FCM Service initialized successfully');
    } catch (e, stack) {
      debugPrint('[FCM] Initialization failed: $e\n$stack');
    }
  }

  static String? get currentDeviceToken => _currentDeviceToken;

  /// Displays a heads-up notification when a message arrives while app is in foreground
  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'New Notification';
    final body = notification?.body ?? message.data['body'] ?? message.data['message'] ?? '';

    if (!kIsWeb && Platform.isAndroid) {
      await _localNotifications.show(
        id: notification?.hashCode ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  /// Displays a local test push notification directly via the notification channel
  static Future<void> showTestNotification({
    String title = 'AugmentEd FCM Test',
    String body = 'Live push notification received on device! 🚀',
  }) async {
    if (!kIsWeb && Platform.isAndroid) {
      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: '{"type":"test"}',
      );
    }
  }

  /// Synchronizes FCM device token with the backend edu_server
  static Future<void> syncDeviceToken() async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        debugPrint('[FCM] No user session found, skipping token registration');
        return;
      }

      String platformName = 'android';
      if (kIsWeb) {
        platformName = 'web';
      } else if (Platform.isIOS) {
        platformName = 'ios';
      } else if (Platform.isMacOS) {
        platformName = 'macos';
      }

      // Listen for registered token stream
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onRegistered.listen((fcmToken) async {
        _currentDeviceToken = fcmToken;
        debugPrint('[FCM] Device token registered via stream: ${fcmToken.substring(0, 15)}...');
        try {
          await ApiService.registerDeviceToken(fcmToken, platform: platformName);
          debugPrint('[FCM] Device token registered successfully with backend: ${fcmToken.substring(0, 15)}...');
        } catch (e) {
          debugPrint('[FCM] Failed to send FCM token to backend: $e');
        }

        // Show test banner notification on physical device
        try {
          await showTestNotification(
            title: 'AugmentEd Push Notification',
            body: 'FCM Token: ${fcmToken.substring(0, 14)}... (Verified)',
          );
        } catch (e) {
          debugPrint('[FCM] Failed to display test notification: $e');
        }
      });

      // Trigger registration
      await _messaging.register();
    } catch (e) {
      debugPrint('[FCM] Error synchronizing device token: $e');
    }
  }

  /// Unregisters the device token from the backend and deletes from FCM
  static Future<void> unregisterToken() async {
    try {
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;

      final tokenToUnregister = _currentDeviceToken;
      if (tokenToUnregister != null && tokenToUnregister.isNotEmpty) {
        await ApiService.unregisterDeviceToken(tokenToUnregister);
        _currentDeviceToken = null;
        debugPrint('[FCM] Unregistered device token from server');
      }
      await _messaging.unregister();
      debugPrint('[FCM] Unregistered FCM device');
    } catch (e) {
      debugPrint('[FCM] Error unregistering token: $e');
    }
  }

  /// Navigates to appropriate screen based on notification payload data
  static void _handleNotificationRouting(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    final type = data['type']?.toString();
    final navigator = AppRouter.navigatorKey.currentState;
    if (navigator == null) return;

    if (type == 'chat' || type == 'message') {
      // Future routing extension for chat
    }
  }

  static void _onNotificationTapped(String? payload) {
    debugPrint('[FCM] Local notification tapped with payload: $payload');
  }
}
