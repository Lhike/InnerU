class ApiConfig {
  static const String _overrideBaseUrl =
      String.fromEnvironment('INNERU_API_BASE_URL');
  static const String _overrideA12BaseUrl =
      String.fromEnvironment('A12_API_BASE_URL');

  static String get baseUrl {
    if (_overrideBaseUrl.isNotEmpty) {
      return _overrideBaseUrl;
    }

    return 'https://inneru-api.valenin.com';
  }

  static String get a12BaseUrl {
    if (_overrideA12BaseUrl.isNotEmpty) {
      return _overrideA12BaseUrl;
    }

    return 'https://a14-api.valenin.com';
  }
}
