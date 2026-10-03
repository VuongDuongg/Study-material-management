import 'package:flutter_test/flutter_test.dart';
import 'package:th1/data/database/app_database.dart';
import 'package:drift/native.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // Khởi tạo in-memory database để kiểm thử logic
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('Kiểm tra thêm và truy vấn tài liệu trong AppDatabase', () async {
    final companion = DocumentsCompanion.insert(
      title: 'Slide Bài 1',
      subject: 'Lập trình di động',
      category: 'Slide',
      filePath: 'https://example.com/slide1.pdf',
    );

    final id = await db.insertDocument(companion);
    expect(id, isPositive);

    final docs = await db.watchAllDocuments().first;
    expect(docs.length, 1);
    expect(docs.first.title, 'Slide Bài 1');
    expect(docs.first.subject, 'Lập trình di động');
  });
}
