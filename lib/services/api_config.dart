import 'package:flutter/foundation.dart';

/// Override per environment with --dart-define=API_BASE_URL=...
/// Web uses Laragon's virtual host; Android Emulator uses the host loopback alias.
const String _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

String get apiBaseUrl {
  if (_configuredApiBaseUrl.isNotEmpty) {
    return _configuredApiBaseUrl.replaceFirst(RegExp(r'/$'), '');
  }
  if (kIsWeb) return 'http://kosan_api.test/api/v1';
  return 'http://10.0.2.2:8000/api/v1';
}
