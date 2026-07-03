import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class TambahGuruScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const TambahGuruScreen({super.key, this.onNavigateToTab});

  @override
  State<TambahGuruScreen> createState() => _TambahGuruScreenState();
}

class _TambahGuruScreenState extends State<TambahGuruScreen> {
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _handleTambahGuru() async {
    final nama = _namaController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (nama.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar('Mohon lengkapi semua data', Colors.red);
      return;
    }

    if (!_isValidEmail(email)) {
      _showSnackBar('Format email tidak valid', Colors.red);
      return;
    }

    if (password.length < 6) {
      _showSnackBar('Password minimal 6 karakter', Colors.red);
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar('Konfirmasi password tidak cocok', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Gunakan AuthProvider.registerGuruByAdmin() yang akan:
      // 1. Buat akun guru via Firebase Auth
      // 2. Simpan data guru ke Firestore
      // 3. Re-login admin otomatis dengan kredensial yang tersimpan
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.registerGuruByAdmin(email, password, nama);

      if (!mounted) return;

      if (success) {
        // Bersihkan form
        _namaController.clear();
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();

        // Tampilkan dialog sukses
        await _showSuccessDialog();

        // Kembali ke dashboard admin (tab index 0)
        widget.onNavigateToTab?.call(0);
      } else {
        _showSnackBar('Gagal menambah guru. Kredensial admin tidak tersedia. Silakan login ulang.', Colors.red);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String pesan;
      switch (e.code) {
        case 'email-already-in-use':
          pesan = 'Email sudah terdaftar. Gunakan email lain.';
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
      _showSnackBar(pesan, Colors.red);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      String pesan;
      if (e.code == 'permission-denied') {
        pesan = 'Firestore rules menolak akses. Deploy ulang firestore.rules ke Firebase.';
      } else {
        pesan = 'Error Firestore: ${e.message}';
      }
      _showSnackBar(pesan, Colors.red);
    } catch (e) {
      if (!mounted) return;
      // Jika gagal karena session, arahkan ke login
      _showSnackBar('Registrasi gagal. Silakan coba lagi.', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSuccessDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon sukses
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 44,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Guru Berhasil Ditambahkan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Akun guru baru telah berhasil dibuat.\nGuru dapat login menggunakan email yang didaftarkan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.muted.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text(
                      'Kembali ke Dashboard',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Data Guru')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Buat akun guru baru. Session admin akan tetap aman dan kembali ke dashboard setelah berhasil.',
                      style: TextStyle(color: AppColors.primary.withValues(alpha: 0.8), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Nama Lengkap
            const Text('Nama Lengkap', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _namaController,
              decoration: const InputDecoration(
                hintText: 'Masukan nama lengkap guru',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 20),

            // Email
            const Text('Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'Masukan email guru',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 20),

            // Password
            const Text('Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: 'Masukkan password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Konfirmasi Password
            const Text('Konfirmasi Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                hintText: 'Ulangi password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Tombol Simpan
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleTambahGuru,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.person_add),
                label: Text(
                  _isLoading ? 'Menyimpan...' : 'Buat Akun Guru',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
