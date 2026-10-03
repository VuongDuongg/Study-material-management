# BÁO CÁO BÀI TẬP LỚN THỰC HÀNH (TH1)
## Đề tài: Xây dựng Ứng dụng Quản lý Tài liệu Học tập theo Kiến trúc Cashew (Local-First Flutter App)

---

**Thông tin bài tập:**
- **Môn học:** Phát triển Ứng dụng Di động
- **Mã bài tập:** TH1 - Cashew Architecture
- **Nền tảng triển khai:** Flutter (Hỗ trợ đa nền tảng: Windows Desktop, Web, Android, iOS)
- **Công nghệ lưu trữ & State Management:** Drift ORM, SQLite Native / Wasm, Provider Pattern, Material You (Material 3)

---

## 1. Phân tích yêu cầu chức năng và thiết kế sơ đồ luồng dữ liệu

### 1.1. Các chức năng cốt lõi (Core Features)
Hệ thống được thiết kế hướng tới việc quản lý tài liệu học tập cá nhân toàn diện, hoạt động độc lập và không phụ thuộc vào kết nối Internet (Local-First):

| Mã chức năng | Tên chức năng | Mô tả chi tiết |
| :--- | :--- | :--- |
| **UC-01** | **Thêm tài liệu (Create)** | Cho phép người dùng nhập Tiêu đề, Môn học, Loại tài liệu (Slide, Bài tập, Sách, Tài liệu khác), Đường dẫn lưu trữ (File local hoặc URL trực tuyến), và Thời gian tạo. |
| **UC-02** | **Xem danh sách (Read)** | Hiển thị danh sách tài liệu trực quan dưới dạng thẻ (Card) với thiết kế Material You, sắp xếp theo thời gian mới nhất. |
| **UC-03** | **Tìm kiếm thời gian thực (Search)** | Tìm kiếm nhanh theo từ khóa xuất hiện trong Tiêu đề hoặc Môn học với độ trễ gần như bằng 0. |
| **UC-04** | **Lọc tài liệu (Filter)** | Lọc danh mục tài liệu bằng Filter Chips và lọc động theo danh sách các Môn học hiện có trong cơ sở dữ liệu. |
| **UC-05** | **Chỉnh sửa tài liệu (Update)** | Cho phép cập nhật thông tin tài liệu đã lưu mà vẫn giữ nguyên khóa chính (Primary Key). |
| **UC-06** | **Xóa tài liệu an toàn (Delete)** | Xóa tài liệu khỏi bộ nhớ cục bộ kèm hộp thoại Modal xác nhận nhằm phòng tránh thao tác nhầm lẫn. |
| **UC-07** | **Mở tài liệu (Launch)** | Tích hợp mở trực tiếp file cục bộ trên máy tính hoặc liên kết URL tới tài liệu thông qua `FileService`. |
| **UC-08** | **Chế độ Sáng / Tối (Theme Mode)** | Hỗ trợ chuyển đổi giao diện linh hoạt giữa Light Mode và Dark Mode dựa trên bảng màu Material You. |

---

### 1.2. Thiết kế sơ đồ luồng di chuyển dữ liệu (Data Flow)

Kiến trúc Cashew hoạt động dựa trên cơ chế luồng dữ liệu một chiều khép kín (**Unidirectional Reactive Data Flow**):

```
       +--------------------------------------------------------+
       |                  Tầng Giao Diện (UI)                   |
       |  (HomeScreen, AddEditDocumentScreen, DocumentCard, ...) |
       +--------------------------------------------------------+
                   |                                ^
     (1) User Input / Action            (5) Reactive Stream
     (Thêm/Sửa/Xóa/Tìm kiếm)               (Cập nhật UI tự động)
                   |                                |
                   v                                |
       +--------------------------------------------------------+
       |               Tầng Nghiệp Vụ (Logic Layer)             |
       |        (DocumentProvider, ThemeProvider, ...)          |
       +--------------------------------------------------------+
                   |                                ^
     (2) Companion / Query Params        (4) Stream<List<Doc>>
                   |                                |
                   v                                |
       +--------------------------------------------------------+
       |                Tầng Dữ Liệu (Data Layer)               |
       |             (AppDatabase - Drift ORM / SQLite)         |
       +--------------------------------------------------------+
                   |                                ^
            (3) SQL Query / C-FFI          Raw SQLite Result
                   v                                |
       +--------------------------------------------------------+
       |             Cơ Sở Dữ Liệu Cục Bộ (SQLite Storage)       |
       |          (study_documents.sqlite / IndexedDB)          |
       +--------------------------------------------------------+
```

