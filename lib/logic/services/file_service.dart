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
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        // Trên web hoặc native, thử mở theo URI
        final uri = Uri.tryParse(trimmed);
        if (uri != null && await canLaunchUrl(uri)) {
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
