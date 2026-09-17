import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/services/api_config.dart';

void main() {
  test('A12 endpoint is separate from the InnerU API endpoint', () {
    expect(ApiConfig.baseUrl, isNot(ApiConfig.a12BaseUrl));
    expect(ApiConfig.a12BaseUrl, contains('/api/v1'));
  });
}
