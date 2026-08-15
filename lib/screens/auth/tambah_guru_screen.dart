import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../providers/auth_provider.dart';
import '../../services/toast_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/awesome_dialogs.dart';

class TambahGuruScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const TambahGuruScreen({super.key, this.onNavigateToTab});

  @override
  State<TambahGuruScreen> createState() => _TambahGuruScreenState();
}

class _TambahGuruScreenState extends State<TambahGuruScreen> {
  final _nipController = TextEditingController();
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nipController.dispose();
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
    final nip = _nipController.text.trim();
    final nama = _namaController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (nip.isEmpty || nama.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showToast('Mohon lengkapi semua data', color: Colors.red);
      return;
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(nip)) {
      _showToast('NIP harus berupa angka', color: Colors.red);
      return;
    }

    if (!_isValidEmail(email)) {
      _showToast('Format email tidak valid', color: Colors.red);
      return;
    }

    if (password.length < 6) {
      _showToast('Password minimal 6 karakter', color: Colors.red);
      return;
    }

    if (password != confirmPassword) {
      _showToast('Konfirmasi password tidak cocok', color: Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Gunakan AuthProvider.registerGuruByAdmin() yang akan:
      // 1. Buat akun guru via Firebase Auth
      // 2. Simpan data guru ke Firestore
      // 3. Re-login admin otomatis dengan kredensial yang tersimpan
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.registerGuruByAdmin(email, password, nama, nip: nip);

      if (!mounted) return;

      if (success) {
        // Bersihkan form
        _nipController.clear();
        _namaController.clear();
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();

        // Tampilkan dialog sukses — admin tetap di halaman ini
        await _showSuccessDialog();
      } else {
        _showToast('Gagal menambah guru. Kredensial admin tidak tersedia. Silakan coba lagi.', color: Colors.red);
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
      _showToast(pesan, color: Colors.red);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      String pesan;
      if (e.code == 'permission-denied') {
        pesan = 'Firestore rules menolak akses. Deploy ulang firestore.rules ke Firebase.';
      } else {
        pesan = 'Error Firestore: ${e.message}';
      }
      _showToast(pesan, color: Colors.red);
    } catch (e) {
      if (!mounted) return;
      // Jika gagal karena session, arahkan ke login
      _showToast('Registrasi gagal. Silakan coba lagi.', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Popup sukses bergaya popup notifikasi WA: centang menggambar diri +
  // partikel perayaan + tombol untuk menambah guru lagi.
  Future<void> _showSuccessDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const AwesomeSuccessDialog(
        title: 'Guru Berhasil Ditambahkan',
        subtitle: 'Akun guru baru telah berhasil dibuat.\n'
            'Guru dapat login menggunakan email yang didaftarkan.',
        confirmText: 'Tambah Guru Lagi',
      ),
    );
  }

  void _showToast(String message, {Color? color}) {
    ToastService.show(
      context,
      message: message,
      backgroundColor: color ?? Colors.green.shade600,
      icon: color != null && color != Colors.green ? Icons.error_outline : Icons.check_circle,
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
                      'Buat akun guru baru. Setelah berhasil, form akan dikosongkan dan Anda dapat menambah guru lagi.',
                      style: TextStyle(color: AppColors.primary.withValues(alpha: 0.8), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // NIP
            const Text('NIP', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _nipController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(18),
              ],
              decoration: const InputDecoration(
                hintText: 'Masukan NIP guru',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 20),

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
