// File generated for Firebase configuration
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDK5LlgzGjqHVWsWlSGj4EYD-_XMqMdA28',
    appId: '1:20678248004:web:f538eb3d1c9f22f6b15e11',
    messagingSenderId: '20678248004',
    projectId: 'augmented-3b845',
    storageBucket: 'augmented-3b845.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDK5LlgzGjqHVWsWlSGj4EYD-_XMqMdA28',
    appId: '1:20678248004:android:f538eb3d1c9f22f6b15e11',
    messagingSenderId: '20678248004',
    projectId: 'augmented-3b845',
    storageBucket: 'augmented-3b845.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDK5LlgzGjqHVWsWlSGj4EYD-_XMqMdA28',
    appId: '1:20678248004:ios:f538eb3d1c9f22f6b15e11',
    messagingSenderId: '20678248004',
    projectId: 'augmented-3b845',
    storageBucket: 'augmented-3b845.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDK5LlgzGjqHVWsWlSGj4EYD-_XMqMdA28',
    appId: '1:20678248004:ios:f538eb3d1c9f22f6b15e11',
    messagingSenderId: '20678248004',
    projectId: 'augmented-3b845',
    storageBucket: 'augmented-3b845.firebasestorage.app',
  );
}
