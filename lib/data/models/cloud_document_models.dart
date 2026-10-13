/// Model thông tin người dùng được lưu trên Supabase
class UserModel {
  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      email: map['email'] as String,
      fullName: map['full_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
    };
  }
}

/// Model tài liệu lưu trên Cloud (Supabase & Firebase Storage)
class DocumentModel {
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
  
  // Quyền của người dùng hiện tại trên tài liệu: 'owner', 'edit', 'view'
  final String userAccessLevel;

  const DocumentModel({
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
    this.userAccessLevel = 'view',
  });

  bool get isOwner => userAccessLevel == 'owner';
  bool get canEdit => isOwner || userAccessLevel == 'edit';

  factory DocumentModel.fromMap(
    Map<String, dynamic> map, {
    String currentUserId = '',
    String? explicitPermission,
  }) {
    final owner = map['owner_id'] as String;
    String accessLevel = 'view';
    if (owner == currentUserId) {
      accessLevel = 'owner';
    } else if (explicitPermission != null) {
      accessLevel = explicitPermission;
    }

    return DocumentModel(
      id: map['id'] as String,
      ownerId: owner,
      title: map['title'] as String,
      description: map['description'] as String?,
      fileUrl: map['file_url'] as String,
      storagePath: map['storage_path'] as String,
      fileSize: (map['file_size'] as num?)?.toInt() ?? 0,
      mimeType: map['mime_type'] as String? ?? 'application/octet-stream',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      userAccessLevel: accessLevel,
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

/// Model phân quyền chia sẻ tài liệu
class DocumentPermissionModel {
  final String id;
  final String documentId;
  final String userId;
  final String permissionLevel; // 'view' hoặc 'edit'
  final DateTime grantedAt;
  final String? userEmail;
  final String? userFullName;

  const DocumentPermissionModel({
    required this.id,
    required this.documentId,
    required this.userId,
    required this.permissionLevel,
    required this.grantedAt,
    this.userEmail,
    this.userFullName,
  });

  factory DocumentPermissionModel.fromMap(Map<String, dynamic> map) {
    String? email;
    String? name;

    if (map['users'] is Map<String, dynamic>) {
      final userMap = map['users'] as Map<String, dynamic>;
      email = userMap['email'] as String?;
      name = userMap['full_name'] as String?;
    }

    return DocumentPermissionModel(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      userId: map['user_id'] as String,
      permissionLevel: map['permission_level'] as String,
      grantedAt: DateTime.parse(map['granted_at'] as String),
      userEmail: email,
      userFullName: name,
    );
  }
}
