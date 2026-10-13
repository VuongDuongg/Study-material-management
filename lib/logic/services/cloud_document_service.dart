import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Model đối tượng tài liệu lưu trên Cloud (Supabase & Firebase Storage)
class CloudDocument {
  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final String fileUrl;
  final String storagePath;
  final int fileSize;
  final String mimeType;
  final DateTime createdAt;
  final DateTime updatedAt;

  CloudDocument({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    required this.fileUrl,
    required this.storagePath,
    required this.fileSize,
    required this.mimeType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CloudDocument.fromMap(Map<String, dynamic> map) {
    return CloudDocument(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      fileUrl: map['file_url'] as String,
      storagePath: map['storage_path'] as String,
      fileSize: (map['file_size'] as num?)?.toInt() ?? 0,
      mimeType: map['mime_type'] as String? ?? 'application/octet-stream',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'title': title,
      'description': description,
      'file_url': fileUrl,
      'storage_path': storagePath,
      'file_size': fileSize,
      'mime_type': mimeType,
    };
  }
}

/// Model quyền truy cập tài liệu
class DocumentPermission {
  final String id;
  final String documentId;
  final String userId;
  final String permissionLevel; // 'view' hoặc 'edit'
  final DateTime grantedAt;
  final String? userEmail;

  DocumentPermission({
    required this.id,
    required this.documentId,
    required this.userId,
    required this.permissionLevel,
    required this.grantedAt,
    this.userEmail,
  });

  factory DocumentPermission.fromMap(Map<String, dynamic> map) {
    return DocumentPermission(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      userId: map['user_id'] as String,
      permissionLevel: map['permission_level'] as String,
      grantedAt: DateTime.parse(map['granted_at'] as String),
      userEmail: map['users'] != null ? map['users']['email'] as String? : null,
    );
  }
}

/// Service quản lý toàn diện: Firebase Storage + Supabase Database
class CloudDocumentService {
  final FirebaseStorage _storage;
  final SupabaseClient _supabase;
  final Uuid _uuid = const Uuid();

  CloudDocumentService({
    FirebaseStorage? storage,
    SupabaseClient? supabase,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _supabase = supabase ?? Supabase.instance.client;

  /// Đảm bảo thông tin User được đồng bộ vào bảng `public.users` của Supabase
  Future<void> syncUserToSupabase({
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      final res = await _supabase.from('users').upsert({
        'id': uid,
        'email': email,
        'full_name': displayName ?? email.split('@').first,
        'avatar_url': photoUrl,
      }).select();
      developer.log('Đã đồng bộ user sang Supabase: $uid', name: 'CloudDocumentService');
      debugPrint('>>> [SUPABASE SYNC THÀNH CÔNG] Đã lưu User vào Supabase: $res');
    } catch (e, st) {
      developer.log('Lỗi sync user sang Supabase: $e', error: e, name: 'CloudDocumentService');
      debugPrint('>>> [SUPABASE SYNC LỖI]: $e \n$st');
      rethrow;
    }
  }

  /// 1. Tải file lên Firebase Storage & Lưu metadata vào Supabase
  /// Cấu trúc chuẩn hóa: documents/{owner_id}/{doc_id}/{fileName}
  Future<CloudDocument> uploadAndCreateDocument({
    required String ownerId,
    required String title,
    String? description,
    required File file,
  }) async {
    try {
      final docId = _uuid.v4();
      final originalFileName = p.basename(file.path);
      final fileSize = await file.length();
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

      // 1. Upload lên Firebase Storage
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

      // 2. Lưu Metadata vào bảng documents trên Supabase
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

      return CloudDocument.fromMap(data);
    } catch (e, st) {
      developer.log('Lỗi uploadAndCreateDocument', error: e, stackTrace: st, name: 'CloudDocumentService');
      throw Exception('Không thể tải tệp lên: $e');
    }
  }

  /// 2. Lấy danh sách tài liệu thuộc sở hữu của user
  Future<List<CloudDocument>> getMyDocuments(String ownerId) async {
    try {
      final List<dynamic> response = await _supabase
          .from('documents')
          .select()
          .eq('owner_id', ownerId)
          .order('created_at', ascending: false);

      return response.map((e) => CloudDocument.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      developer.log('Lỗi getMyDocuments: $e', error: e, name: 'CloudDocumentService');
      return [];
    }
  }

  /// 3. Lấy danh sách tài liệu được chia sẻ cho user
  Future<List<CloudDocument>> getSharedWithMeDocuments(String userId) async {
    try {
      final List<dynamic> response = await _supabase
          .from('document_permissions')
          .select('documents(*)')
          .eq('user_id', userId);

      final List<CloudDocument> list = [];
      for (final row in response) {
        if (row['documents'] != null) {
          list.add(CloudDocument.fromMap(row['documents'] as Map<String, dynamic>));
        }
      }
      return list;
    } catch (e) {
      developer.log('Lỗi getSharedWithMeDocuments: $e', error: e, name: 'CloudDocumentService');
      return [];
    }
  }

  /// 4. Chia sẻ tài liệu cho người dùng khác thông qua email
  Future<void> shareDocument({
    required String documentId,
    required String targetEmail,
    required String permissionLevel, // 'view' hoặc 'edit'
  }) async {
    try {
      // Tìm target user trong bảng users
      final userRes = await _supabase
          .from('users')
          .select('id')
          .eq('email', targetEmail.trim().toLowerCase())
          .maybeSingle();

      if (userRes == null) {
        throw Exception('Không tìm thấy người dùng có email: $targetEmail');
      }

      final targetUserId = userRes['id'] as String;

      // Cấp quyền hoặc cập nhật quyền
      await _supabase.from('document_permissions').upsert({
        'document_id': documentId,
        'user_id': targetUserId,
        'permission_level': permissionLevel,
      });

      developer.log('Đã cấp quyền $permissionLevel cho $targetEmail', name: 'CloudDocumentService');
    } catch (e) {
      developer.log('Lỗi shareDocument: $e', error: e, name: 'CloudDocumentService');
      rethrow;
    }
  }

  /// 5. Cập nhật thông tin tài liệu
  Future<void> updateDocument({
    required String documentId,
    required String title,
    String? description,
  }) async {
    try {
      await _supabase.from('documents').update({
        'title': title,
        'description': description,
      }).eq('id', documentId);
    } catch (e) {
      developer.log('Lỗi updateDocument: $e', error: e, name: 'CloudDocumentService');
      throw Exception('Không thể cập nhật tài liệu: $e');
    }
  }

  /// 6. Xóa tài liệu khỏi Supabase & Firebase Storage
  Future<void> deleteDocument({
    required String documentId,
    required String storagePath,
  }) async {
    try {
      // Xóa trên Firebase Storage
      try {
        await _storage.ref().child(storagePath).delete();
      } catch (storageErr) {
        developer.log('Lỗi xóa storage file (bỏ qua nếu không tồn tại): $storageErr');
      }

      // Xóa trong Supabase (sẽ tự động cascade xóa bảng document_permissions)
      await _supabase.from('documents').delete().eq('id', documentId);
    } catch (e) {
      developer.log('Lỗi deleteDocument: $e', error: e, name: 'CloudDocumentService');
      throw Exception('Không thể xóa tài liệu: $e');
    }
  }
}
