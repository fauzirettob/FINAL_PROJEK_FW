import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/toast_service.dart';

import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../widgets/awesome_dialogs.dart';
import '../../widgets/tilt3d.dart';
import '../../models/guru.dart';
import '../../models/siswa.dart';
import '../../models/jadwal_pelajaran.dart';
import '../../providers/auth_provider.dart';

class OlahDataScreen extends StatefulWidget {
  final FirestoreService? firestoreService;

  const OlahDataScreen({super.key, this.firestoreService});

  @override
  State<OlahDataScreen> createState() => _OlahDataScreenState();
}

class _OlahDataScreenState extends State<OlahDataScreen> {
  late final FirestoreService _fs = widget.firestoreService ?? FirestoreService();
  String _searchGuru = '';
  List<AttendanceOverride> _activeOverrides = [];
  bool _isLoadingOverrides = false;

  // ─── Edit Data Guru ──────────────────────────────────────────
  Future<void> _editGuru(Guru guru) async {
    final nipController = TextEditingController(text: guru.nip);
    final namaController = TextEditingController(text: guru.nama);
    final emailController = TextEditingController(text: guru.email);
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    List<String> selectedKelas = List<String>.from(guru.kelasList);
    String? selectedWaliKelas = guru.waliKelas;
    final availableKelas = List<String>.from(kategoriKelas);
    // Auto-derive mapel from kelas
    List<String> selectedMapel = getMapelByMultipleKelas(selectedKelas);

    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Form(
            key: formKey,
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: AppColors.warning, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Data Guru',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.foreground,
                              ),
                            ),
                            Text(
                              'Ubah informasi guru',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.border.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 18, color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                // Form Fields
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // NIP
                        const Text('NIP', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: nipController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Masukan NIP guru',
                            prefixIcon: Icon(Icons.badge_outlined, size: 20),
                            isDense: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'NIP tidak boleh kosong';
                            if (!RegExp(r'^[0-9]+$').hasMatch(v.trim())) return 'NIP harus berupa angka';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Nama
                        const Text('Nama Lengkap', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: namaController,
                          decoration: const InputDecoration(
                            hintText: 'Masukan nama lengkap guru',
                            prefixIcon: Icon(Icons.person_outline, size: 20),
                            isDense: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Nama tidak boleh kosong';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Email
                        const Text('Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'Masukan email guru',
                            prefixIcon: Icon(Icons.email_outlined, size: 20),
                            isDense: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Email tidak boleh kosong';
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) return 'Format email tidak valid';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Mata Pelajaran (Auto-Derived)
                        const Text('Mata Pelajaran yang Diajar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          'Otomatis ditentukan berdasarkan kelas yang dipilih',
                          style: TextStyle(color: AppColors.muted.withValues(alpha: 0.7), fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                          ),
                          child: selectedMapel.isEmpty
                              ? const Text(
                                  'Pilih kelas terlebih dahulu',
                                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                                )
                              : Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: selectedMapel.map((mapel) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        mapel,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                        if (selectedMapel.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${selectedMapel.length} mata pelajaran (otomatis)',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Kelas yang Diajar
                        const Text('Kelas yang Diajar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          'Pilih kelas. Mapel otomatis ditentukan dari jadwal.',
                          style: TextStyle(color: AppColors.muted.withValues(alpha: 0.7), fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        if (availableKelas.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              'Belum ada kelas tersedia',
                              style: TextStyle(color: AppColors.muted, fontSize: 12),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: availableKelas.map((kelas) {
                              final isSelected = selectedKelas.contains(kelas);
                              return GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    if (isSelected) {
                                      selectedKelas.remove(kelas);
                                      if (selectedWaliKelas == kelas) {
                                        selectedWaliKelas = null;
                                      }
                                    } else {
                                      selectedKelas.add(kelas);
                                    }
                                    // Auto-update mapel
                                    selectedMapel = getMapelByMultipleKelas(selectedKelas);
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.accent.withValues(alpha: 0.15)
                                        : AppColors.card,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? AppColors.accent : AppColors.border,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                                        size: 16,
                                        color: isSelected ? AppColors.accent : AppColors.muted,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        kelas,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                          color: isSelected ? AppColors.accent : AppColors.foreground,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        if (selectedKelas.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${selectedKelas.length} kelas dipilih',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Wali Kelas
                        const Text('Wali Kelas (Opsional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          'Jadikan guru ini sebagai wali kelas',
                          style: TextStyle(color: AppColors.muted.withValues(alpha: 0.7), fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        if (selectedKelas.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              'Pilih kelas terlebih dahulu',
                              style: TextStyle(color: AppColors.muted, fontSize: 12),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: selectedKelas.map((kelas) {
                              final isSelected = selectedWaliKelas == kelas;
                              return GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    selectedWaliKelas = isSelected ? null : kelas;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFFF9800).withValues(alpha: 0.15)
                                        : AppColors.card,
                                    borderRadius: BorderRadius.circular(10),
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
                                        size: 16,
                                        color: isSelected ? const Color(0xFFFF9800) : AppColors.muted,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        kelas,
                                        style: TextStyle(
                                          fontSize: 12,
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
                        if (selectedWaliKelas != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFF9800)),
                                const SizedBox(width: 4),
                                Text(
                                  'Wali Kelas $selectedWaliKelas',
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
                        const SizedBox(height: 16),
                        // Password Baru (Opsional)
                        const Text('Password Baru (Opsional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          'Kosongkan jika tidak ingin mengubah password',
                          style: TextStyle(color: AppColors.muted.withValues(alpha: 0.7), fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'Masukan password baru',
                            prefixIcon: Icon(Icons.lock_outline, size: 20),
                            isDense: true,
                          ),
                          validator: (v) {
                            if (v != null && v.isNotEmpty && v.length < 6) return 'Password minimal 6 karakter';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Konfirmasi Password
                        const Text('Konfirmasi Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'Ulangi password baru',
                            prefixIcon: Icon(Icons.lock_outline, size: 20),
                            isDense: true,
                          ),
                          validator: (v) {
                            if (passwordController.text.isNotEmpty) {
                              if (v == null || v.isEmpty) return 'Konfirmasi tidak boleh kosong';
                              if (v != passwordController.text) return 'Password tidak cocok';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                // Footer
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        setModalState(() => isLoading = true);
                        Navigator.pop(ctx, {
                          'nip': nipController.text.trim(),
                          'nama': namaController.text.trim(),
                          'email': emailController.text.trim(),
                          'mapelList': selectedMapel,
                          'kelasList': selectedKelas,
                          'waliKelas': selectedWaliKelas,
                          'password': passwordController.text.trim(),
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Simpan Perubahan',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == null) return;

    // ── Step 1: Update data guru di Firestore ──
    try {
      await _fs.updateGuru(guru.id, {
        'nip': result['nip'],
        'nama': result['nama'],
        'email': result['email'],
        'mapelList': result['mapelList'],
        'kelasList': result['kelasList'],
        'waliKelas': result['waliKelas'],
      });
    } catch (e) {
      if (!mounted) return;
      ToastService.show(
        context,
        message: 'Gagal update data guru: $e',
        backgroundColor: Colors.red.shade600,
        icon: Icons.error_outline,
      );
      return;
    }

    // ── Step 2: Update password via Cloud Function (jika diisi) ──
    final newPassword = result['password'] as String?;
    String? passwordError;
    if (newPassword != null && newPassword.isNotEmpty) {
      try {
        final callable = FirebaseFunctions.instance.httpsCallable('resetGuruPassword');
        await callable.call({
          'guruUid': guru.id,
          'newPassword': newPassword,
        });
      } on FirebaseFunctionsException catch (e) {
        debugPrint('resetGuruPassword error [${e.code}]: ${e.message}');
        passwordError = e.message ?? 'Gagal update password';
      } catch (e) {
        debugPrint('resetGuruPassword unexpected error: $e');
        passwordError = 'Gagal update password: $e';
      }
    }

    if (!mounted) return;
    setState(() {}); // Refresh the list

    // ── Step 3: Tampilkan hasil ──
    if (passwordError != null) {
      ToastService.show(
        context,
        message: 'Data guru berhasil diupdate, tapi password gagal: $passwordError',
        backgroundColor: Colors.orange.shade600,
        icon: Icons.warning_amber_rounded,
      );
    } else if (newPassword != null && newPassword.isNotEmpty) {
      ToastService.show(
        context,
        message: 'Data guru & password ${result['nama']} berhasil diupdate',
      );
    } else {
      ToastService.show(
        context,
        message: 'Data guru ${result['nama']} berhasil diupdate',
      );
    }
  }

  // ─── Hapus Guru ─────────────────────────────────────────────
  Future<void> _hapusGuru(Guru guru) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AwesomeConfirmDialog(
        title: 'Hapus Guru',
        message: 'Yakin ingin menghapus akun guru ${guru.nama}?\n\n'
            'Data absensi yang dibuat oleh guru ini tetap tersimpan.',
        icon: Icons.person_off_rounded,
        color: Colors.red,
        confirmText: 'Hapus',
        confirmIcon: Icons.delete_outline,
      ),
    );

    if (confirmed != true) return;

    try {
      await _fs.deleteGuru(guru.id);
      if (!mounted) return;
      ToastService.show(
        context,
        message: 'Guru ${guru.nama} berhasil dihapus',
      );
    } catch (e) {
      if (!mounted) return;
      ToastService.show(
        context,
        message: 'Gagal menghapus: $e',
        backgroundColor: Colors.red.shade600,
        icon: Icons.error_outline,
      );
    }
  }

  // ─── Reset Password Guru ────────────────────────────────────
  Future<void> _resetPasswordGuru(Guru guru) async {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.55,
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Form(
            key: formKey,
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.lock_reset_rounded,
                            color: Colors.orange, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reset Password',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.foreground,
                              ),
                            ),
                            Text(
                              guru.nama,
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.border.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 18, color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                // Form Fields
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Password Baru
                        const Text('Password Baru', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'Masukan password baru',
                            prefixIcon: Icon(Icons.lock_outline, size: 20),
                            isDense: true,
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Password tidak boleh kosong';
                            if (v.length < 6) return 'Password minimal 6 karakter';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Konfirmasi Password
                        const Text('Konfirmasi Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'Ulangi password baru',
                            prefixIcon: Icon(Icons.lock_outline, size: 20),
                            isDense: true,
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Konfirmasi tidak boleh kosong';
                            if (v != passwordController.text) return 'Password tidak cocok';
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                // Footer
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        setModalState(() => isLoading = true);
                        Navigator.pop(ctx, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Reset Password',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != true) return;

    final newPassword = passwordController.text.trim();

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('resetGuruPassword');
      await callable.call({
        'guruUid': guru.id,
        'newPassword': newPassword,
      });
      if (!mounted) return;
      ToastService.show(
        context,
        message: 'Password ${guru.nama} berhasil direset',
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ToastService.show(
        context,
        message: e.message ?? 'Gagal reset password',
        backgroundColor: Colors.red.shade600,
        icon: Icons.error_outline,
      );
    } catch (e) {
      if (!mounted) return;
      ToastService.show(
        context,
        message: 'Gagal reset password: $e',
        backgroundColor: Colors.red.shade600,
        icon: Icons.error_outline,
      );
    }
  }

  // ─── Approval Absensi Ulang Guru ──────────────────────────
  Future<void> _loadActiveOverrides() async {
    setState(() => _isLoadingOverrides = true);
    try {
      final overrides = await _fs.getActiveOverridesForDate(DateTime.now());
      if (mounted) {
        setState(() {
          _activeOverrides = overrides;
          _isLoadingOverrides = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingOverrides = false);
    }
  }

  Future<void> _approveGuruAbsensi() async {
    // Load semua guru
    final allGuru = await _fs.getAllGuru();
    if (!mounted) return;

    if (allGuru.isEmpty) {
      ToastService.show(context, message: 'Tidak ada data guru');
      return;
    }

    final selectedGuru = await showDialog<Guru>(
      context: context,
      builder: (ctx) => _GuruPickerDialog(guruList: allGuru),
    );
    if (selectedGuru == null || !mounted) return;

    // Pilih durasi
    final durasi = await showDialog<int>(
      context: context,
      builder: (ctx) => _DurasiPickerDialog(),
    );
    if (durasi == null || !mounted) return;

    // Pilih kelas + mapel untuk approval
    final kelasMapelResult = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _KelasMapelPickerDialog(
        guru: selectedGuru,
        fs: _fs,
      ),
    );
    if (kelasMapelResult == null || !mounted) return;

    final kelas = kelasMapelResult['kelas']!;
    final mapel = kelasMapelResult['mapel']!;

    try {
      final auth = context.read<AuthProvider>();
      final adminId = auth.admin?.id ?? 'unknown';
      await _fs.overrideAttendanceTime(
        kelas, mapel, DateTime.now(), adminId,
        durationMinutes: durasi,
      );
      if (mounted) {
        ToastService.show(
          context,
          message: '✅ ${selectedGuru.nama} diizinkan absensi ulang $mapel ($durasi menit)',
        );
        _loadActiveOverrides();
      }
    } catch (e) {
      if (mounted) {
        ToastService.show(
          context,
          message: 'Gagal approve: $e',
          backgroundColor: Colors.red.shade600,
          icon: Icons.error_outline,
        );
      }
    }
  }

  Future<void> _revokeOverride(AttendanceOverride override) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AwesomeConfirmDialog(
        title: 'Batalkan Approval',
        message: 'Batalkan approval absensi ulang untuk ${override.mataPelajaran} (Kelas ${override.kelas})?',
        icon: Icons.cancel_outlined,
        color: Colors.red,
        confirmText: 'Batalkan',
        confirmIcon: Icons.close,
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _fs.removeAttendanceTimeOverride(
          override.kelas, override.mataPelajaran, override.tanggal);
      if (mounted) {
        ToastService.show(context, message: 'Approval dibatalkan');
        _loadActiveOverrides();
      }
    } catch (e) {
      if (mounted) {
        ToastService.show(
          context,
          message: 'Gagal: $e',
          backgroundColor: Colors.red.shade600,
          icon: Icons.error_outline,
        );
      }
    }
  }

  // ─── Ekspor Guru ke CSV ─────────────────────────────────
  Future<void> _exportGuru() async {
    await _showLoadingDialog('Menyiapkan data guru...');
    try {
      final allData = await _fs.getAllGuru();
      if (allData.isEmpty) {
        if (!mounted) return;
        Navigator.of(context).pop();
        ToastService.show(
          context,
          message: 'Tidak ada data guru untuk diekspor',
        );
        return;
      }

      final rows = <List<dynamic>>[
        ['No', 'NIP', 'Nama', 'Email', 'Role', 'Tanggal Daftar'],
      ];

      for (int i = 0; i < allData.length; i++) {
        final g = allData[i];
        rows.add([
          i + 1,
          g.nip,
          g.nama,
          g.email,
          g.role,
          DateFormat('dd/MM/yyyy').format(g.createdAt),
        ]);
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      await _simpanDanShare(
        rows: rows,
        filename: 'daftar_guru_${DateFormat('yyyyMMdd').format(DateTime.now())}',
        title: 'Daftar Guru',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor: $e')),
      );
    }
  }

  // ─── Ekspor Siswa ke CSV ────────────────────────────────
  Future<void> _exportSiswa() async {
    await _showLoadingDialog('Menyiapkan data siswa...');
    try {
      final allData = await _fs.getAllSiswa();
      if (allData.isEmpty) {
        if (!mounted) return;
        Navigator.of(context).pop();
        ToastService.show(
          context,
          message: 'Tidak ada data siswa untuk diekspor',
        );
        return;
      }

      final rows = <List<dynamic>>[
        ['No', 'Nama', 'NIS', 'Kelas', 'Nama Orang Tua', 'HP Orang Tua', 'Tanggal Daftar'],
      ];

      for (int i = 0; i < allData.length; i++) {
        final s = allData[i];
        rows.add([
          i + 1,
          s.nama,
          s.nis,
          s.kelas,
          s.namaOrtu,
          s.hpOrtu,
          DateFormat('dd/MM/yyyy').format(s.createdAt),
        ]);
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      await _simpanDanShare(
        rows: rows,
        filename: 'daftar_siswa_${DateFormat('yyyyMMdd').format(DateTime.now())}',
        title: 'Daftar Siswa',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor: $e')),
      );
    }
  }

  // ─── Loading Dialog ─────────────────────────────────────
  Future<void> _showLoadingDialog(String message) async {
    if (!mounted) return;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AwesomeLoadingDialog(message: message),
    );
  }

  // ─── Simpan CSV & Share ─────────────────────────────────
  Future<void> _simpanDanShare({
    required List<List<dynamic>> rows,
    required String filename,
    required String title,
  }) async {
    // Encode ke CSV dengan UTF-8 BOM agar Excel bisa membaca encoding Indonesia
    final csvContent = Csv().encode(rows);

    final bom = utf8.encode('\uFEFF');
    final bytes = [...bom, ...utf8.encode(csvContent)];

    if (kIsWeb) {
      // Untuk web, tampilkan toast bahwa fitur export belum tersedia
      if (!mounted) return;
      ToastService.show(
        context,
        message: 'Export CSV belum didukung di web. Gunakan aplikasi mobile.',
        backgroundColor: Colors.orange.shade600,
        icon: Icons.info_outline,
      );
      return;
    }

    // Simpan ke temporary directory (mobile only)
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename.csv');
    await file.writeAsBytes(bytes);

    if (!mounted) return;

    // Share file via native share sheet
    final xFile = XFile(
      file.path,
      mimeType: 'text/csv',
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        text: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Olah Data'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download_rounded),
            tooltip: 'Ekspor Data',
            onSelected: (value) {
              if (value == 'export_siswa') {
                _exportSiswa();
              } else if (value == 'export_guru') {
                _exportGuru();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_siswa',
                child: ListTile(
                  leading: Icon(Icons.people_alt_rounded, color: AppColors.accent),
                  title: Text('Ekspor Siswa'),
                  subtitle: Text('CSV', style: TextStyle(fontSize: 11)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export_guru',
                child: ListTile(
                  leading: Icon(Icons.person, color: AppColors.warning),
                  title: Text('Ekspor Guru'),
                  subtitle: Text('CSV', style: TextStyle(fontSize: 11)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Stats Row ──────────────────────────────────────
          _buildStatsRow(),
          const SizedBox(height: 12),
          // ─── Approval Absensi Section ───────────────────────
          _buildApprovalSection(),
          const SizedBox(height: 8),
          // ─── Perpindahan Kelas Section ─────────────────────────
          _buildPerpindahanKelasSection(),
          const SizedBox(height: 8),
          // ─── Search ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _searchGuru = v.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Cari guru...',
                prefixIcon: Icon(Icons.search, size: 20),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          // ─── Daftar Guru ─────────────────────────────────────
          Expanded(
            child: _buildGuruList(),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadActiveOverrides();
  }

  // ─── Perpindahan Kelas Section ───────────────────────────────
  Widget _buildPerpindahanKelasSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF8B5CF6), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Perpindahan Kelas',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Pindahkan semua siswa dari satu kelas ke kelas lain',
                        style: TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showPerpindahanKelasDialog,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Pindah', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Dialog Perpindahan Kelas ──────────────────────────────────
  Future<void> _showPerpindahanKelasDialog() async {
    String? dariKelas;
    String? keKelas;
    int jumlahSiswa = 0;
    bool isLoading = false;
    bool isProcessing = false;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF8B5CF6), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Perpindahan Kelas',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.foreground,
                            ),
                          ),
                          Text(
                            'Pindahkan semua siswa dari satu kelas ke kelas lain',
                            style: TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.border.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 18, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Form Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dari Kelas
                      const Text(
                        'Dari Kelas',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: kategoriKelas.map((kelas) {
                          final isSelected = dariKelas == kelas;
                          return GestureDetector(
                            onTap: isProcessing ? null : () async {
                              setModalState(() {
                                dariKelas = isSelected ? null : kelas;
                                keKelas = null;
                                jumlahSiswa = 0;
                              });
                              // Load jumlah siswa
                              if (dariKelas != null) {
                                setModalState(() => isLoading = true);
                                final count = await _fs.getJumlahSiswaPerKelas(dariKelas!);
                                if (ctx.mounted) {
                                  setModalState(() {
                                    jumlahSiswa = count;
                                    isLoading = false;
                                  });
                                }
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                    : AppColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF8B5CF6) : AppColors.border,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                                    size: 18,
                                    color: isSelected ? const Color(0xFF8B5CF6) : AppColors.muted,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Kelas $kelas',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      color: isSelected ? const Color(0xFF8B5CF6) : AppColors.foreground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      // Info jumlah siswa
                      if (dariKelas != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.15)),
                          ),
                          child: isLoading
                              ? const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : Row(
                                  children: [
                                    const Icon(Icons.people_alt_rounded, size: 18, color: Color(0xFF8B5CF6)),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$jumlahSiswa siswa di kelas $dariKelas',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF8B5CF6),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      // Ke Kelas
                      const Text(
                        'Ke Kelas',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: kategoriKelas
                            .where((k) => k != dariKelas)
                            .map((kelas) {
                          final isSelected = keKelas == kelas;
                          return GestureDetector(
                            onTap: isProcessing || dariKelas == null ? null : () {
                              setModalState(() => keKelas = isSelected ? null : kelas);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : AppColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? Colors.green : AppColors.border,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                                    size: 18,
                                    color: isSelected ? Colors.green : AppColors.muted,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Kelas $kelas',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      color: isSelected ? Colors.green : AppColors.foreground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      // Preview perpindahan
                      if (dariKelas != null && keKelas != null && !isLoading) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$jumlahSiswa siswa akan dipindahkan',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Dari kelas $dariKelas ke kelas $keKelas',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Footer
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: (dariKelas != null && keKelas != null && !isProcessing)
                          ? null
                          : null,
                      color: (dariKelas != null && keKelas != null && !isProcessing)
                          ? const Color(0xFF8B5CF6)
                          : AppColors.muted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton(
                      onPressed: (dariKelas != null && keKelas != null && !isProcessing)
                          ? () async {
                              // Konfirmasi
                              final confirmed = await showDialog<bool>(
                                context: ctx,
                                builder: (confirmCtx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: const Text(
                                    'Konfirmasi Perpindahan',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  content: Text(
                                    'Pindahkan $jumlahSiswa siswa dari kelas $dariKelas ke kelas $keKelas?\n\nTindakan ini tidak dapat dibatalkan.',
                                    style: const TextStyle(fontSize: 14, height: 1.5),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(confirmCtx, false),
                                      child: const Text('Batal'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(confirmCtx, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF8B5CF6),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Text('Ya, Pindahkan'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                setModalState(() => isProcessing = true);
                                try {
                                  final count = await _fs.pindahkanSiswa(dariKelas!, keKelas!);
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx, {
                                      'dariKelas': dariKelas!,
                                      'keKelas': keKelas!,
                                      'jumlah': count,
                                    });
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ToastService.show(
                                      ctx,
                                      message: 'Gagal memindahkan siswa: $e',
                                      backgroundColor: Colors.red.shade600,
                                      icon: Icons.error_outline,
                                    );
                                    setModalState(() => isProcessing = false);
                                  }
                                }
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isProcessing
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Pindahkan Siswa',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Tampilkan hasil setelah dialog ditutup
    if (result != null && mounted) {
      final dari = result['dariKelas'] as String;
      final ke = result['keKelas'] as String;
      final jumlah = result['jumlah'] as int;

      ToastService.show(
        context,
        message: '✅ $jumlah siswa berhasil dipindahkan dari kelas $dari ke kelas $ke',
      );
    }
  }

  // ─── Approval Absensi Section ────────────────────────────────
  Widget _buildApprovalSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.timer_rounded, color: Colors.green, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Approval Absensi Ulang',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Izinkan guru absensi ulang dengan batas waktu',
                        style: TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _approveGuruAbsensi,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Approve', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            if (_isLoadingOverrides) ...[
              const SizedBox(height: 10),
              const Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ] else if (_activeOverrides.isEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Tidak ada approval aktif hari ini',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              ..._activeOverrides.map((override) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_rounded, color: Colors.orange, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            override.mataPelajaran,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Kelas ${override.kelas} • Sisa ${override.remainingTime}',
                            style: const TextStyle(fontSize: 10, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _revokeOverride(override),
                      icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      tooltip: 'Batalkan',
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Stats Row ──────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: FutureBuilder<List<Siswa>>(
              future: _fs.getAllSiswa(),
              builder: (context, siswaSnap) {
                final totalSiswa = siswaSnap.data?.length ?? 0;
                return _MiniStatCard(
                  icon: Icons.people_alt_rounded,
                  label: 'Siswa',
                  value: totalSiswa.toString(),
                  color: AppColors.accent,
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FutureBuilder<List<Guru>>(
              future: _fs.getAllGuru(),
              builder: (context, guruSnap) {
                final totalGuru = guruSnap.data?.length ?? 0;
                return _MiniStatCard(
                  icon: Icons.person,
                  label: 'Guru',
                  value: totalGuru.toString(),
                  color: AppColors.warning,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Daftar Guru ────────────────────────────────────────────
  Widget _buildGuruList() {
    return FutureBuilder<List<Guru>>(
      future: _fs.getAllGuru(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }

        var list = snapshot.data ?? [];
        if (_searchGuru.isNotEmpty) {
          list = list
              .where((g) =>
                  g.nama.toLowerCase().contains(_searchGuru) ||
                  g.nip.toLowerCase().contains(_searchGuru) ||
                  g.email.toLowerCase().contains(_searchGuru) ||
                  g.mapelList.any((m) => m.toLowerCase().contains(_searchGuru)) ||
                  g.kelasList.any((k) => k.toLowerCase().contains(_searchGuru)))
              .toList();
        }

        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_off_rounded, size: 64, color: AppColors.muted.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                const Text('Belum ada data guru', style: TextStyle(color: AppColors.muted)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final guru = list[index];

            return Tilt3D(
              child: Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                      child: Text(
                        guru.nama.isNotEmpty ? guru.nama[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Info (Nama + Mapel + Kelas)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guru.nama,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          if (guru.mapelList.isNotEmpty)
                            Text(
                              guru.mapelList.join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primary.withValues(alpha: 0.8),
                              ),
                            ),
                          if (guru.kelasList.isNotEmpty)
                            Text(
                              'Kelas: ${guru.kelasList.join(', ')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Edit Guru
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.warning),
                      onPressed: () => _editGuru(guru),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      tooltip: 'Edit data guru',
                    ),

                    // Reset Password
                    IconButton(
                      icon: const Icon(Icons.lock_reset_rounded, size: 18, color: Colors.orange),
                      onPressed: () => _resetPasswordGuru(guru),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      tooltip: 'Reset password',
                    ),
                    // Delete
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      onPressed: () => _hapusGuru(guru),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      tooltip: 'Hapus guru',
                    ),
                  ],
                ),
              ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Mini Stat Card ──────────────────────────────────────────
class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tilt3D(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ],
        ),
      ),
    );
  }
}

// ─── Dialog Pilih Guru ───────────────────────────────────────
class _GuruPickerDialog extends StatefulWidget {
  final List<Guru> guruList;
  const _GuruPickerDialog({required this.guruList});
  @override
  State<_GuruPickerDialog> createState() => _GuruPickerDialogState();
}

class _GuruPickerDialogState extends State<_GuruPickerDialog> {
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final filtered = widget.guruList
        .where((g) => g.nama.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Pilih Guru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: Column(
          children: [
            TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Cari nama guru...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final guru = filtered[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                      child: Text(guru.nama[0].toUpperCase(),
                          style: const TextStyle(color: AppColors.warning, fontSize: 12)),
                    ),
                    title: Text(guru.nama, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(guru.mapelList.join(', '),
                        style: const TextStyle(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.pop(ctx, guru),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
      ],
    );
  }
}

// ─── Dialog Pilih Durasi ──────────────────────────────────────
class _DurasiPickerDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Batas Waktu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Pilih durasi waktu absensi ulang:',
              style: TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          ...[5, 10, 15, 30].map((menit) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, menit),
                icon: const Icon(Icons.timer_rounded, size: 18),
                label: Text('$menit Menit'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          )),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
      ],
    );
  }
}

// ─── Dialog Pilih Kelas & Mapel ───────────────────────────────
class _KelasMapelPickerDialog extends StatefulWidget {
  final Guru guru;
  final FirestoreService fs;
  const _KelasMapelPickerDialog({required this.guru, required this.fs});
  @override
  State<_KelasMapelPickerDialog> createState() => _KelasMapelPickerDialogState();
}

class _KelasMapelPickerDialogState extends State<_KelasMapelPickerDialog> {
  String? _selectedKelas;
  String? _selectedMapel;
  List<String> _availableMapel = [];

  void _updateMapel() {
    if (_selectedKelas == null) {
      _availableMapel = [];
    } else {
      // _selectedKelas sudah berupa tingkat (X/XI/XII),
      // gunakan getMapelByTingkat bukan getMapelByKelas.
      final allMapel = getMapelByTingkat(_selectedKelas!);
      // Filter berdasarkan mapel yang diajar guru
      _availableMapel = allMapel
          .where((m) => widget.guru.mapelList.contains(m))
          .toList();
    }
    _selectedMapel = null;
  }

  @override
  Widget build(BuildContext context) {
    // Kelas dari guru
    final kelasList = widget.guru.kelasList
        .map((k) => kelasToTingkat(k))
        .whereType<String>()
        .toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Pilih Kelas & Mapel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kelas:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: kelasList.map((k) {
              final sel = _selectedKelas == k;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedKelas = sel ? null : k;
                  _updateMapel();
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary.withValues(alpha: 0.15) : AppColors.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                  ),
                  child: Text(k, style: TextStyle(
                    fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel ? AppColors.primary : AppColors.foreground,
                  )),
                ),
              );
            }).toList(),
          ),
          if (_selectedKelas != null) ...[
            const SizedBox(height: 14),
            const Text('Mata Pelajaran:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            if (_availableMapel.isEmpty)
              const Text('Tidak ada mapel untuk kelas ini', style: TextStyle(fontSize: 11, color: AppColors.muted))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _availableMapel.map((m) {
                  final sel = _selectedMapel == m;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMapel = sel ? null : m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? Colors.green.withValues(alpha: 0.15) : AppColors.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sel ? Colors.green : AppColors.border),
                      ),
                      child: Text(m, style: TextStyle(
                        fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? Colors.green : AppColors.foreground,
                      )),
                    ),
                  );
                }).toList(),
              ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          onPressed: (_selectedKelas != null && _selectedMapel != null)
              ? () => Navigator.pop(context, {'kelas': _selectedKelas!, 'mapel': _selectedMapel!})
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Approve'),
        ),
      ],
    );
  }
}