#### Chi tiết các bước trong luồng dữ liệu:
1. **User Action:** Người dùng thực hiện thao tác trên màn hình (nhập từ khóa tìm kiếm, ấn nút Lưu form hoặc bấm Xóa).
2. **Logic Dispatching:** UI gọi phương thức tương ứng của `DocumentProvider` (ví dụ: `addDocument()`, `setSearchQuery()`). Tầng UI không trực tiếp tạo truy vấn SQL.
3. **Data Persistence:** `DocumentProvider` chuyển đổi dữ liệu thành các thực thể Drift (`DocumentsCompanion`) và gọi tầng `AppDatabase`. Tầng Data thực thi câu lệnh SQL xuống engine SQLite thông qua Native C-FFI hoặc Web Wasm.
4. **Reactive Notification:** Ngay khi dữ liệu bảng `Documents` có sự biến động (INSERT/UPDATE/DELETE), luồng `watchFilteredDocuments()` của Drift lập tức tự động kích hoạt truy vấn ngầm và đẩy mảng dữ liệu mới ra Stream.
5. **UI Re-rendering:** `DocumentProvider` nhận kết quả từ Stream, cập nhật danh sách nội bộ và gọi `notifyListeners()`. Các widget đăng ký lắng nghe (qua `context.watch<DocumentProvider>()`) tự động build lại dữ liệu mới nhất mà không yêu cầu người dùng phải tải lại trang (Zero-Refresh).

---

## 2. Thiết lập cấu trúc thư mục và phân lớp hệ thống theo chuẩn Cashew

### 2.1. Cây thư mục dự án (`lib/`)

```
lib/
├── data/                                 # [DATA LAYER] Quản lý lưu trữ cục bộ
│   ├── database/                         # Cấu hình Drift ORM & Kết nối cơ sở dữ liệu
│   │   ├── connection/                   # Kết nối đa nền tảng (Cross-platform Connection)
│   │   │   ├── connection.dart           # Conditional Export (phân giải Web vs Native)
│   │   │   ├── native.dart               # Cấu hình SQLite Native (Desktop / Mobile)
│   │   │   ├── web.dart                  # Cấu hình Drift Web (Wasm + Web Worker)
│   │   │   └── unsupported.dart          # Fallback cho môi trường không hỗ trợ
│   │   ├── app_database.dart             # Lớp AppDatabase, DAO và các câu lệnh CRUD
│   │   └── app_database.g.dart           # Mã nguồn do build_runner / drift_dev tự động sinh
│   └── models/                           # Định nghĩa Schema & Data Classes
│       └── documents.dart                # Bảng Documents (id, title, subject, category, ...)
│
├── logic/                                # [LOGIC LAYER] Nghiệp vụ & State Management
│   ├── providers/                        # Các StateNotifier / ChangeNotifier
│   │   ├── document_provider.dart        # Quản lý State CRUD, Filter, Search, Reactive Stream
│   │   └── theme_provider.dart           # Quản lý ThemeMode (Light/Dark/System)
│   └── services/                         # Tiện ích bổ trợ (I/O, ngoại vi)
│       └── file_service.dart             # Xử lý mở đường dẫn file hoặc link trực tuyến
│
├── ui/                                   # [UI LAYER] Giao diện người dùng Material You
│   ├── screens/                          # Màn hình chức năng
│   │   ├── home_screen.dart              # Màn hình chính (Search, Filter, List view)
│   │   └── add_edit_document_screen.dart # Màn hình biểu mẫu Thêm / Sửa tài liệu
│   └── widgets/                          # Các thành phần tái sử dụng
│       ├── document_card.dart            # Thẻ hiển thị thông tin chi tiết từng tài liệu
│       ├── filter_bar.dart               # Thanh Filter Chips phân loại và lọc môn học
│       └── empty_state_view.dart         # Giao diện thông báo khi danh sách rỗng
│
└── main.dart                             # Khởi tạo DI, cấu hình Theme và Root App
```

