import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Kết quả đóng gói sau khi đăng nhập thành công
class AuthResult {
  final UserCredential credential;
  final String? idToken;

  const AuthResult({
    required this.credential,
    required this.idToken,
  });
}

/// Service quản lý toàn bộ luồng xác thực Firebase & Google Sign-In
class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: <String>['email', 'profile'],
            );

  /// Lắng nghe trạng thái người dùng (Real-time Auth State)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Người dùng hiện tại
  User? get currentUser => _auth.currentUser;

  /// Đăng nhập bằng tài khoản Google
  /// 
  /// - Kích hoạt popup chọn tài khoản Google
  /// - Lấy Google OAuth credentials (accessToken & idToken)
  /// - Xác thực với Firebase Authentication
  /// - Lấy Firebase ID Token
  /// Trả về [AuthResult] hoặc `null` nếu người dùng hủy luồng đăng nhập.
  Future<AuthResult?> signInWithGoogle() async {
    try {
      // 1. Kích hoạt giao diện đăng nhập Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // Trường hợp người dùng hủy đăng nhập
      if (googleUser == null) {
        developer.log('Người dùng đã hủy đăng nhập Google.', name: 'AuthService');
        return null;
      }

      // 2. Lấy thông tin OAuth Tokens từ Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Tạo credential cho Firebase
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Đăng nhập vào Firebase
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      // 5. Lấy Firebase ID Token
      final String? firebaseIdToken =
          await userCredential.user?.getIdToken(true);

      developer.log(
        'Đăng nhập Google thành công: UID=${userCredential.user?.uid}, Email=${userCredential.user?.email}',
        name: 'AuthService',
      );

      return AuthResult(
        credential: userCredential,
        idToken: firebaseIdToken,
      );
    } on FirebaseAuthException catch (e) {
      developer.log(
        'Lỗi FirebaseAuthException: [${e.code}] ${e.message}',
        error: e,
        name: 'AuthService',
      );
      switch (e.code) {
        case 'account-exists-with-different-credential':
          throw Exception(
              'Email này đã được liên kết với một phương thức đăng nhập khác.');
        case 'invalid-credential':
          throw Exception('Thông tin xác thực không hợp lệ hoặc đã hết hạn.');
        case 'operation-not-allowed':
          throw Exception(
              'Đăng nhập Google chưa được kích hoạt trên Firebase Console.');
        case 'user-disabled':
          throw Exception('Tài khoản người dùng đã bị vô hiệu hóa.');
        case 'network-request-failed':
          throw Exception('Lỗi mạng. Vui lòng kiểm tra lại kết nối internet.');
        default:
          throw Exception(e.message ?? 'Đăng nhập Firebase thất bại.');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Lỗi không xác định khi đăng nhập Google',
        error: e,
        stackTrace: stackTrace,
        name: 'AuthService',
      );
      throw Exception('Đã xảy ra lỗi: $e');
    }
  }

  /// Đăng xuất khỏi Firebase và xóa phiên lưu trữ Google Sign-In
  Future<void> signOut() async {
    try {
      await Future.wait([
        _googleSignIn.signOut(),
        _auth.signOut(),
      ]);
      developer.log('Đã đăng xuất thành công.', name: 'AuthService');
    } catch (e) {
      developer.log('Lỗi khi đăng xuất: $e', error: e, name: 'AuthService');
      throw Exception('Không thể đăng xuất: $e');
    }
  }
}
