import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api_service.dart';
import '../core/biometric_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final BiometricService _bioService = BiometricService();

  bool _isAuthenticated = false;
  bool _isBiometricLocked = false;
  bool _isLoading = false;
  String? _errorMessage;
  String _userName = "User";
  String _userEmail = "";
  
  bool _isFingerprintEnrolled = false;
  bool _isFaceLockEnrolled = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get isBiometricLocked => _isBiometricLocked;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get userName => _userName;
  String get userEmail => _userEmail;
  bool get isFingerprintEnrolled => _isFingerprintEnrolled;
  bool get isFaceLockEnrolled => _isFaceLockEnrolled;
  bool get hasAnyBiometricEnrolled => _isFingerprintEnrolled || _isFaceLockEnrolled;

  AuthProvider() {
    _checkInitialAuth();
    refreshBiometrics();
  }

  Future<void> refreshBiometrics() async {
    _isFingerprintEnrolled = await _bioService.isFingerprintEnrolled();
    _isFaceLockEnrolled = await _bioService.isFaceLockEnrolled();
    notifyListeners();
  }

  Future<void> deleteFaceData() async {
    final userId = await _storage.read(key: 'user_id');
    await _bioService.deleteFaceLock(userId: userId);
    await refreshBiometrics();
  }

  Future<void> deleteFingerprintData() async {
    final userId = await _storage.read(key: 'user_id');
    await _bioService.deleteFingerprint(userId: userId);
    await refreshBiometrics();
  }

  Future<void> resetAllBiometrics() async {
    final userId = await _storage.read(key: 'user_id');
    await _bioService.resetBiometrics(userId: userId);
    await refreshBiometrics();
  }

  void unlockBiometric() {
    _isBiometricLocked = false;
    notifyListeners();
  }

  void lockApp() {
    if (hasAnyBiometricEnrolled) {
      _isBiometricLocked = true;
      notifyListeners();
    }
  }

  Future<void> _checkInitialAuth() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final userId = await _storage.read(key: 'user_id');
      if (userId != null) {
        try {
          await _bioService.syncBiometricsFromCloud(userId);
        } catch (_) {}
      }
      _userName = await _storage.read(key: 'user_name') ?? "User";
      _userEmail = await _storage.read(key: 'user_email') ?? "";
      _isAuthenticated = true;
      await refreshBiometrics();
      if (hasAnyBiometricEnrolled) {
        _isBiometricLocked = true;
      }
      notifyListeners();
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      final didAuthenticate = await _bioService.verifyFingerprint();
      if (didAuthenticate) {
        final token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          _isAuthenticated = true;
          _isBiometricLocked = false;
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint("Biometrics error: $e");
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.login(email, password);
      _userName = res['full_name'] ?? email.split('@')[0];
      _userEmail = res['email'] ?? email;
      _isAuthenticated = true;
      await refreshBiometrics();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
          _errorMessage = "Cannot connect to server at ${_api.baseUrl}.\nCheck Server Settings (gear icon at top).";
        } else if (e.response?.statusCode == 401) {
          _errorMessage = "Invalid email or password.";
        } else {
          final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
          _errorMessage = detail ?? "Server response error (${e.response?.statusCode})";
        }
      } else {
        // Strip "Exception: " prefix for clean error display
        String msg = e.toString();
        if (msg.startsWith('Exception: ')) {
          msg = msg.substring(11);
        }
        _errorMessage = msg;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password, String fullName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.register(email, password, fullName);
      _userName = res['full_name'] ?? fullName;
      _userEmail = res['email'] ?? email;
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
          _errorMessage = "Cannot connect to server at ${_api.baseUrl}.\nCheck Server Settings (gear icon at top).";
        } else if (e.response?.statusCode == 400) {
          final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
          _errorMessage = detail ?? "Registration failed. Email may already be in use.";
        } else {
          _errorMessage = "Server error: ${e.message}";
        }
      } else {
        // Strip "Exception: " prefix for clean error display
        String msg = e.toString();
        if (msg.startsWith('Exception: ')) {
          msg = msg.substring(11);
        }
        _errorMessage = msg;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    _isAuthenticated = false;
    _userName = "User";
    _userEmail = "";
    notifyListeners();
  }
}
