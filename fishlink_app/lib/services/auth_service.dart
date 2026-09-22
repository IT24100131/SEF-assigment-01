import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../models/auth_response.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  // Check if user is logged in on app start
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        // Optionally verify token with backend here
        _isAuthenticated = true;
      }
    } catch (e) {
      _isAuthenticated = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final authResponse = await ApiService.login(email, password);
      _currentUser = authResponse.user;
      _isAuthenticated = true;
      
      // Store user data
      await _storage.write(key: 'user_data', value: authResponse.user.toJson().toString());
      
    } catch (e) {
      _isAuthenticated = false;
      _currentUser = null;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(RegisterRequest request) async {
    _isLoading = true;
    notifyListeners();

    try {
      final authResponse = await ApiService.register(request);
      _currentUser = authResponse.user;
      _isAuthenticated = true;
      
      // Store user data
      await _storage.write(key: 'user_data', value: authResponse.user.toJson().toString());
      
    } catch (e) {
      _isAuthenticated = false;
      _currentUser = null;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await ApiService.logout();
      await _storage.deleteAll();
      _currentUser = null;
      _isAuthenticated = false;
    } catch (e) {
      // Even if logout fails on server, clear local data
      _currentUser = null;
      _isAuthenticated = false;
      await _storage.deleteAll();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}