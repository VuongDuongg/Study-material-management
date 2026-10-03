import 'package:drift/drift.dart';
import '../models/documents.dart';
import 'connection/connection.dart' as impl;

part 'app_database.g.dart';

@DriftDatabase(tables: [Documents])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? impl.openConnection());

  // Cho phép inject QueryExecutor cho mục đích testing nếu cần
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  // --- CRUD QUERIES ---

  /// Lấy stream tất cả tài liệu, sắp xếp theo thời gian mới nhất (Reactive Local-First)
  Stream<List<Document>> watchAllDocuments() {
    return (select(documents)
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  /// Thêm tài liệu mới
  Future<int> insertDocument(DocumentsCompanion doc) {
    return into(documents).insert(doc);
  }

  /// Cập nhật tài liệu
  Future<bool> updateDocument(Document doc) {
    return update(documents).replace(doc);
  }

  /// Xóa tài liệu theo ID
  Future<int> deleteDocumentById(int id) {
    return (delete(documents)..where((t) => t.id.equals(id))).go();
  }

  /// Tìm kiếm tài liệu theo từ khóa trong tiêu đề hoặc môn học
  Stream<List<Document>> watchFilteredDocuments({
    String searchQuery = '',
    String? subjectFilter,
    String? categoryFilter,
  }) {
    return (select(documents)
          ..where((t) {
            final predicates = <Expression<bool>>[];

            if (searchQuery.trim().isNotEmpty) {
              final queryPattern = '%${searchQuery.trim().toLowerCase()}%';
              predicates.add(
                t.title.lower().like(queryPattern) |
                    t.subject.lower().like(queryPattern),
              );
            }

            if (subjectFilter != null && subjectFilter.isNotEmpty && subjectFilter != 'Tất cả') {
              predicates.add(t.subject.equals(subjectFilter));
            }

            if (categoryFilter != null && categoryFilter.isNotEmpty && categoryFilter != 'Tất cả') {
              predicates.add(t.category.equals(categoryFilter));
            }

            if (predicates.isEmpty) {
              return const Constant(true);
            }

            return predicates.reduce((a, b) => a & b);
          })
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }
}
