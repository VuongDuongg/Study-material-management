import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/database/app_database.dart';
import '../../data/models/cloud_document_models.dart';
import '../../logic/providers/auth_provider.dart';
import '../../logic/providers/cloud_document_provider.dart';
import '../../logic/providers/document_provider.dart';
import '../../logic/providers/theme_provider.dart';
import '../../logic/services/document_service.dart';
import '../widgets/cloud_document_card.dart';
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
        title: const Text('Xác nhận xóa tài liệu'),
        content: Text(
          'Bạn có chắc chắn muốn xóa "${doc.title}" khỏi danh sách không?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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

  void _showEditCloudDocDialog(BuildContext context, DocumentModel doc) {
    final titleController = TextEditingController(text: doc.title);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Chỉnh sửa tài liệu'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Tiêu đề tài liệu',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              final newTitle = titleController.text.trim();
              if (newTitle.isEmpty) return;
              Navigator.pop(dialogCtx);

              final auth = context.read<AuthProvider>();
              final currentUser = auth.currentUser;
              if (currentUser == null) return;

              final docService = context.read<DocumentService>();
              final res = await docService.updateDocument(
                document: doc,
                newTitle: newTitle,
                currentUserId: currentUser.uid,
              );

              if (context.mounted) {
                res.when(
                  onSuccess: (_) {
                    context
                        .read<CloudDocumentProvider>()
                        .loadDocumentsForUser(currentUser.uid);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã cập nhật tài liệu thành công!')),
                    );
                  },
                  onFailure: (msg, _) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Lỗi: $msg'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  },
                );
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final localDocProvider = context.watch<DocumentProvider>();
    final cloudDocProvider = context.watch<CloudDocumentProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    final isAuthenticated = authProvider.isAuthenticated;
    final cloudDocuments = cloudDocProvider.documents;
    final localDocuments = localDocProvider.documents;
    final isLoading = isAuthenticated ? cloudDocProvider.isLoading : localDocProvider.isLoading;
    final totalCount = isAuthenticated ? cloudDocuments.length : localDocuments.length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Tài Liệu Học Tập',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$totalCount tài liệu đã lưu',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Nút chuyển Theme
          IconButton(
            tooltip: 'Đổi giao diện Sáng/Tối',
            icon: Icon(
              themeProvider.isDarkMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              size: 22,
            ),
            onPressed: () => themeProvider.toggleTheme(),
          ),

          // Nút Google Sign-In / Avatar
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (auth.isLoading) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final user = auth.currentUser;
              if (user != null) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: PopupMenuButton<String>(
                    tooltip: 'Tài khoản: ${user.displayName ?? user.email}',
                    offset: const Offset(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    icon: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundImage: user.photoURL != null
                            ? NetworkImage(user.photoURL!)
                            : null,
                        child: user.photoURL == null
                            ? Text(
                                (user.displayName ??
                                        user.email ??
                                        'U')[0]
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                      ),
                    ),
                    onSelected: (value) async {
                      if (value == 'logout') {
                        await auth.signOut();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã đăng xuất tài khoản Google.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        enabled: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName ?? 'Người dùng',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded,
                                color: Colors.red, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'Đăng xuất',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () async {
                    final success = await auth.signInWithGoogle();
                    if (!context.mounted) return;
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Chào mừng ${auth.currentUser?.displayName ?? "bạn"}!',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else if (auth.errorMessage != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Lỗi: ${auth.errorMessage}'),
                          backgroundColor: theme.colorScheme.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.login_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Google Sign-In', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm nhanh bo cong hiện đại
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  if (isAuthenticated) {
                    cloudDocProvider.setSearchQuery(val);
                  } else {
                    localDocProvider.setSearchQuery(val);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm tài liệu, môn học...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            if (isAuthenticated) {
                              cloudDocProvider.setSearchQuery('');
                            } else {
                              localDocProvider.setSearchQuery('');
                            }
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          // Bộ lọc Môn học & Danh mục
          FilterBar(
            subjects: isAuthenticated
                ? cloudDocProvider.availableSubjects
                : localDocProvider.availableSubjects,
            categories: DocumentProvider.categories,
            selectedSubject: isAuthenticated
                ? cloudDocProvider.selectedSubject
                : localDocProvider.selectedSubject,
            selectedCategory: isAuthenticated
                ? cloudDocProvider.selectedCategory
                : localDocProvider.selectedCategory,
            onSubjectChanged: (sub) {
              if (isAuthenticated) {
                cloudDocProvider.setSelectedSubject(sub);
              } else {
                localDocProvider.setSelectedSubject(sub);
              }
            },
            onCategoryChanged: (cat) {
              if (isAuthenticated) {
                cloudDocProvider.setSelectedCategory(cat);
              } else {
                localDocProvider.setSelectedCategory(cat);
              }
            },
          ),

          const SizedBox(height: 8),

          // Danh sách tài liệu
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : totalCount == 0
                    ? EmptyStateView(
                        title: _searchController.text.isNotEmpty ||
                                (isAuthenticated
                                    ? cloudDocProvider.selectedCategory != 'Tất cả' ||
                                        cloudDocProvider.selectedSubject != 'Tất cả'
                                    : localDocProvider.selectedCategory != 'Tất cả' ||
                                        localDocProvider.selectedSubject != 'Tất cả')
                            ? 'Không tìm thấy tài liệu'
                            : (isAuthenticated
                                ? 'Chưa có tài liệu nào thuộc tài khoản này'
                                : 'Chưa có tài liệu nào'),
                        message: _searchController.text.isNotEmpty
                            ? 'Thử thay đổi từ khóa hoặc bộ lọc danh mục'
                            : (isAuthenticated
                                ? 'Tài liệu bạn tạo hoặc được người khác chia sẻ sẽ xuất hiện ở đây.'
                                : 'Bấm nút thêm bên dưới để tạo tài liệu học tập đầu tiên của bạn!'),
                        icon: _searchController.text.isNotEmpty
                            ? Icons.search_off_rounded
                            : Icons.auto_stories_outlined,
                        actionLabel: _searchController.text.isNotEmpty
                            ? 'Xóa bộ lọc'
                            : 'Thêm tài liệu mới',
                        onAction: () {
                          if (_searchController.text.isNotEmpty) {
                            _searchController.clear();
                            if (isAuthenticated) {
                              cloudDocProvider.clearFilters();
                            } else {
                              localDocProvider.clearFilters();
                            }
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const AddEditDocumentScreen(),
                              ),
                            );
                          }
                        },
                      )
                    : isAuthenticated
                        // Khi đã đăng nhập Google: Chỉ hiển thị tài liệu của tài khoản này hoặc được chia sẻ
                        ? ListView.builder(
                            padding: const EdgeInsets.only(bottom: 88, top: 4),
                            itemCount: cloudDocuments.length,
                            itemBuilder: (context, index) {
                              final doc = cloudDocuments[index];
                              return CloudDocumentCard(
                                document: doc,
                                onEdit: () {
                                  // Chỉnh sửa tiêu đề
                                  _showEditCloudDocDialog(context, doc);
                                },
                                onDelete: () async {
                                  final ok = await cloudDocProvider.deleteDoc(doc);
                                  if (ok && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Đã xóa tài liệu khỏi Cloud')),
                                    );
                                  }
                                },
                              );
                            },
                          )
                        // Khi chưa đăng nhập: Hiển thị tài liệu cục bộ
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 88, top: 4),
                            itemCount: localDocuments.length,
                            itemBuilder: (context, index) {
                              final doc = localDocuments[index];
                              return DocumentCard(
                                document: doc,
                                onEdit: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AddEditDocumentScreen(documentToEdit: doc),
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
        elevation: 3,
        highlightElevation: 6,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddEditDocumentScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Thêm tài liệu',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
