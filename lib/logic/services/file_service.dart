import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class FileService {
  /// Mở file hoặc URL đa nền tảng (Web, Mobile, Desktop)
  static Future<bool> openDocumentLocation(String pathOrUrl) async {
    final trimmed = pathOrUrl.trim();
    if (trimmed.isEmpty) return false;

    try {
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        final uri = Uri.parse(trimmed);
        try {
          return await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {
          return await launchUrl(
            uri,
            mode: LaunchMode.platformDefault,
          );
        }
      } else {
        final uri = Uri.tryParse(trimmed);
        if (uri != null) {
          return await launchUrl(uri);
        }
      }
    } catch (e) {
      debugPrint('Error opening location: $e');
      return false;
    }
    return false;
  }
}
