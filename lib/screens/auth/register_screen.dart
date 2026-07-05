import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/skeleton_loader.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passController.text;
    final confirmPassword = _confirmPassController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mohon lengkapi semua data")),
      );
      return;
    }

    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Format email tidak valid")),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password minimal 6 karakter")),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Konfirmasi password tidak cocok")),
      );
      return;
    }

    // Capture AuthProvider sebelum async pertama
    final authProvider = context.read<AuthProvider>();

    // Cek jumlah admin yang sudah ada (maksimal 3)
    try {
      final adminCount = await FirestoreService().getAdminCount();
      if (adminCount >= 3) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text("Pendaftaran admin dibatasi maksimal 3 akun. Hubungi admin lain untuk info lebih lanjut."),
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint('RegisterScreen: Gagal cek jumlah admin: $e');
    }

    setState(() => _isLoading = true);

    try {
      await authProvider.register(email, password, name, role: 'admin');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text("Akun Admin berhasil dibuat! Silakan login."),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String pesan;
      switch (e.code) {
        case 'email-already-in-use':
          pesan = 'Email sudah terdaftar. Gunakan email lain atau login.';
          break;
        case 'weak-password':
          pesan = 'Password terlalu lemah. Minimal 6 karakter.';
          break;
        case 'invalid-email':
          pesan = 'Format email tidak valid.';
          break;
        default:
          pesan = e.message ?? 'Gagal membuat akun. Coba lagi.';
      }
      debugPrint('RegisterScreen: FirebaseAuthException [${e.code}]: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(pesan),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      debugPrint('RegisterScreen: FirebaseException [${e.code}]: ${e.message}');
      String pesan;
      if (e.code == 'permission-denied') {
        pesan = 'Firestore rules menolak akses. Deploy ulang firestore.rules ke Firebase.';
      } else if (e.code == 'unavailable') {
        pesan = 'Firestore tidak dapat dijangkau. Periksa koneksi internet.';
      } else if (e.code == 'not-found') {
        pesan = 'Database Firestore belum dibuat. Buat di Firebase Console > Firestore Database.';
      } else {
        pesan = 'Error Firebase: ${e.message}. Coba deploy ulang firestore.rules.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(pesan),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('RegisterScreen: Error: $e');
      final pesan = e.toString().contains('Akun admin')
          ? e.toString()
          : 'Registrasi gagal: ${e.toString()}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(pesan),
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

  Widget _buildForm() {
    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),

          // Header — khusus Admin
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.admin_panel_settings,
                      size: 40, color: Colors.deepOrange),
                ),
                const SizedBox(height: 16),
                Text(
                  "Daftar Admin Baru",
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Buat akun administrator untuk mengelola aplikasi",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const SizedBox(height: 24),

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
                  hintText: "Masukkan Nama",
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
                  hintText: "Masukkan email",
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
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      "Daftar Admin",
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

class RegisterSkeleton extends StatelessWidget {
  const RegisterSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
