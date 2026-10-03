import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    Directory dbFolder;
    try {
      // Ưu tiên getApplicationSupportDirectory (trên Windows là AppData/Roaming hoặc Local)
      // Đường dẫn này là ASCII chuẩn, không bị OneDrive đồng bộ và không chứa ký tự tiếng Việt có dấu
      dbFolder = await getApplicationSupportDirectory();
    } catch (_) {
      dbFolder = await getTemporaryDirectory();
    }

    if (!await dbFolder.exists()) {
      await dbFolder.create(recursive: true);
    }

    final file = File(p.join(dbFolder.path, 'study_documents.sqlite'));
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    // Không dùng createInBackground để tránh isolate mở file khi chưa ready
    return NativeDatabase(file);
  });
}
