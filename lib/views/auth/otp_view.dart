import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../controllers/auth_controller.dart';
import 'reset_password_view.dart';

class OtpView extends StatefulWidget {
  final ApiService apiService;
  final String email;

  /// true  = alur lupa password (Reset Password)
  /// false = alur registrasi (Verify OTP)
  final bool isForgotPassword;

  const OtpView({
    super.key,
    required this.apiService,
    required this.email,
    required this.isForgotPassword,
  });

  @override
  State<OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<OtpView> {
  late AuthController _controller;
  final _formKey = GlobalKey<FormState>();

  // 6 kotak OTP — controller & focusnode per digit
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  Timer? _timer;
  int _secondsRemaining = 60;

  @override
  void initState() {
    super.initState();
    _controller = AuthController(apiService: widget.apiService);
    _controller.addListener(_updateState);
    _startTimer();
  }

  void _startTimer() {
    _secondsRemaining = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _timer?.cancel();
          }
        });
      }
    });
  }

  void _updateState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _controller.removeListener(_updateState);
    _controller.dispose();
    super.dispose();
  }

  /// Gabung semua digit menjadi 1 string OTP
  String get _otpCode => _otpControllers.map((c) => c.text).join();

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final otp = _otpCode;

    if (widget.isForgotPassword) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResetPasswordView(
              apiService: widget.apiService,
              email: widget.email,
              otpCode: otp,
            ),
          ),
        );
      }
    } else {
      final result = await _controller.verifyOtp(widget.email, otp);
      if (result['status'] == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Verifikasi berhasil! Silakan login.',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF10B981), width: 1),
              ),
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    }
  }

  Future<void> _handleResendOtp() async {
    if (_secondsRemaining > 0) return;

    Map<String, dynamic> result;
    if (widget.isForgotPassword) {
      result = await _controller.forgotPassword(widget.email);
    } else {
      result = await _controller.resendOtp(widget.email);
    }

    if (result['status'] == 200) {
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand Icon
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 56,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.isForgotPassword ? 'Reset Password' : 'Verifikasi Email',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kode OTP 6 digit dikirim ke\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),

                // Main Glassmorphism Form Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ======================================
                        // OTP Box Input (6 Kotak) - Responsif
                        // ======================================
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // Hitung lebar kotak agar pas di semua ukuran layar
                            const double hPadding = 4.0; // padding kiri + kanan per kotak
                            final double boxWidth = ((constraints.maxWidth - hPadding * 2 * 6) / 6)
                                .clamp(34.0, 52.0);
                            final double boxHeight = (boxWidth * 1.25).clamp(44.0, 62.0);
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                6,
                                (index) => _buildOtpBox(index, boxWidth, boxHeight, hPadding),
                              ),
                            );
                          },
                        ),

                        // OTP validation error
                        FormField<String>(
                          validator: (_) {
                            if (_otpCode.length < 6) return 'Masukkan 6 digit kode OTP';
                            return null;
                          },
                          builder: (state) {
                            if (state.hasError) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  state.errorText!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),

                        const SizedBox(height: 24),

                        // Status Message
                        _buildStatusIndicator(),
                        const SizedBox(height: 20),

                        // Submit Button
                        _buildSubmitButton(),

                        const SizedBox(height: 16),
                        _buildResendLink(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── OTP Box ──────────────────────────────────────────────
  Widget _buildOtpBox(int index, double boxWidth, double boxHeight, double hPadding) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPadding),
      child: SizedBox(
        width: boxWidth,
        height: boxHeight,
        child: TextFormField(
          controller: _otpControllers[index],
          focusNode: _otpFocusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: GoogleFonts.firaCode(
            color: Colors.white,
            fontSize: (boxWidth * 0.45).clamp(16.0, 22.0),
            fontWeight: FontWeight.bold,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: const Color(0xFF0F172A).withOpacity(0.6),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.12), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF10B981), width: 2.0),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2.0),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (val) {
            if (val.isNotEmpty) {
              // Maju ke kotak berikutnya
              if (index < 5) {
                FocusScope.of(context).requestFocus(_otpFocusNodes[index + 1]);
              } else {
                // Tutup keyboard setelah kotak terakhir
                _otpFocusNodes[index].unfocus();
              }
            }
          },
          onEditingComplete: () {},
          // Deteksi backspace untuk mundur ke kotak sebelumnya
          onTap: () {
            _otpControllers[index].selection = TextSelection.fromPosition(
              TextPosition(offset: _otpControllers[index].text.length),
            );
          },
        ),
      ),
    );
  }


  // ── Status Indicator ──────────────────────────────────────
  Widget _buildStatusIndicator() {
    if (_controller.statusMessage == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _controller.isSuccessMessage
            ? const Color(0xFF10B981).withOpacity(0.1)
            : Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _controller.isSuccessMessage
              ? const Color(0xFF10B981).withOpacity(0.3)
              : Colors.redAccent.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _controller.isSuccessMessage ? Icons.check_circle_outline : Icons.error_outline,
            color: _controller.isSuccessMessage ? const Color(0xFF10B981) : Colors.redAccent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _controller.statusMessage!,
              style: GoogleFonts.outfit(
                color: _controller.isSuccessMessage
                    ? const Color(0xFF34D399)
                    : const Color(0xFFFCA5A5),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit Button ─────────────────────────────────────────
  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: _controller.isLoading
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: _controller.isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF10B981).withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _controller.isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Verifikasi Kode',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  // ── Resend OTP Link ───────────────────────────────────────
  Widget _buildResendLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Tidak menerima kode?',
          style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 12.5),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: (_secondsRemaining > 0 || _controller.isLoading) ? null : _handleResendOtp,
          child: Text(
            _secondsRemaining > 0 ? 'Kirim Ulang (${_secondsRemaining}s)' : 'Kirim Ulang',
            style: GoogleFonts.outfit(
              color: (_secondsRemaining > 0 || _controller.isLoading)
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF06B6D4),
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
