import 'package:flutter/foundation.dart';
import '../../data/models/cloud_document_models.dart';
import '../services/document_service.dart';

class CloudDocumentProvider extends ChangeNotifier {
  final DocumentService _service;
  List<DocumentModel> _documents = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedCategory = 'Tất cả';
  String _selectedSubject = 'Tất cả';
  String _currentUserId = '';

  CloudDocumentProvider(this._service);

  List<DocumentModel> get documents {
    return _documents.where((doc) {
      // Lọc danh mục
      if (_selectedCategory != 'Tất cả') {
        final desc = doc.description ?? '';
        if (!desc.contains('Danh mục: $_selectedCategory') &&
            !doc.title.toLowerCase().contains(_selectedCategory.toLowerCase())) {
          return false;
        }
      }
      // Lọc môn học
      if (_selectedSubject != 'Tất cả') {
        final desc = doc.description ?? '';
        if (!desc.contains('Môn: $_selectedSubject') &&
            !doc.title.toLowerCase().contains(_selectedSubject.toLowerCase())) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  String get selectedSubject => _selectedSubject;

  List<String> get availableSubjects {
    final subjects = <String>{};
    for (final doc in _documents) {
      final desc = doc.description ?? '';
      if (desc.contains('Môn: ')) {
        final match = RegExp(r'Môn:\s*([^,\n]+)').firstMatch(desc);
        if (match != null && match.group(1) != null) {
          subjects.add(match.group(1)!.trim());
        }
      }
    }
    final list = subjects.toList()..sort();
    return ['Tất cả', ...list];
  }

  static const List<String> categories = [
    'Tất cả',
    'Slide',
    'Bài tập',
    'Sách',
    'Tài liệu khác',
  ];

  /// Tải tài liệu theo User ID thực tế từ Supabase (có RLS phân quyền)
  Future<void> loadDocumentsForUser(String? userId) async {
    if (userId == null || userId.isEmpty) {
      _currentUserId = '';
      _documents = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _currentUserId = userId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _service.searchDocuments(
      query: _searchQuery,
      currentUserId: userId,
    );

    _isLoading = false;
    result.when(
      onSuccess: (docs) {
        _documents = docs;
      },
      onFailure: (msg, _) {
        _errorMessage = msg;
      },
    );
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    if (_currentUserId.isNotEmpty) {
      loadDocumentsForUser(_currentUserId);
    } else {
      notifyListeners();
    }
  }

  void setSelectedCategory(String cat) {
    _selectedCategory = cat;
    notifyListeners();
  }

  void setSelectedSubject(String sub) {
    _selectedSubject = sub;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = 'Tất cả';
    _selectedSubject = 'Tất cả';
    if (_currentUserId.isNotEmpty) {
      loadDocumentsForUser(_currentUserId);
    } else {
      notifyListeners();
    }
  }

  Future<bool> deleteDoc(DocumentModel doc) async {
    final res = await _service.deleteDocument(
      document: doc,
      currentUserId: _currentUserId,
    );
    if (res.isSuccess) {
      _documents.removeWhere((d) => d.id == doc.id);
      notifyListeners();
      return true;
    }
    return false;
  }
}
