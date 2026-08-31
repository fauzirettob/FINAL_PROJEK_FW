import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../providers/auth_provider.dart';
import '../../services/toast_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/awesome_dialogs.dart';
import '../../models/jadwal_pelajaran.dart';

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
  List<String> _selectedKelas = [];
  String? _selectedWaliKelas;
  bool _isWaliKelas = false; // true = daftar sebagai Wali Kelas

  // Daftar kelas
  static const List<String> _daftarKelas = ['10', '11', '12'];
  static const int _warnaKelas = 0xFF1565C0; // Biru
  static const int _warnaWaliKelas = 0xFFFF9800; // Orange

  /// Mata pelajaran yang di-derive otomatis berdasarkan kelas yang dipilih
  List<String> get _autoMapel => getMapelByMultipleKelas(_selectedKelas);

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

    if (_selectedKelas.isEmpty) {
      _showToast('Pilih minimal satu kelas yang diajar', color: Colors.red);
      return;
    }

    if (_isWaliKelas && _selectedWaliKelas == null) {
      _showToast('Pilih kelas untuk dijadikan Wali Kelas', color: Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final mapelList = _autoMapel;
      final success = await authProvider.registerGuruByAdmin(email, password, nama,
          nip: nip, mapelList: mapelList, kelasList: _selectedKelas,
          waliKelas: _selectedWaliKelas);

      if (!mounted) return;

      if (success) {
        // Data wali kelas sudah tersimpan dari registerGuruByAdmin

        _nipController.clear();
        _namaController.clear();
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        setState(() {
        _selectedKelas = [];
        _selectedWaliKelas = null;
        _isWaliKelas = false;
        });
        await _showSuccessDialog();
      } else {
        _showToast('Gagal menambah guru. Kredensial admin tidak tersedia.', color: Colors.red);
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
        pesan = 'Firestore rules menolak akses.';
      } else {
        pesan = 'Error Firestore: ${e.message}';
      }
      _showToast(pesan, color: Colors.red);
    } catch (e) {
      if (!mounted) return;
      _showToast('Registrasi gagal. Silakan coba lagi.', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
                      'Pilih kelas untuk guru. Mata pelajaran akan otomatis ditentukan berdasarkan jadwal.',
                      style: TextStyle(color: AppColors.primary.withValues(alpha: 0.8), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ═══ PILIHAN ROLE ═══
            const Text('Daftar Sebagai', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              'Pilih role guru yang ingin didaftarkan',
              style: TextStyle(color: AppColors.muted.withValues(alpha: 0.7), fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // Guru Biasa
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _isWaliKelas = false;
                      _selectedWaliKelas = null;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: !_isWaliKelas
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: !_isWaliKelas ? AppColors.primary : AppColors.border,
                          width: !_isWaliKelas ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: !_isWaliKelas
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : AppColors.muted.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.school_rounded,
                              size: 28,
                              color: !_isWaliKelas ? AppColors.primary : AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Guru',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: !_isWaliKelas ? AppColors.primary : AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Mengajar mata pelajaran',
                            style: TextStyle(
                              fontSize: 11,
                              color: !_isWaliKelas
                                  ? AppColors.primary.withValues(alpha: 0.7)
                                  : AppColors.muted,
                            ),
                          ),
                          if (!_isWaliKelas) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '✓ Dipilih',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Wali Kelas
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isWaliKelas = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isWaliKelas
                            ? Color(_warnaWaliKelas).withValues(alpha: 0.1)
                            : AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isWaliKelas ? Color(_warnaWaliKelas) : AppColors.border,
                          width: _isWaliKelas ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: _isWaliKelas
                                  ? Color(_warnaWaliKelas).withValues(alpha: 0.15)
                                  : AppColors.muted.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.star_rounded,
                              size: 28,
                              color: _isWaliKelas ? Color(_warnaWaliKelas) : AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Wali Kelas',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _isWaliKelas ? Color(_warnaWaliKelas) : AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Mengajar + Kelola Kelas',
                            style: TextStyle(
                              fontSize: 11,
                              color: _isWaliKelas
                                  ? Color(_warnaWaliKelas).withValues(alpha: 0.7)
                                  : AppColors.muted,
                            ),
                          ),
                          if (_isWaliKelas) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Color(_warnaWaliKelas).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '⭐ Dipilih',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFF9800),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
            const SizedBox(height: 24),

            // ═══ KELAS ═══
            const Text('Kelas yang Diajar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              'Ketuk kategori untuk membuka, lalu pilih kelas. Mapel otomatis ditentukan.',
              style: TextStyle(color: AppColors.muted.withValues(alpha: 0.7), fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _daftarKelas.map((kelas) {
                final isSelected = _selectedKelas.contains(kelas);
                final warna = Color(_warnaKelas);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_selectedKelas.contains(kelas)) {
                        _selectedKelas.remove(kelas);
                        if (_selectedWaliKelas == kelas) {
                          _selectedWaliKelas = null;
                        }
                      } else {
                        _selectedKelas.add(kelas);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? warna.withValues(alpha: 0.15)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? warna : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          size: 16,
                          color: isSelected ? warna : AppColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Kelas $kelas',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? warna : AppColors.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_selectedKelas.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${_selectedKelas.length} kelas dipilih',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),

            // ═══ MATA PELAJARAN (AUTO-DERIVED) ═══
            if (_selectedKelas.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Mata Pelajaran (Otomatis)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Berdasarkan jadwal untuk kelas: ${_selectedKelas.join(", ")}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.muted.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _autoMapel.map((mapel) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, size: 12, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                mapel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ═══ WALI KELAS ═══
            if (_isWaliKelas && _selectedKelas.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(_warnaWaliKelas).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Color(_warnaWaliKelas).withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFF9800)),
                        const SizedBox(width: 8),
                        const Text(
                          'Pilih Kelas Wali Kelas',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFFFF9800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pilih kelas yang akan diampu sebagai wali kelas',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedKelas.map((kelas) {
                        final isSelected = _selectedWaliKelas == kelas;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedWaliKelas = isSelected ? null : kelas;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFF9800).withValues(alpha: 0.15)
                                  : AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFFF9800) : AppColors.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                                  size: 20,
                                  color: isSelected ? const Color(0xFFFF9800) : AppColors.muted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Kelas $kelas',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? const Color(0xFFFF9800) : AppColors.foreground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              if (_selectedWaliKelas != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFF9800)),
                      const SizedBox(width: 6),
                      Text(
                        'Wali Kelas $_selectedWaliKelas',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF9800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],

            // Tombol Simpan
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleTambahGuru,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isLoading)
                      const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    else
                      const Icon(Icons.person_add),
                    const SizedBox(width: 8),
                    Text(
                      _isLoading ? 'Menyimpan...' : (_isWaliKelas ? 'Buat Akun Wali Kelas' : 'Buat Akun Guru'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