### 2.2. Nguyên tắc phân lớp và tính đóng gói (Encapsulation)

Kiến trúc Cashew thiết lập 3 quy tắc phân lớp nghiêm ngặt:

1. **Tính độc lập của Data Layer (Local Data Independence):**
   - Tầng `data/` không được phép import bất kỳ thành phần nào từ tầng `logic/` hay `ui/`.
   - Chịu trách nhiệm duy nhất: định nghĩa schema bảng dữ liệu (`documents.dart`), cấu hình driver kết nối SQLite phù hợp với từng nền tảng, và cung cấp các hàm truy vấn nguyên tử (Atomic CRUD).
2. **Tính đóng gói của Logic Layer (Business Encapsulation):**
   - Tầng `logic/` đứng làm cầu nối trung gian (Mediator). Lớp `DocumentProvider` nhận `AppDatabase` thông qua kỹ thuật **Dependency Injection** trong constructor.
   - Toàn bộ trạng thái (danh sách tài liệu, từ khóa tìm kiếm, bộ lọc được chọn, trạng thái loading) đều là biến private (`_documents`, `_searchQuery`,...) và chỉ được đọc qua các Getters. Việc thay đổi dữ liệu bắt buộc phải thông qua các phương thức công khai.
3. **Tầng UI thụ động (Passive UI Layer):**
   - Tuyệt đối **không** viết các câu lệnh SQL, Drift DAO hay truy cập file I/O trực tiếp trong các Widget của tầng `ui/`.
   - Tầng UI chỉ hiển thị dữ liệu lấy từ Provider và chuyển các thao tác của người dùng thành các lời gọi hàm xuống Provider.

---

## 3. Triển khai các chức năng cốt lõi (CRUD)

### 3.1. Định nghĩa bảng dữ liệu (Data Schema Definition)
Tại `lib/data/models/documents.dart`, bảng `Documents` được định nghĩa thông qua DSL của Drift ORM:

