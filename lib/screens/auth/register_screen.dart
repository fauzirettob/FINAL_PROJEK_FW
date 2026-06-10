import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/skeleton_loader.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controllers untuk mengambil input dari text field
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _isLoading = false;
  bool _obscureText = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  // Validasi email sederhana
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Fungsi untuk menangani proses registrasi
  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passController.text;
    final confirmPassword = _confirmPassController.text;

    // Validasi field kosong
    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mohon lengkapi semua data")),
      );
      return;
    }

    // Validasi format email
    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Format email tidak valid")),
      );
      return;
    }

    // Validasi minimal password
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password minimal 6 karakter")),
      );
      return;
    }

    // Validasi konfirmasi password
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Konfirmasi password tidak cocok")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Panggil fungsi register dari AuthProvider
      final authProvider = context.read<AuthProvider>();
      await authProvider.register(email, password, name);

      // Setelah registrasi, user di-sign-out otomatis oleh AuthProvider.
      // User harus login manual ke halaman Login.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text("Akun berhasil dibuat! Silakan login."),
        ),
      );
      // Kembali ke halaman Login agar user bisa login manual.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      // Tangani error (misal: email sudah terdaftar)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text("Registrasi gagal: ${e.toString()}"),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: _isLoading
              ? const SkeletonLoader(
                  key: ValueKey('skeleton'),
                  child: RegisterSkeleton(),
                )
              : _buildForm(),
        ),
      ),
    );
  }

  /// Form registrasi lengkap
  Widget _buildForm() {
    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),

          // Header / Judul
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_alt_1,
                      size: 40, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  "Buat Akun Guru",
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Daftar untuk mulai mengelola absensi",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Form Input
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Nama Lengkap",
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: "Contoh: Bpk. Budi Santoso",
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Email",
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: "guru@sekolah.sch.id",
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Password",
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _passController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  hintText: "Masukkan password",
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () {
                      setState(() => _obscureText = !_obscureText);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Konfirmasi Password",
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPassController,
                obscureText: _obscureText,
                decoration: const InputDecoration(
                  hintText: "Ulangi password",
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Tombol Register
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      "Daftar Sekarang",
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 24),

          // Link ke Login
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Sudah punya akun?",
                  style: TextStyle(color: AppColors.muted)),
              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text(
                  "Masuk",
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
