import 'package:flutter_test/flutter_test.dart';
import 'package:kosan/services/api_config.dart';

void main() {
  test('API base URL includes the Laravel API version prefix', () {
    expect(apiBaseUrl, endsWith('/api/v1'));
  });
}
