class ApiConfig {
  static const String _overrideBaseUrl =
      String.fromEnvironment('INNERU_API_BASE_URL');

  static String get baseUrl {
    if (_overrideBaseUrl.isNotEmpty) {
      return _overrideBaseUrl;
    }

    return 'https://inneru-api.valenin.com';
  }

  static const String _a12OverrideBaseUrl =
      String.fromEnvironment('ABUNDANCE_A12_API_BASE_URL');

  static String get a12BaseUrl => _a12OverrideBaseUrl.isNotEmpty
      ? _a12OverrideBaseUrl
      : 'https://a14-api.valenin.com/api/v1';
}
