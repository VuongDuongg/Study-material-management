import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/cloud_document_models.dart';
import '../../logic/providers/auth_provider.dart';
import '../../logic/services/file_service.dart';
import 'share_document_dialog.dart';

class CloudDocumentCard extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CloudDocumentCard({
    super.key,
    required this.document,
    required this.onEdit,
    required this.onDelete,
  });

  String _extractCategory(String? description) {
    if (description == null) return 'Tài liệu khác';
    final match = RegExp(r'Danh mục:\s*([^,\n]+)').firstMatch(description);
    return match?.group(1)?.trim() ?? 'Tài liệu khác';
  }

  String _extractSubject(String? description) {
    if (description == null) return 'Chung';
    final match = RegExp(r'Môn:\s*([^,\n]+)').firstMatch(description);
    return match?.group(1)?.trim() ?? 'Chung';
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'slide':
        return Icons.slideshow_rounded;
      case 'bài tập':
        return Icons.assignment_outlined;
      case 'sách':
        return Icons.menu_book_rounded;
      default:
        return Icons.article_outlined;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'slide':
        return const Color(0xFFF59E0B);
      case 'bài tập':
        return const Color(0xFF10B981);
      case 'sách':
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final category = _extractCategory(document.description);
    final subject = _extractSubject(document.description);
    final catColor = _getCategoryColor(category);
    final formattedDate =
        DateFormat('dd/MM/yyyy • HH:mm').format(document.createdAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : const Color(0xFF64748B).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            final targetUrl = document.fileUrl.isNotEmpty
                ? document.fileUrl
                : document.storagePath;
            final success = await FileService.openDocumentLocation(targetUrl);
            if (!success && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Không thể mở tệp: $targetUrl'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            catColor.withValues(alpha: 0.2),
                            catColor.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _getCategoryIcon(category),
                        color: catColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            document.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.school_outlined,
                                size: 14,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  subject,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[700],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Tùy chọn',
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      onSelected: (val) {
                        if (val == 'share') {
                          final auth = context.read<AuthProvider>();
                          final currentUser = auth.currentUser;
                          if (currentUser == null) return;
                          ShareDocumentDialog.show(
                            context,
                            documentId: document.id,
                            documentTitle: document.title,
                            ownerId: document.ownerId,
                          );
                        } else if (val == 'edit') {
                          onEdit();
                        } else if (val == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (ctx) => [
                        if (document.isOwner)
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share_outlined,
                                    size: 20, color: Colors.blue),
                                SizedBox(width: 12),
                                Text('Chia sẻ quyền',
                                    style: TextStyle(color: Colors.blue)),
                              ],
                            ),
                          ),
                        if (document.canEdit)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 20),
                                SizedBox(width: 12),
                                Text('Chỉnh sửa'),
                              ],
                            ),
                          ),
                        if (document.isOwner)
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: theme.colorScheme.error,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Xóa tài liệu',
                                  style:
                                      TextStyle(color: theme.colorScheme.error),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: catColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Badge hiển thị vai trò quyền
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: document.isOwner
                            ? Colors.purple.withValues(alpha: 0.12)
                            : (document.canEdit
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.blue.withValues(alpha: 0.12)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        document.isOwner
                            ? 'Chủ sở hữu'
                            : (document.canEdit ? 'Có quyền sửa' : 'Chỉ xem'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: document.isOwner
                              ? Colors.purple
                              : (document.canEdit ? Colors.green : Colors.blue),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
