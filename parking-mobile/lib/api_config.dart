import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Docker `mobile_bas2` API суурь хаяг.
/// Override: `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:4000`
String apiBaseUrl() {
  const fromEnv = String.fromEnvironment('API_BASE_URL');
  if (fromEnv.isNotEmpty) return fromEnv.replaceAll(RegExp(r'/$'), '');
  if (kIsWeb) return 'http://127.0.0.1:4000';
  if (Platform.isAndroid) return 'http://10.0.2.2:4000';
  return 'http://127.0.0.1:4000';
}
