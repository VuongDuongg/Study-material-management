import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/database/app_database.dart';
import '../../logic/providers/document_provider.dart';
import '../../logic/providers/theme_provider.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/filter_bar.dart';
import 'add_edit_document_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showDeleteDialog(BuildContext context, Document doc) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa tài liệu "${doc.title}" không?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await context.read<DocumentProvider>().deleteDocument(doc.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã xóa tài liệu'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final docProvider = context.watch<DocumentProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    final documents = docProvider.documents;
    final isLoading = docProvider.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_stories_rounded),
            SizedBox(width: 10),
            Text('Tài Liệu Học Tập'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Đổi giao diện Sáng/Tối',
            icon: Icon(
              themeProvider.isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () => themeProvider.toggleTheme(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm nhanh Material 3
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Tìm kiếm theo tiêu đề hoặc môn học...',
              leading: const Icon(Icons.search_rounded),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      docProvider.setSearchQuery('');
                    },
                  ),
              ],
              onChanged: (val) {
                docProvider.setSearchQuery(val);
              },
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),

          // Bộ lọc Môn học & Danh mục
          FilterBar(
            subjects: docProvider.availableSubjects,
            categories: DocumentProvider.categories,
            selectedSubject: docProvider.selectedSubject,
            selectedCategory: docProvider.selectedCategory,
            onSubjectChanged: (sub) => docProvider.setSelectedSubject(sub),
            onCategoryChanged: (cat) => docProvider.setSelectedCategory(cat),
          ),

          const SizedBox(height: 8),

          // Danh sách tài liệu phản ứng thời gian thực (Reactive Stream List)
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : documents.isEmpty
                    ? EmptyStateView(
                        title: docProvider.searchQuery.isNotEmpty ||
                                docProvider.selectedSubject != 'Tất cả' ||
                                docProvider.selectedCategory != 'Tất cả'
                            ? 'Không tìm thấy tài liệu phù hợp'
                            : 'Chưa có tài liệu nào',
                        message: docProvider.searchQuery.isNotEmpty ||
                                docProvider.selectedSubject != 'Tất cả' ||
                                docProvider.selectedCategory != 'Tất cả'
                            ? 'Hãy thử thay đổi từ khóa tìm kiếm hoặc bỏ bớt bộ lọc.'
                            : 'Nhấn vào nút "+" bên dưới để lưu trữ tài liệu học tập đầu tiên của bạn!',
                        icon: docProvider.searchQuery.isNotEmpty
                            ? Icons.search_off_rounded
                            : Icons.library_books_outlined,
                        actionLabel: docProvider.searchQuery.isNotEmpty ||
                                docProvider.selectedSubject != 'Tất cả' ||
                                docProvider.selectedCategory != 'Tất cả'
                            ? 'Đặt lại bộ lọc'
                            : 'Thêm tài liệu ngay',
                        onAction: () {
                          if (docProvider.searchQuery.isNotEmpty ||
                              docProvider.selectedSubject != 'Tất cả' ||
                              docProvider.selectedCategory != 'Tất cả') {
                            _searchController.clear();
                            docProvider.clearFilters();
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddEditDocumentScreen(),
                              ),
                            );
                          }
                        },
                      )
                    : ListView.builder(
                        itemCount: documents.length,
                        padding: const EdgeInsets.only(bottom: 88, top: 4),
                        itemBuilder: (context, index) {
                          final doc = documents[index];
                          return DocumentCard(
                            document: doc,
                            onEdit: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddEditDocumentScreen(
                                    documentToEdit: doc,
                                  ),
                                ),
                              );
                            },
                            onDelete: () => _showDeleteDialog(context, doc),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddEditDocumentScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm tài liệu'),
      ),
    );
  }
}
