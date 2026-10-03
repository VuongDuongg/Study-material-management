import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../data/database/app_database.dart';

class DocumentProvider extends ChangeNotifier {
  final AppDatabase _database;
  StreamSubscription<List<Document>>? _subscription;

  List<Document> _documents = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedSubject = 'Tất cả';
  String _selectedCategory = 'Tất cả';

  DocumentProvider(this._database) {
    _initStream();
  }

  // Getters
  List<Document> get documents => _documents;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedSubject => _selectedSubject;
  String get selectedCategory => _selectedCategory;

  /// Danh sách tất cả các môn học có trong dữ liệu (kèm tùy chọn 'Tất cả')
  List<String> get availableSubjects {
    final subjects = _documents.map((e) => e.subject.trim()).where((s) => s.isNotEmpty).toSet().toList();
    subjects.sort();
    return ['Tất cả', ...subjects];
  }

  /// Danh sách danh mục cố định theo yêu cầu
  static const List<String> categories = [
    'Tất cả',
    'Slide',
    'Bài tập',
    'Sách',
    'Tài liệu khác',
  ];

  void _initStream() {
    _subscription?.cancel();
    _subscription = _database
        .watchFilteredDocuments(
          searchQuery: _searchQuery,
          subjectFilter: _selectedSubject,
          categoryFilter: _selectedCategory,
        )
        .listen(
          (data) {
            _documents = data;
            _isLoading = false;
            notifyListeners();
          },
          onError: (error) {
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      _initStream();
    }
  }

  void setSelectedSubject(String subject) {
    if (_selectedSubject != subject) {
      _selectedSubject = subject;
      _initStream();
    }
  }

  void setSelectedCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      _initStream();
    }
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedSubject = 'Tất cả';
    _selectedCategory = 'Tất cả';
    _initStream();
  }

  // --- CRUD ACTIONS ---

  Future<void> addDocument({
    required String title,
    required String subject,
    required String category,
    required String filePath,
    DateTime? createdAt,
  }) async {
    final companion = DocumentsCompanion(
      title: Value(title.trim()),
      subject: Value(subject.trim()),
      category: Value(category.trim()),
      filePath: Value(filePath.trim()),
      createdAt: createdAt != null ? Value(createdAt) : const Value.absent(),
    );
    await _database.insertDocument(companion);
  }

  Future<void> updateExistingDocument(Document document) async {
    await _database.updateDocument(document);
  }

  Future<void> deleteDocument(int id) async {
    await _database.deleteDocumentById(id);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
