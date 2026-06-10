import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../controllers/auth_controller.dart';
import 'otp_view.dart';

class RegisterView extends StatefulWidget {
  final ApiService apiService;

  const RegisterView({super.key, required this.apiService});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  late AuthController _controller;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscureConfirm = true;

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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _controller.removeListener(_updateState);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final result = await _controller.register(name, email, password);
    if (result['status'] == 201) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpView(
              apiService: widget.apiService,
              email: email,
              isForgotPassword: false,
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


          // Main Scrollable Content
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
                      size: 56,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'EyeGuard',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      'Buat Akun Baru',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Form Card
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
                            _buildFormHeader('Daftar Baru', 'Isi data di bawah untuk memulai'),
                            const SizedBox(height: 20),

                            // Nama Lengkap
                            _buildTextField(
                              controller: _nameController,
                              label: 'Nama Lengkap',
                              hint: 'John Doe',
                              icon: Icons.person_outline,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Nama wajib diisi';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Email
                            _buildTextField(
                              controller: _emailController,
                              label: 'Alamat Email',
                              hint: 'user@example.com',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Email wajib diisi';
                                final reg = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
                                if (!reg.hasMatch(val.trim())) return 'Format email tidak valid';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Kata Sandi
                            _buildTextField(
                              controller: _passwordController,
                              label: 'Kata Sandi',
                              hint: '••••••••',
                              icon: Icons.lock_outline,
                              obscureText: _controller.obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _controller.obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                onPressed: _controller.toggleObscurePassword,
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Kata sandi wajib diisi';
                                final reg = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$');
                                if (!reg.hasMatch(val)) {
                                  return 'Min. 8 karakter, huruf besar, kecil, dan angka';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Ulangi Kata Sandi
                            _buildTextField(
                              controller: _confirmPasswordController,
                              label: 'Ulangi Kata Sandi',
                              hint: '••••••••',
                              icon: Icons.lock_reset_outlined,
                              obscureText: _obscureConfirm,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Ulangi kata sandi wajib diisi';
                                if (val != _passwordController.text) return 'Kata sandi tidak cocok';
                                return null;
                              },
                            ),

                            // Status indicator
                            _buildStatusIndicator(),
                            const SizedBox(height: 20),

                            // Submit button
                            _buildSubmitButton('Daftar Sekarang'),
                            const SizedBox(height: 16),

                            // Link ke login
                            _buildSwitchFormLink(
                              'Sudah memiliki akun?',
                              'Masuk',
                              () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF10B981), size: 20),
        suffixIcon: suffixIcon,
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
      ),
      validator: validator,
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
                  color: _controller.isSuccessMessage
                      ? const Color(0xFF34D399)
                      : const Color(0xFFFCA5A5),
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
        onPressed: _controller.isLoading ? null : _handleRegister,
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
            style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 12.5),
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
