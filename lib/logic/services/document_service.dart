import 'dart:io';
import '../../data/models/cloud_document_models.dart';
import '../../data/repositories/document_repository.dart';
import '../common/result.dart';

/// Service xử lý nghiệp vụ, kiểm tra quyền hạn (validation) và trả về Result Pattern
class DocumentService {
  final DocumentRepository _repository;

  DocumentService({DocumentRepository? repository})
      : _repository = repository ?? DocumentRepositoryImpl();

  /// 1. Tìm kiếm tài liệu theo title hoặc description có phân quyền
  Future<Result<List<DocumentModel>>> searchDocuments({
    required String query,
    required String currentUserId,
  }) async {
    try {
      if (currentUserId.trim().isEmpty) {
        return const Failure('Người dùng chưa được xác thực.');
      }

      final documents = await _repository.searchDocuments(
        query: query,
        currentUserId: currentUserId,
      );

      return Success(documents);
    } catch (e) {
      return Failure('Không thể tìm kiếm tài liệu: $e', e);
    }
  }

  /// 2. Cập nhật tiêu đề & mô tả tài liệu (Kiểm tra quyền hạn trước khi gửi request)
  Future<Result<DocumentModel>> updateDocument({
    required DocumentModel document,
    required String newTitle,
    String? newDescription,
    required String currentUserId,
  }) async {
    try {
      // Kiểm tra tính hợp lệ của dữ liệu đầu vào
      if (newTitle.trim().isEmpty) {
        return const Failure('Tiêu đề tài liệu không được để trống.');
      }

      // Kiểm tra quyền hạn của user trên Client trước khi gọi server
      if (!document.canEdit) {
        return const Failure(
          'Từ chối truy cập: Bạn không có quyền chỉnh sửa tài liệu này.',
        );
      }

      final updatedDoc = await _repository.updateDocument(
        documentId: document.id,
        title: newTitle,
        description: newDescription,
      );

      return Success(updatedDoc);
    } catch (e) {
      return Failure('Lỗi khi cập nhật tài liệu: $e', e);
    }
  }

  /// 3. Chia sẻ tài liệu cho người dùng khác qua Email
  Future<Result<void>> shareDocumentByEmail({
    required DocumentModel document,
    required String targetEmail,
    required String permissionLevel, // 'view' hoặc 'edit'
    required String currentUserId,
  }) async {
    try {
      // Chỉ chủ sở hữu (Owner) mới có quyền chia sẻ
      if (document.ownerId != currentUserId) {
        return const Failure(
          'Từ chối truy cập: Chỉ chủ sở hữu mới có quyền phân quyền tài liệu này.',
        );
      }

      final trimmedEmail = targetEmail.trim().toLowerCase();
      if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
        return const Failure('Email người nhận không hợp lệ.');
      }

      if (!['view', 'edit'].contains(permissionLevel)) {
        return const Failure('Mức quyền chỉ có thể là "view" hoặc "edit".');
      }

      // Tìm thông tin người nhận theo email
      final targetUser = await _repository.findUserByEmail(trimmedEmail);
      if (targetUser == null) {
        return Failure(
          'Không tìm thấy người dùng có email "$trimmedEmail" trong hệ thống.',
        );
      }

      // Tránh tự chia sẻ cho chính mình
      if (targetUser.id == currentUserId) {
        return const Failure(
          'Bạn là chủ sở hữu của tài liệu này, không cần cấp quyền cho chính mình.',
        );
      }

      // Ghi nhận quyền
      await _repository.shareDocument(
        documentId: document.id,
        targetUserId: targetUser.id,
        permissionLevel: permissionLevel,
      );

      return const Success(null);
    } catch (e) {
      return Failure('Lỗi khi chia sẻ tài liệu: $e', e);
    }
  }

  /// 4. Thu hồi quyền chia sẻ tài liệu
  Future<Result<void>> revokePermission({
    required DocumentModel document,
    required String targetUserId,
    required String currentUserId,
  }) async {
    try {
      // Chỉ chủ sở hữu mới có quyền thu hồi
      if (document.ownerId != currentUserId) {
        return const Failure(
          'Từ chối truy cập: Chỉ chủ sở hữu mới có quyền thu hồi quyền chia sẻ.',
        );
      }

      await _repository.revokePermission(
        documentId: document.id,
        targetUserId: targetUserId,
      );

      return const Success(null);
    } catch (e) {
      return Failure('Lỗi khi thu hồi quyền: $e', e);
    }
  }

  /// 5. Lấy danh sách phân quyền của một tài liệu
  Future<Result<List<DocumentPermissionModel>>> getDocumentPermissions({
    required String documentId,
  }) async {
    try {
      final perms = await _repository.getDocumentPermissions(documentId);
      return Success(perms);
    } catch (e) {
      return Failure('Không thể lấy danh sách quyền: $e', e);
    }
  }

  /// 6. Upload tệp mới
  Future<Result<DocumentModel>> uploadDocument({
    required String ownerId,
    required String title,
    String? description,
    required File file,
  }) async {
    try {
      if (title.trim().isEmpty) {
        return const Failure('Tiêu đề tài liệu không được để trống.');
      }

      final doc = await _repository.uploadAndCreateDocument(
        ownerId: ownerId,
        title: title,
        description: description,
        file: file,
      );

      return Success(doc);
    } catch (e) {
      return Failure('Lỗi khi tải lên tài liệu: $e', e);
    }
  }

  /// 7. Xóa tài liệu
  Future<Result<void>> deleteDocument({
    required DocumentModel document,
    required String currentUserId,
  }) async {
    try {
      if (document.ownerId != currentUserId) {
        return const Failure(
          'Từ chối truy cập: Bạn không có quyền xóa tài liệu của người khác.',
        );
      }

      await _repository.deleteDocument(
        documentId: document.id,
        storagePath: document.storagePath,
      );

      return const Success(null);
    } catch (e) {
      return Failure('Lỗi khi xóa tài liệu: $e', e);
    }
  }
}
