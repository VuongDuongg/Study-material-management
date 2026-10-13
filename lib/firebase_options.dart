import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Lớp cấu hình tùy chọn Firebase cho các nền tảng.
/// 
/// LƯU Ý: Sau khi tạo dự án trên Firebase Console và tải về file:
/// - android/app/google-services.json (Android)
/// - ios/Runner/GoogleService-Info.plist (iOS)
/// Bạn có thể chạy lệnh `flutterfire configure` để tự động cập nhật file này
/// với apiKey và appId chính xác của dự án bạn.
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
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSy-PLACEHOLDER-WEB-KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'studydoc-demo',
    authDomain: 'studydoc-demo.firebaseapp.com',
    storageBucket: 'studydoc-demo.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSy-PLACEHOLDER-ANDROID-KEY',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'studydoc-demo',
    storageBucket: 'studydoc-demo.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSy-PLACEHOLDER-IOS-KEY',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'studydoc-demo',
    storageBucket: 'studydoc-demo.appspot.com',
    iosBundleId: 'com.example.th1',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSy-PLACEHOLDER-WINDOWS-KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'studydoc-demo',
    storageBucket: 'studydoc-demo.appspot.com',
  );
}
