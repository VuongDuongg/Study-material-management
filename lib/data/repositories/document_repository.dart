import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/cloud_document_models.dart';

/// Repository giao tiếp trực tiếp với Supabase Client & Firebase Storage SDK
abstract class DocumentRepository {
  Future<List<DocumentModel>> searchDocuments({
    required String query,
    required String currentUserId,
  });

  Future<DocumentModel> uploadAndCreateDocument({
    required String ownerId,
    required String title,
    String? description,
    required File file,
  });

  Future<DocumentModel> updateDocument({
    required String documentId,
    required String title,
    String? description,
  });

  Future<void> deleteDocument({
    required String documentId,
    required String storagePath,
  });

  Future<UserModel?> findUserByEmail(String email);

  Future<void> shareDocument({
    required String documentId,
    required String targetUserId,
    required String permissionLevel,
  });

  Future<void> revokePermission({
    required String documentId,
    required String targetUserId,
  });

  Future<List<DocumentPermissionModel>> getDocumentPermissions(
    String documentId,
  );
}

class DocumentRepositoryImpl implements DocumentRepository {
  final SupabaseClient _supabase;
  final FirebaseStorage _storage;
  final Uuid _uuid;

  DocumentRepositoryImpl({
    SupabaseClient? supabase,
    FirebaseStorage? storage,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _storage = storage ?? FirebaseStorage.instance,
        _uuid = const Uuid();

  @override
  Future<List<DocumentModel>> searchDocuments({
    required String query,
    required String currentUserId,
  }) async {
    // 1. Tìm trong tài liệu do user sở hữu
    var ownerQuery = _supabase
        .from('documents')
        .select()
        .eq('owner_id', currentUserId);

    if (query.trim().isNotEmpty) {
      final sanitized = query.trim();
      ownerQuery = ownerQuery.or('title.ilike.%$sanitized%,description.ilike.%$sanitized%');
    }

    final ownerDocsResponse = await ownerQuery.order('created_at', ascending: false);

    final List<DocumentModel> results = [];
    for (final row in ownerDocsResponse) {
      results.add(
        DocumentModel.fromMap(
          row,
          currentUserId: currentUserId,
          explicitPermission: 'owner',
        ),
      );
    }

    // 2. Tìm trong tài liệu được chia sẻ cho user
    var sharedQuery = _supabase
        .from('document_permissions')
        .select('permission_level, documents(*)')
        .eq('user_id', currentUserId);

    final sharedResponse = await sharedQuery;

    for (final row in sharedResponse) {
      final docMap = row['documents'] as Map<String, dynamic>?;
      if (docMap != null) {
        final permLevel = row['permission_level'] as String? ?? 'view';
        final title = docMap['title'] as String? ?? '';
        final description = docMap['description'] as String? ?? '';

        // Khớp từ khóa tìm kiếm nếu có
        final lowerQuery = query.trim().toLowerCase();
        if (lowerQuery.isEmpty ||
            title.toLowerCase().contains(lowerQuery) ||
            description.toLowerCase().contains(lowerQuery)) {
          // Tránh trùng lặp nếu có
          if (!results.any((d) => d.id == docMap['id'])) {
            results.add(
              DocumentModel.fromMap(
                docMap,
                currentUserId: currentUserId,
                explicitPermission: permLevel,
              ),
            );
          }
        }
      }
    }

    return results;
  }

  @override
  Future<DocumentModel> uploadAndCreateDocument({
    required String ownerId,
    required String title,
    String? description,
    required File file,
  }) async {
    final docId = _uuid.v4();
    final originalFileName = p.basename(file.path);
    final fileSize = await file.length();
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

    // Upload Firebase Storage
    final storagePath = 'documents/$ownerId/$docId/$originalFileName';
    final ref = _storage.ref().child(storagePath);

    final uploadTask = ref.putFile(
      file,
      SettableMetadata(
        contentType: mimeType,
        customMetadata: {
          'ownerId': ownerId,
          'docId': docId,
          'originalName': originalFileName,
        },
      ),
    );

    final snapshot = await uploadTask;
    final fileUrl = await snapshot.ref.getDownloadURL();

    // Lưu Supabase
    final data = await _supabase
        .from('documents')
        .insert({
          'id': docId,
          'owner_id': ownerId,
          'title': title,
          'description': description,
          'file_url': fileUrl,
          'storage_path': storagePath,
          'file_size': fileSize,
          'mime_type': mimeType,
        })
        .select()
        .single();

    return DocumentModel.fromMap(
      data,
      currentUserId: ownerId,
      explicitPermission: 'owner',
    );
  }

  @override
  Future<DocumentModel> updateDocument({
    required String documentId,
    required String title,
    String? description,
  }) async {
    final data = await _supabase
        .from('documents')
        .update({
          'title': title.trim(),
          'description': description?.trim(),
        })
        .eq('id', documentId)
        .select()
        .single();

    return DocumentModel.fromMap(data);
  }

  @override
  Future<void> deleteDocument({
    required String documentId,
    required String storagePath,
  }) async {
    // 1. Xóa file trên Firebase Storage
    try {
      await _storage.ref().child(storagePath).delete();
    } catch (_) {
      // Bỏ qua nếu file trên storage đã bị xóa trước đó
    }

    // 2. Xóa record trong Supabase
    await _supabase.from('documents').delete().eq('id', documentId);
  }

  @override
  Future<UserModel?> findUserByEmail(String email) async {
    final res = await _supabase
        .from('users')
        .select()
        .eq('email', email.trim().toLowerCase())
        .maybeSingle();

    if (res == null) return null;
    return UserModel.fromMap(res);
  }

  @override
  Future<void> shareDocument({
    required String documentId,
    required String targetUserId,
    required String permissionLevel,
  }) async {
    await _supabase.from('document_permissions').upsert({
      'document_id': documentId,
      'user_id': targetUserId,
      'permission_level': permissionLevel,
    });
  }

  @override
  Future<void> revokePermission({
    required String documentId,
    required String targetUserId,
  }) async {
    await _supabase
        .from('document_permissions')
        .delete()
        .eq('document_id', documentId)
        .eq('user_id', targetUserId);
  }

  @override
  Future<List<DocumentPermissionModel>> getDocumentPermissions(
    String documentId,
  ) async {
    final response = await _supabase
        .from('document_permissions')
        .select('*, users(email, full_name)')
        .eq('document_id', documentId);

    return (response as List<dynamic>)
        .map((e) => DocumentPermissionModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
