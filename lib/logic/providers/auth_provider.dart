import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/cloud_document_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  StreamSubscription<User?>? _userSubscription;

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  String? _lastIdToken;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _currentUser = _authService.currentUser;
    _userSubscription = _authService.authStateChanges.listen((user) {
      _currentUser = user;
      notifyListeners();
    });
  }

  // Getters
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get lastIdToken => _lastIdToken;

  /// Đăng nhập bằng Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithGoogle();
      if (result != null) {
        _lastIdToken = result.idToken;
        final user = result.credential.user;
        if (user != null && user.email != null) {
          // Tự động đồng bộ người dùng vào bảng users trên Supabase
          final cloudService = CloudDocumentService();
          await cloudService.syncUserToSupabase(
            uid: user.uid,
            email: user.email!,
            displayName: user.displayName,
            photoUrl: user.photoURL,
          );
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // Người dùng tự hủy
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Đăng xuất
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      _lastIdToken = null;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
