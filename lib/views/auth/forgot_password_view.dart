import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../controllers/auth_controller.dart';
import 'otp_view.dart';

class ForgotPasswordView extends StatefulWidget {
  final ApiService apiService;

  const ForgotPasswordView({super.key, required this.apiService});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  late AuthController _controller;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AuthController(apiService: widget.apiService);
    _controller.addListener(_updateState);
  }

  void _updateState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _emailController.dispose();
    _controller.removeListener(_updateState);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();

    final result = await _controller.forgotPassword(email);
    if (result['status'] == 200) {
      if (mounted) {
        // Navigate to OTP Screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpView(
              apiService: widget.apiService,
              email: email,
              isForgotPassword: true,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [


          // Central Card Container
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo
                    const Icon(
                      Icons.remove_red_eye_outlined,
                      size: 64,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'EyeGuard',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      'Smart Shield for Healthy Eyes',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF94A3B8),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 32),

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
                            _buildFormHeader('Lupa Sandi', 'Kami akan mengirimkan OTP untuk mereset sandi Anda'),
                            const SizedBox(height: 20),
                            _buildEmailField(),
                            _buildStatusIndicator(),
                            const SizedBox(height: 24),
                            _buildSubmitButton('Kirim Kode OTP'),
                            const SizedBox(height: 16),
                            _buildSwitchFormLink(
                              'Batal?',
                              'Kembali ke Login',
                              () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFormHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.outfit(
            color: const Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
      keyboardType: TextInputType.emailAddress,
      decoration: _buildInputDecoration(
        hint: 'user@example.com',
        label: 'Alamat Email',
        icon: Icons.email_outlined,
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) return 'Email wajib diisi';
        final reg = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (!reg.hasMatch(val.trim())) return 'Format email tidak valid';
        return null;
      },
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF10B981), size: 20),
      labelText: label,
      labelStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13),
      hintText: hint,
      hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF0F172A).withOpacity(0.5),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildStatusIndicator() {
    if (_controller.statusMessage == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
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
                  color: _controller.isSuccessMessage ? const Color(0xFF34D399) : const Color(0xFFFCA5A5),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(String text) {
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
        onPressed: _controller.isLoading ? null : _handleForgotPassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF10B981).withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
                text,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildSwitchFormLink(String preText, String linkText, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            preText,
            style: GoogleFonts.outfit(
              color: const Color(0xFF94A3B8),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _controller.isLoading ? null : onTap,
            child: Text(
              linkText,
              style: GoogleFonts.outfit(
                color: const Color(0xFF10B981),
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
