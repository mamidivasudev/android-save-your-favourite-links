/// Utility class for validating and normalizing URLs
/// Path: lib/utils/url_validator.dart
class UrlValidator {
  static bool isValid(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty && 
        uri.host.contains('.');
  }

  static String? normalize(String url) {
    String trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) return null;
    return trimmed;
  }

  static String validationError() {
    return 'Please enter a valid URL (e.g. https://example.com)';
  }
}

