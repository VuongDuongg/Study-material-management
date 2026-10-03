import 'package:drift/drift.dart';

/// Bảng dữ liệu Documents trong cơ sở dữ liệu SQLite
class Documents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  TextColumn get subject => text().withLength(min: 1, max: 100)();
  TextColumn get category => text().withLength(min: 1, max: 50)(); // Slide, Bài tập, Sách, Tài liệu khác
  TextColumn get filePath => text()(); // Đường dẫn file cục bộ hoặc link URL
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
