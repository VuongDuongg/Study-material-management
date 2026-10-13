import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/cloud_document_models.dart';
import '../../logic/providers/auth_provider.dart';
import '../../logic/services/document_service.dart';

/// Hộp thoại chia sẻ tài liệu và quản lý quyền truy cập
class ShareDocumentDialog extends StatefulWidget {
  final String documentId;
  final String documentTitle;
  final String ownerId;

  const ShareDocumentDialog({
    super.key,
    required this.documentId,
    required this.documentTitle,
    required this.ownerId,
  });

  static Future<void> show(
    BuildContext context, {
    required String documentId,
    required String documentTitle,
    required String ownerId,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ShareDocumentDialog(
        documentId: documentId,
        documentTitle: documentTitle,
        ownerId: ownerId,
      ),
    );
  }

  @override
  State<ShareDocumentDialog> createState() => _ShareDocumentDialogState();
}

class _ShareDocumentDialogState extends State<ShareDocumentDialog> {
  final TextEditingController _emailController = TextEditingController();
  String _selectedPermission = 'view'; // 'view' hoặc 'edit'
  bool _isLoading = false;
  List<DocumentPermissionModel> _permissions = [];

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    final docService = context.read<DocumentService>();
    final result = await docService.getDocumentPermissions(
      documentId: widget.documentId,
    );
    if (result.isSuccess && mounted) {
      setState(() {
        _permissions = result.dataOrNull ?? [];
      });
    }
  }

  Future<void> _share() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập email người nhận')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để chia sẻ tài liệu')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final docService = context.read<DocumentService>();

    try {
      // 1. Tìm hoặc lấy đúng UUID trên Supabase
      final supabase = Supabase.instance.client;
      String targetDocId = widget.documentId;

      // Nếu documentId là int (từ SQLite cục bộ ví dụ "3"), tìm UUID thực tế trên Supabase
      if (!widget.documentId.contains('-')) {
        final findRes = await supabase
            .from('documents')
            .select('id, owner_id')
            .eq('title', widget.documentTitle.trim())
            .order('created_at', ascending: false)
            .limit(1);

        if ((findRes as List).isNotEmpty) {
          targetDocId = findRes.first['id'] as String;
        } else {
          // Tạo một bản ghi trên Supabase nếu chưa tồn tại
          final newUuid = const Uuid().v4();
          await supabase.from('documents').insert({
            'id': newUuid,
            'owner_id': currentUser.uid,
            'title': widget.documentTitle,
            'description': 'Tài liệu từ ứng dụng',
            'file_url': 'https://placeholder.local',
            'storage_path': 'documents/${currentUser.uid}/$newUuid/doc.dat',
            'file_size': 1024,
            'mime_type': 'text/plain',
          });
          targetDocId = newUuid;
        }
      }

      final dummyDoc = DocumentModel(
        id: targetDocId,
        ownerId: widget.ownerId,
        title: widget.documentTitle,
        fileUrl: '',
        storagePath: '',
        fileSize: 0,
        mimeType: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        userAccessLevel: 'owner',
      );

      final result = await docService.shareDocumentByEmail(
        document: dummyDoc,
        targetEmail: email,
        permissionLevel: _selectedPermission,
        currentUserId: currentUser.uid,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      result.when(
        onSuccess: (_) {
          _emailController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã cấp quyền $_selectedPermission cho $email!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadPermissions();
        },
        onFailure: (msg, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: $msg'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _revoke(String targetUserId, String email) async {
    final auth = context.read<AuthProvider>();
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final docService = context.read<DocumentService>();
    final dummyDoc = DocumentModel(
      id: widget.documentId,
      ownerId: widget.ownerId,
      title: widget.documentTitle,
      fileUrl: '',
      storagePath: '',
      fileSize: 0,
      mimeType: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      userAccessLevel: 'owner',
    );

    final res = await docService.revokePermission(
      document: dummyDoc,
      targetUserId: targetUserId,
      currentUserId: currentUser.uid,
    );

    if (!mounted) return;
    res.when(
      onSuccess: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã thu hồi quyền của $email')),
        );
        _loadPermissions();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.share_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Chia sẻ tài liệu',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.documentTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              // Ô nhập Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email người nhận',
                  hintText: 'nguoidung@gmail.com',
                  prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              // Chọn quyền
              Row(
                children: [
                  const Text('Quyền: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Xem (View)'),
                    selected: _selectedPermission == 'view',
                    onSelected: (val) {
                      if (val) setState(() => _selectedPermission = 'view');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Sửa (Edit)'),
                    selected: _selectedPermission == 'edit',
                    onSelected: (val) {
                      if (val) setState(() => _selectedPermission = 'edit');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _share,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Cấp quyền'),
                ),
              ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Danh sách được chia sẻ:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_permissions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Chưa chia sẻ cho người nào',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _permissions.length,
                  itemBuilder: (ctx, index) {
                    final p = _permissions[index];
                    final email = p.userEmail ?? p.userId;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        radius: 14,
                        child: Icon(Icons.person, size: 16),
                      ),
                      title: Text(email, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        'Quyền: ${p.permissionLevel.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: p.permissionLevel == 'edit' ? Colors.green : Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        tooltip: 'Thu hồi quyền',
                        onPressed: () => _revoke(p.userId, email),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
