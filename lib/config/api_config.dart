import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Set ke URL Laravel utama (website) via:
  /// --dart-define=API_BASE_URL=http://192.168.x.x:8000
  static const String _envBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }

    // Default to the main Laravel website backend on this machine.
    if (kIsWeb) {
      return 'http://localhost:8000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      default:
        return 'http://127.0.0.1:8000';
    }
  }
}
