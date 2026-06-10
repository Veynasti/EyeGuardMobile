import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthController extends ChangeNotifier {
  final ApiService apiService;

  AuthController({required this.apiService});

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;

  bool _isSuccessMessage = false;
  bool get isSuccessMessage => _isSuccessMessage;

  bool _obscurePassword = true;
  bool get obscurePassword => _obscurePassword;

  void setObscurePassword(bool val) {
    _obscurePassword = val;
    notifyListeners();
  }

  void toggleObscurePassword() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void setStatus(String? message, {bool isSuccess = false}) {
    _statusMessage = message;
    _isSuccessMessage = isSuccess;
    notifyListeners();
  }

  void clearStatus() {
    _statusMessage = null;
    _isSuccessMessage = false;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    setLoading(true);
    clearStatus();
    try {
      final result = await apiService.login(email, password);
      if (result['status'] == 200) {
        setStatus('Login Berhasil!', isSuccess: true);
      } else {
        final errorMsg = result['body']['error'] ?? 'Email atau password salah';
        setStatus(errorMsg);
      }
      return result;
    } catch (e) {
      setStatus('Terjadi kesalahan koneksi ke server.');
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    setLoading(true);
    clearStatus();
    try {
      final result = await apiService.register(name, email, password);
      if (result['status'] == 201) {
        setStatus('Registrasi berhasil! Kode OTP dikirim ke email.', isSuccess: true);
      } else {
        setStatus(result['body']['error'] ?? 'Registrasi gagal. Coba lagi.');
      }
      return result;
    } catch (e) {
      setStatus('Terjadi kesalahan koneksi ke server.');
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String otpCode) async {
    setLoading(true);
    clearStatus();
    try {
      final result = await apiService.verifyOtp(email, otpCode);
      if (result['status'] == 200) {
        setStatus('Verifikasi berhasil! Silakan login.', isSuccess: true);
      } else {
        setStatus(result['body']['error'] ?? 'OTP tidak valid atau kadaluarsa.');
      }
      return result;
    } catch (e) {
      setStatus('Terjadi kesalahan koneksi ke server.');
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    setLoading(true);
    clearStatus();
    try {
      final result = await apiService.forgotPassword(email);
      if (result['status'] == 200) {
        setStatus('OTP untuk reset password dikirim ke email.', isSuccess: true);
      } else {
        setStatus(result['body']['error'] ?? 'Gagal mengirim OTP.');
      }
      return result;
    } catch (e) {
      setStatus('Terjadi kesalahan koneksi ke server.');
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<Map<String, dynamic>> resetPassword(String email, String otpCode, String newPassword) async {
    setLoading(true);
    clearStatus();
    try {
      final result = await apiService.resetPassword(email, otpCode, newPassword);
      if (result['status'] == 200) {
        setStatus('Password berhasil direset! Silakan login.', isSuccess: true);
      } else {
        setStatus(result['body']['error'] ?? 'Reset password gagal. Periksa kembali OTP Anda.');
      }
      return result;
    } catch (e) {
      setStatus('Terjadi kesalahan koneksi ke server.');
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<Map<String, dynamic>> resendOtp(String email) async {
    setLoading(true);
    clearStatus();
    try {
      final result = await apiService.resendOtp(email);
      if (result['status'] == 200) {
        setStatus('Kode OTP berhasil dikirim ulang!', isSuccess: true);
      } else if (result['status'] == 429) {
        // Rate limit — tampilkan pesan cooldown dari server
        setStatus(result['body']['error'] ?? 'Tunggu sebentar sebelum meminta kode baru.');
      } else {
        setStatus(result['body']['error'] ?? 'Gagal mengirim ulang OTP.');
      }
      return result;
    } catch (e) {
      setStatus('Gagal menghubungi server.');
      rethrow;
    } finally {
      setLoading(false);
    }
  }
}