```dart
import 'package:drift/drift.dart';

class Documents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  TextColumn get subject => text().withLength(min: 1, max: 100)();
  TextColumn get category => text().withLength(min: 1, max: 50)();
  TextColumn get filePath => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

### 3.2. Hiện thực hóa các thao tác CRUD trong `AppDatabase`

#### Thêm mới (Create):
Sử dụng `DocumentsCompanion` để đảm bảo tính an toàn kiểu dữ liệu và tự động sinh giá trị khóa chính `id`:
```dart
Future<int> insertDocument(DocumentsCompanion doc) {
  return into(documents).insert(doc);
}
```

#### Đọc & Tìm kiếm phản ứng thời gian thực (Read & Reactive Search):
Tận dụng cơ chế `watch()` của Drift để tạo một `Stream` phát ra danh sách dữ liệu mới mỗi khi cơ sở dữ liệu có thay đổi:
```dart
Stream<List<Document>> watchFilteredDocuments({
  String searchQuery = '',
  String? subjectFilter,
  String? categoryFilter,
}) {
  return (select(documents)
        ..where((t) {
          final predicates = <Expression<bool>>[];

          // Tìm kiếm không phân biệt hoa thường theo tiêu đề hoặc môn học
          if (searchQuery.trim().isNotEmpty) {
            final queryPattern = '%${searchQuery.trim().toLowerCase()}%';
            predicates.add(
              t.title.lower().like(queryPattern) |
                  t.subject.lower().like(queryPattern),
            );
          }

          // Lọc theo môn học
          if (subjectFilter != null && subjectFilter.isNotEmpty && subjectFilter != 'Tất cả') {
            predicates.add(t.subject.equals(subjectFilter));
          }

          // Lọc theo thể loại tài liệu
          if (categoryFilter != null && categoryFilter.isNotEmpty && categoryFilter != 'Tất cả') {
            predicates.add(t.category.equals(categoryFilter));
          }

          return predicates.isEmpty ? const Constant(true) : predicates.reduce((a, b) => a & b);
        })
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
      .watch();
}
```

#### Chỉnh sửa (Update):
Thay thế toàn bộ bản ghi theo khóa chính:
```dart
Future<bool> updateDocument(Document doc) {
  return update(documents).replace(doc);
}
```

#### Xóa (Delete):
Xóa an toàn theo định danh duy nhất (ID):
```dart
Future<int> deleteDocumentById(int id) {
  return (delete(documents)..where((t) => t.id.equals(id))).go();
}
```

### 3.3. Tầng Logic kết nối Stream (`DocumentProvider`)
Tại `lib/logic/providers/document_provider.dart`, Provider quản lý việc lắng nghe Subscription từ database stream:

```dart
void _initStream() {
  _subscription?.cancel();
  _subscription = _database
      .watchFilteredDocuments(
        searchQuery: _searchQuery,
        subjectFilter: _selectedSubject,
        categoryFilter: _selectedCategory,
      )
      .listen((data) {
        _documents = data;
        _isLoading = false;
        notifyListeners(); // Thông báo UI vẽ lại
      });
}
```

---

## 4. Kiểm thử tính đúng đắn của việc phân tách logic và xử lý thực tế trên Windows Desktop

### 4.1. Giải quyết bài toán phân quyền & đường dẫn thư mục lưu trữ trên Windows (`SqliteException(14)`)
Trong quá trình triển khai thực tế trên môi trường Windows Desktop, khi sử dụng hàm mặc định `getApplicationDocumentsDirectory()`, hệ thống phát sinh lỗi:
```text
SqliteException(14): while opening the database, unable to open database file, unable to open database file (code 14)
```

#### Nguyên nhân kỹ thuật:
1. **Xung đột đường dẫn chứa ký tự tiếng Việt có dấu:** Trên nhiều máy tính Windows cài đặt bản địa hóa tiếng Việt hoặc liên kết tài khoản Microsoft, thư mục tài liệu thực tế trỏ về `C:\Users\Admin\OneDrive\Tài liệu`. Driver SQLite C-FFI khi mở đường dẫn chứa ký tự Unicode có dấu sẽ gặp lỗi phân giải.
2. **Cơ chế OneDrive Files-On-Demand:** Dịch vụ đám mây OneDrive tự động khóa (lock) hoặc đồng bộ tệp khiến tiến trình ứng dụng bị từ chối quyền truy cập file (`Access Denied`).

#### Giải pháp khắc phục triệt để trong `lib/data/database/connection/native.dart`:
Chuyển đổi thư mục lưu trữ sang `getApplicationSupportDirectory()` kết hợp với việc kiểm tra và tự động khởi tạo thư mục đệ quy:
```dart
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    Directory dbFolder;
    try {
      // getApplicationSupportDirectory trỏ tới C:\Users\<User>\AppData\Local\<App>
      // Đảm bảo 100% đường dẫn là ký tự ASCII chuẩn, không bị OneDrive can thiệp
      dbFolder = await getApplicationSupportDirectory();
    } catch (_) {
      dbFolder = await getTemporaryDirectory();
    }

    if (!await dbFolder.exists()) {
      await dbFolder.create(recursive: true);
    }

    final file = File(p.join(dbFolder.path, 'study_documents.sqlite'));
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    return NativeDatabase(file);
  });
}
```

### 4.2. Kiểm thử Unit Test cho tính độc lập của tầng dữ liệu
Để chứng minh tính đóng gói và độc lập, bộ kiểm thử tự động tại `test/widget_test.dart` được khởi tạo chạy trên cơ sở dữ liệu ảo trong bộ nhớ RAM (`NativeDatabase.memory()`), không phụ thuộc vào hệ thống tệp đĩa cứng và UI:

```dart
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('Kiểm tra thêm và truy vấn tài liệu trong AppDatabase', () async {
    final companion = DocumentsCompanion.insert(
      title: 'Slide Bài 1',
      subject: 'Lập trình di động',
      category: 'Slide',
      filePath: 'https://example.com/slide1.pdf',
    );

    final id = await db.insertDocument(companion);
    expect(id, isPositive);

    final docs = await db.watchAllDocuments().first;
    expect(docs.length, 1);
    expect(docs.first.title, 'Slide Bài 1');
    expect(docs.first.subject, 'Lập trình di động');
  });
}
```

**Kết quả thực thi kiểm thử:**
```text
00:00 +0: loading test/widget_test.dart
00:00 +0: Kiểm tra thêm và truy vấn tài liệu trong AppDatabase
00:00 +1: All tests passed!
```
- Lệnh `flutter analyze`: **0 warnings, 0 issues found**.
- Lệnh `flutter test`: **100% Passed**.

---

## 5. Đóng gói mã nguồn và báo cáo giải trình kiến trúc Cashew

### 5.1. Hướng dẫn dọn dẹp mã nguồn và chuẩn bị đóng gói

Trước khi nộp bài hoặc chia sẻ mã nguồn, cần thực hiện dọn dẹp các tệp build tạm thời có dung lượng lớn (`build/`, `.dart_tool/`):

1. **Dọn dẹp thư mục build:**
   ```powershell
   flutter clean
   ```
2. **Khôi phục các gói phụ thuộc:**
   ```powershell
   flutter pub get
   ```
3. **Sinh lại mã nguồn ORM nếu cần thiết:**
   ```powershell
   dart run build_runner build --delete-conflicting-outputs
   ```
4. **Kiểm tra chất lượng mã nguồn lần cuối trước khi nén zip:**
   ```powershell
   flutter analyze
   flutter test
   ```
5. **Nén thư mục dự án:** Nén toàn bộ thư mục `th1/` (loại trừ thư mục `build/` nếu có) thành định dạng `.zip` để nộp bài.

---

### 5.2. Giải trình tổng kết về mô hình kiến trúc Cashew (Local-First)

#### Ưu điểm nổi bật của mô hình Local-First:
1. **Bảo mật và Quyền riêng tư tuyệt đối:**
   - Dữ liệu tài liệu học tập, đường dẫn tài liệu cá nhân được lưu trữ trực tiếp 100% trên thiết bị người dùng thông qua SQLite cục bộ. Không có rủi ro bị rò rỉ dữ liệu hoặc nghe lén qua mạng trung gian.
2. **Hoạt động Offline hoàn toàn:**
   - Ứng dụng khởi động tức thì, thao tác đọc/ghi có độ trễ gần bằng 0 (Zero-latency). Người dùng có thể học tập, tra cứu tài liệu ở bất kỳ đâu ngay cả khi không có kết nối Internet.
3. **Không phụ thuộc Server & Tiết kiệm chi phí vận hành:**
   - Không tốn chi phí thuê máy chủ, duy trì Cloud Database backend hay lo ngại việc sập dịch vụ trung tâm.
4. **Độ ổn định và Khả năng chịu lỗi cao:**
   - Nhờ tách biệt ranh giới giữa Data - Logic - UI, việc nâng cấp cơ sở dữ liệu (Database Migrations) hay thay đổi giao diện không ảnh hưởng chéo đến các thành phần khác.

#### Định hướng mở rộng trong tương lai:
- **Đồng bộ hóa P2P / CRDT (Conflict-free Replicated Data Types):** Triển khai cơ chế đồng bộ dữ liệu giữa các thiết bị của cùng một người dùng (điện thoại và máy tính) thông qua mạng LAN nội bộ hoặc giao thức Peer-to-Peer mà vẫn không cần máy chủ trung tâm.
- **Trích xuất nội dung và Tìm kiếm toàn văn (Full-Text Search - FTS5):** Tích hợp SQLite FTS5 extension để tìm kiếm không chỉ trong tiêu đề mà còn quét sâu vào nội dung tệp văn bản.
- **Tích hợp xem tài liệu tại chỗ (In-app Document Viewer):** Tích hợp PDF Reader và Markdown Viewer trực tiếp ngay trong giao diện ứng dụng.

---
*Báo cáo được hoàn thành và nghiệm thu trên hệ thống Flutter SDK 3.x - Đáp ứng toàn diện các tiêu chí kiến trúc Cashew Local-First.*
