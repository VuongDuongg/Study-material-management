# BÁO CÁO KỸ THUẬT: TÍCH HỢP HỆ THỐNG QUẢN LÝ VÀ CHIA SẺ TÀI LIỆU (FLUTTER + FIREBASE + SUPABASE)

---

## 1. THIẾT LẬP DỰ ÁN FIREBASE & TÍCH HỢP ĐĂNG NHẬP GOOGLE

### 1.1. Cấu hình Native & Firebase Console
- **Android SHA-1 Fingerprint**:
  - Trích xuất mã `SHA1` thông qua tác vụ Gradle: `./gradlew signingReport`.
  - Cấu hình mã vân tay vào phần **Project Settings > Your apps (Android)** trên Firebase Console với package name `com.example.th1`.
- **Cấu hình Gradle Native**:
  - [android/settings.gradle.kts](file:///d:/Mobile/Th1/th1/android/settings.gradle.kts): Khai báo plugin Google Services `id("com.google.gms.google-services") version "4.4.2" apply false`.
  - [android/app/build.gradle.kts](file:///d:/Mobile/Th1/th1/android/app/build.gradle.kts): Áp dụng plugin `id("com.google.gms.google-services")`.
  - Đặt file `google-services.json` vào thư mục `android/app/`.
- **Thư viện tích hợp**: `firebase_core`, `firebase_auth`, `google_sign_in: ^6.2.2`.

### 1.2. Kiến trúc Service `AuthService` & `AuthProvider`
- **Tệp triển khai**: [lib/logic/services/auth_service.dart](file:///d:/Mobile/Th1/th1/lib/logic/services/auth_service.dart) & [lib/logic/providers/auth_provider.dart](file:///d:/Mobile/Th1/th1/lib/logic/providers/auth_provider.dart).
- **Quy trình xác thực**:
  1. Người dùng bấm **Google Sign-In** -> Popup `google_sign_in` mở để chọn tài khoản.
  2. Lấy `GoogleSignInAuthentication` gồm `accessToken` và `idToken`.
  3. Chuyển đổi thành `OAuthCredential` và xác thực qua `FirebaseAuth.instance.signInWithCredential()`.
  4. Lấy Firebase ID Token và tự động kích hoạt tiến trình đồng bộ người dùng vào cơ sở dữ liệu Supabase.
  5. Đóng gói ngoại lệ: Xử lý các mã lỗi `invalid-credential`, `network-request-failed`, `user-disabled` và trường hợp người dùng hủy đăng nhập.

---

## 2. KIẾN TRÚC LƯU TRỮ FIREBASE STORAGE & KẾT NỐI METADATA SUPABASE

### 2.1. Quy chuẩn cấu trúc đường dẫn lưu trữ (Path Convention)
Đường dẫn file trên Firebase Storage được chuẩn hóa theo định dạng phân cấp:
```text
documents/{owner_id}/{doc_id}/{fileName}
```
- **`owner_id`**: Firebase UID của người tải lên (tránh xung đột và hỗ trợ viết Storage Security Rules).
- **`doc_id`**: Mã định danh duy nhất của tài liệu (UUID v4).
- **`fileName`**: Tên gốc của tệp đính kèm.

### 2.2. Luồng đồng bộ Client (Upload -> Metadata Sync)
- **Tệp triển khai**: [lib/logic/services/cloud_document_service.dart](file:///d:/Mobile/Th1/th1/lib/logic/services/cloud_document_service.dart).
- **Quy trình thực thi**:
  1. Client đọc tệp cục bộ (`File`), sinh `UUID v4` cho tài liệu và trích xuất `mimeType`, `fileSize`.
  2. Gọi `FirebaseStorage.instance.ref().child(storagePath).putFile()` đính kèm Custom Metadata (`ownerId`, `docId`, `originalName`).
  3. Lấy `downloadUrl` từ Firebase Storage Snapshot.
  4. Ghi bản ghi Metadata vào bảng `public.documents` trên Supabase:
     ```json
     {
       "id": "uuid-v4",
       "owner_id": "firebase-uid",
       "title": "Tiêu đề",
       "description": "Mô tả",
       "file_url": "https://firebasestorage.googleapis.com/...",
       "storage_path": "documents/{owner_id}/{doc_id}/{fileName}",
       "file_size": 1048576,
       "mime_type": "application/pdf"
     }
     ```

---

## 3. THIẾT KẾ CƠ SỞ DỮ LIỆU TRÊN SUPABASE (POSTGRESQL)

Tệp script hoàn chỉnh: [supabase_schema.sql](file:///d:/Mobile/Th1/th1/supabase_schema.sql).

### 3.1. Cấu trúc các bảng dữ liệu
1. **Bảng `public.users`**:
   - `id VARCHAR(128) PRIMARY KEY`: Firebase UID.
   - `email VARCHAR(255) UNIQUE NOT NULL`: Địa chỉ email.
   - `full_name VARCHAR(255)`: Tên người dùng.
   - `avatar_url TEXT`: URL ảnh đại diện.
   - `created_at TIMESTAMPTZ DEFAULT now()`: Thời điểm tạo.
2. **Bảng `public.documents`**:
   - `id UUID PRIMARY KEY DEFAULT uuid_generate_v4()`: Khóa chính UUID.
   - `owner_id VARCHAR(128) NOT NULL REFERENCES public.users(id) ON DELETE CASCADE`.
   - `title VARCHAR(255) NOT NULL`, `description TEXT`.
   - `file_url TEXT NOT NULL`, `storage_path TEXT NOT NULL`.
   - `file_size BIGINT`, `mime_type VARCHAR(100)`.
   - `created_at TIMESTAMPTZ`, `updated_at TIMESTAMPTZ`.
3. **Bảng `public.document_permissions`**:
   - `id UUID PRIMARY KEY DEFAULT uuid_generate_v4()`.
   - `document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE`.
   - `user_id VARCHAR(128) NOT NULL REFERENCES public.users(id) ON DELETE CASCADE`.
   - `permission_level VARCHAR(20) CHECK (permission_level IN ('view', 'edit'))`.
   - `granted_at TIMESTAMPTZ DEFAULT now()`.
   - `UNIQUE (document_id, user_id)`: Ngăn chặn cấp quyền trùng lặp.

### 3.2. Chỉ mục tối ưu hóa (Indexes)
- `idx_documents_owner_id`: Tối ưu hóa truy vấn tài liệu theo chủ sở hữu.
- `idx_documents_created_at_desc`: Tối ưu hóa phân trang và sắp xếp tài liệu mới nhất.
- `idx_permissions_document_id` & `idx_permissions_user_id`: Tăng tốc độ truy vấn kiểm tra quyền hạn khi join dữ liệu.

---

## 4. TRIỂN KHAI CRUD, TÌM KIẾM & PHÂN QUYỀN CHIA SẺ

Mã nguồn được phân tách theo Clean Architecture:
- **Repository**: [lib/data/repositories/document_repository.dart](file:///d:/Mobile/Th1/th1/lib/data/repositories/document_repository.dart).
- **Service**: [lib/logic/services/document_service.dart](file:///d:/Mobile/Th1/th1/lib/logic/services/document_service.dart).
- **Result Pattern**: [lib/logic/common/result.dart](file:///d:/Mobile/Th1/th1/lib/logic/common/result.dart).

### 4.1. Chức năng Tìm kiếm (Search)
- Áp dụng toán tử `.or('title.ilike.%query%,description.ilike.%query%')` của Supabase SDK kết hợp tìm kiếm trên tập hợp tài liệu sở hữu và tài liệu được phân quyền truy cập.

### 4.2. Chức năng Cập nhật (Update)
- Kiểm tra quyền hạn trực tiếp tại tầng Client (`doc.canEdit`) trước khi gọi API.
- Cập nhật tiêu đề và mô tả; hệ thống Trigger `trg_documents_updated_at` tự động cập nhật trường `updated_at`.

### 4.3. Chức năng Chia sẻ & Thu hồi quyền (Share & Revoke)
- **Hộp thoại giao diện**: [lib/ui/widgets/share_document_dialog.dart](file:///d:/Mobile/Th1/th1/lib/ui/widgets/share_document_dialog.dart).
- Tra cứu người dùng theo email -> Kiểm tra trùng lặp và không cho phép tự chia sẻ cho chính mình -> `upsert` vào bảng `document_permissions` với quyền `view` hoặc `edit`.
- Thu hồi quyền: Xóa bản ghi trong `document_permissions` theo `document_id` và `user_id`.

---

## 5. THIẾT LẬP CHÍNH SÁCH BẢO MẬT (ROW LEVEL SECURITY - RLS)

Tệp script chính sách RLS: [supabase_rls_policies.sql](file:///d:/Mobile/Th1/th1/supabase_rls_policies.sql).

### 5.1. Kỹ thuật chống vòng lặp đệ quy (Anti-Infinite Recursion)
Để tránh đệ quy chéo giữa bảng `documents` và `document_permissions`, hệ thống sử dụng các hàm bổ trợ **`SECURITY DEFINER`**:
```sql
CREATE OR REPLACE FUNCTION public.is_document_owner(doc_id UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.documents
    WHERE id = doc_id AND owner_id = (auth.uid())::text
  );
$$;

CREATE OR REPLACE FUNCTION public.can_edit_document(doc_id UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.document_permissions
    WHERE document_id = doc_id 
      AND user_id = (auth.uid())::text 
      AND permission_level = 'edit'
  );
$$;
```

### 5.2. Các chính sách RLS chi tiết
- **Bảng `documents`**:
  - `SELECT`: Cho phép nếu `owner_id = auth.uid()` HOẶC có bản ghi quyền tương ứng trong `document_permissions` với mức `view` hoặc `edit`.
  - `INSERT`: Chỉ cho phép khi `owner_id = auth.uid()`.
  - `UPDATE`: Cho phép nếu là chủ sở hữu HOẶC thỏa mãn `public.can_edit_document(id)`.
  - `DELETE`: Nghiêm cấm mọi tài khoản khác, chỉ cho phép chủ sở hữu (`owner_id = auth.uid()`).
- **Bảng `document_permissions`**:
  - `SELECT`: Chỉ cho phép xem quyền nếu là chủ sở hữu của tài liệu đó hoặc chính người được cấp quyền.
  - `INSERT / UPDATE / DELETE`: Bắt buộc thỏa mãn điều kiện `public.is_document_owner(document_id)`.

---

## 6. KIỂM THỬ (TESTING) VỚI 3 TÀI KHOẢN NGƯỜI DÙNG

### 6.1. Thiết lập đối tượng kiểm thử
| Tài khoản | Email | Vai trò trong kịch bản |
| :--- | :--- | :--- |
| **User A** | `duongquocvuon9@gmail.com` | **Chủ sở hữu (Owner)** |
| **User B** | `funnyvuong@gmail.com` | **Người chỉnh sửa (Editor - Quyền 'edit')** |
| **User C** | `duongquocvuonggg@gmail.com` | **Người xem (Viewer - Quyền 'view')** |

### 6.2. Kịch bản & Kết quả xác minh

| STT | Bước kiểm thử | Thao tác thực hiện | Kết quả kỳ vọng | Trạng thái |
| :---: | :--- | :--- | :--- | :---: |
| **1** | **Xác thực & Đồng bộ** | Đăng nhập Google với lần lượt User A, B, C | Cả 3 tài khoản tự động xuất hiện trên bảng `users` của Supabase | **ĐẠT (PASS)** |
| **2** | **Tạo tài liệu** | User A tải lên tài liệu `Tài liệu môn Di Động` | File lưu vào `documents/{UID_A}/{doc_id}/` trên Firebase Storage; bản ghi metadata tạo trên Supabase | **ĐẠT (PASS)** |
| **3** | **Phân quyền chia sẻ** | User A mở dialog: chia sẻ cho User B quyền `edit`, User C quyền `view` | Bảng `document_permissions` ghi nhận 2 bản ghi tương ứng | **ĐẠT (PASS)** |
| **4** | **Kiểm tra quyền User B** | Đăng xuất User A -> Đăng nhập User B | Thấy tài liệu của A chia sẻ; Nhãn hiển thị **"Có quyền sửa"**; Update tiêu đề thành công; Xóa tài liệu bị từ chối | **ĐẠT (PASS)** |
| **5** | **Kiểm tra quyền User C** | Đăng xuất User B -> Đăng nhập User C | Thấy tài liệu của A chia sẻ; Nhãn hiển thị **"Chỉ xem"**; Bấm nút Sửa hoặc Xóa bị RLS từ chối | **ĐẠT (PASS)** |
| **6** | **Thu hồi quyền** | Đăng nhập lại User A, xóa quyền của User C | Dòng quyền của User C bị xóa khỏi `document_permissions`; User C vào app không còn thấy tài liệu | **ĐẠT (PASS)** |
| **7** | **Độc lập tài khoản** | Đăng xuất hoàn toàn về trạng thái chưa login | Màn hình chính phân tách rạch ròi giữa dữ liệu offline cục bộ và dữ liệu đám mây | **ĐẠT (PASS)** |

---

## 7. TỔNG KẾT
Toàn bộ yêu cầu kỹ thuật đã được triển khai hoàn tất trực tiếp trong dự án Flutter, kiểm tra biên dịch đạt chuẩn `flutter analyze` (**0 errors, 0 warnings**) và xác minh thành công trên thiết bị thực tế kết nối qua ADB/scrcpy.
