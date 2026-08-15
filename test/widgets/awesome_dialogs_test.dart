import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:absensi_siswa/widgets/awesome_dialogs.dart';

/// Bungkus aplikasi dengan MediaQuery di atas MaterialApp agar dialog
/// (yang dirender di bawah navigator root) ikut menerima setelan reduce motion.
Widget _app(Widget home, {bool reduceMotion = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: MaterialApp(home: home),
  );
}

/// Buka dialog lewat tombol 'buka' dan catat hasil pop ke [onResult].
Future<void> _bukaDialog(
  WidgetTester tester,
  Widget dialog, {
  bool reduceMotion = false,
  void Function(bool?)? onResult,
}) async {
  await tester.pumpWidget(_app(
    Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showDialog<bool>(
                context: context,
                builder: (_) => dialog,
              );
              onResult?.call(result);
            },
            child: const Text('buka'),
          ),
        ),
      ),
    ),
    reduceMotion: reduceMotion,
  ));

  await tester.tap(find.text('buka'));
  // Frame pertama membangun rute dialog (animasi masuk mulai dari skala 0),
  // frame kedua menyelesaikan animasi masuk agar tombol bisa diketuk.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Lepas widget agar controller animasi berulang dibuang sebelum test selesai.
Future<void> _lepas(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: SizedBox()));
}

void main() {
  group('WhatsAppConfirmDialog', () {
    const dialog = WhatsAppConfirmDialog(
      jumlahOrangTua: 12,
      totalSiswa: 15,
      kelas: 'X IPA 1',
      tanggal: '10/08/2026',
      namaContoh: 'Budi',
      statusContoh: 'hadir',
    );

    testWidgets('menampilkan ringkasan, pratinjau pesan, dan tombol aksi',
        (tester) async {
      await _bukaDialog(tester, dialog);

      expect(find.text('Kirim Notifikasi WA'), findsOneWidget);
      expect(find.textContaining('X IPA 1'), findsWidgets);
      expect(find.text('Contoh pesan yang akan dikirim'), findsOneWidget);
      expect(find.textContaining('Budi'), findsOneWidget);
      expect(find.textContaining('✅ Hadir'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Kirim Sekarang'), findsOneWidget);

      await _lepas(tester);
    });

    testWidgets('tombol Batal menutup dialog dengan hasil false',
        (tester) async {
      bool? hasil;
      await _bukaDialog(tester, dialog, onResult: (v) => hasil = v);

      await tester.tap(find.text('Batal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(hasil, isFalse);
      await _lepas(tester);
    });

    testWidgets('tombol Kirim Sekarang menutup dialog dengan hasil true',
        (tester) async {
      bool? hasil;
      await _bukaDialog(tester, dialog, onResult: (v) => hasil = v);

      await tester.tap(find.text('Kirim Sekarang'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(hasil, isTrue);
      await _lepas(tester);
    });

    testWidgets('reduce motion: konten tampil tanpa animasi & tanpa timer',
        (tester) async {
      await _bukaDialog(tester, dialog, reduceMotion: true);

      expect(find.text('Kirim Notifikasi WA'), findsOneWidget);
      // Angka count-up tampil langsung sebagai nilai akhir.
      expect(find.text('12'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _lepas(tester);
    });
  });

  group('WhatsAppResultDialog', () {
    testWidgets('sukses semua → judul terkirim + statistik berhasil/gagal',
        (tester) async {
      await _bukaDialog(
        tester,
        const WhatsAppResultDialog(
          berhasil: 11,
          gagal: 0,
          kelas: 'X IPA 1',
          tanggal: '10/08/2026',
        ),
      );

      expect(find.text('Notifikasi Terkirim 🎉'), findsOneWidget);
      expect(find.text('Berhasil'), findsOneWidget);
      expect(find.text('Gagal'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);

      // Tunggu animasi count-up selesai → nilai akhir tampil.
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('11'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);

      await _lepas(tester);
    });

    testWidgets('sebagian gagal → judul peringatan', (tester) async {
      await _bukaDialog(
        tester,
        const WhatsAppResultDialog(
          berhasil: 9,
          gagal: 2,
          kelas: 'X IPA 1',
          tanggal: '10/08/2026',
        ),
      );

      expect(find.text('Sebagian Gagal Terkirim'), findsOneWidget);
      expect(find.textContaining('tidak terkirim'), findsOneWidget);
      // Badge peringatan oranye menggantikan centang hijau.
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.byType(AnimatedCheckmark), findsNothing);

      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('9'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      await _lepas(tester);
    });

    testWidgets('tombol Selesai menutup dialog', (tester) async {
      var ditutup = false;
      await _bukaDialog(
        tester,
        const WhatsAppResultDialog(
          berhasil: 5,
          gagal: 0,
          kelas: 'X IPA 1',
          tanggal: '10/08/2026',
        ),
        onResult: (_) => ditutup = true,
      );

      await tester.tap(find.text('Selesai'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(ditutup, isTrue);
      await _lepas(tester);
    });

    testWidgets('reduce motion: nilai akhir langsung tampil tanpa timer',
        (tester) async {
      await _bukaDialog(
        tester,
        const WhatsAppResultDialog(
          berhasil: 12,
          gagal: 1,
          kelas: 'X IPA 1',
          tanggal: '10/08/2026',
        ),
        reduceMotion: true,
      );

      expect(find.text('Sebagian Gagal Terkirim'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _lepas(tester);
    });

    testWidgets('per siswa sukses → judul terkirim + nama siswa + chip status',
        (tester) async {
      await _bukaDialog(
        tester,
        const WhatsAppResultDialog(
          berhasil: 1,
          gagal: 0,
          tanggal: '10/08/2026',
          namaSiswa: 'Budi',
          statusLabel: '✅ Hadir',
        ),
      );

      expect(find.text('Notifikasi Terkirim 🎉'), findsOneWidget);
      expect(find.textContaining('Budi'), findsOneWidget);
      expect(find.text('✅ Hadir'), findsOneWidget);

      await _lepas(tester);
    });

    testWidgets('per siswa gagal → judul WA Gagal Terkirim + badge peringatan',
        (tester) async {
      await _bukaDialog(
        tester,
        const WhatsAppResultDialog(
          berhasil: 0,
          gagal: 1,
          tanggal: '10/08/2026',
          namaSiswa: 'Budi',
        ),
      );

      expect(find.text('WA Gagal Terkirim'), findsOneWidget);
      expect(find.textContaining('tidak terkirim'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.byType(AnimatedCheckmark), findsNothing);

      await _lepas(tester);
    });

    testWidgets('waSkipped → Absen Tersimpan + info tanpa statistik',
        (tester) async {
      await _bukaDialog(
        tester,
        const WhatsAppResultDialog(
          berhasil: 0,
          gagal: 0,
          tanggal: '10/08/2026',
          namaSiswa: 'Budi',
          waSkipped: true,
        ),
      );

      expect(find.text('Absen Tersimpan'), findsOneWidget);
      expect(find.textContaining('belum diisi'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      expect(find.byType(AnimatedCheckmark), findsNothing);
      // Tanpa statistik berhasil/gagal saat pengiriman dilewati.
      expect(find.text('Berhasil'), findsNothing);
      expect(find.text('Gagal'), findsNothing);

      await _lepas(tester);
    });

    testWidgets('onDone dipanggil saat tombol Selesai ditekan', (tester) async {
      var selesai = false;
      await _bukaDialog(
        tester,
        WhatsAppResultDialog(
          berhasil: 1,
          gagal: 0,
          tanggal: '10/08/2026',
          namaSiswa: 'Budi',
          onDone: () => selesai = true,
        ),
      );

      await tester.tap(find.text('Selesai'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(selesai, isTrue);
      await _lepas(tester);
    });
  });

  group('AnimatedCheckmark', () {
    testWidgets('reduce motion: centang utuh tampil langsung tanpa animasi',
        (tester) async {
      await tester.pumpWidget(_app(
        const Scaffold(
          body: Center(child: AnimatedCheckmark()),
        ),
        reduceMotion: true,
      ));

      expect(find.byType(AnimatedCheckmark), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AwesomeConfirmDialog', () {
    const dialog = AwesomeConfirmDialog(
      title: 'Hapus Data',
      message: 'Apakah Anda yakin ingin menghapus data ini?',
      icon: Icons.delete_forever_rounded,
      color: Colors.red,
      confirmText: 'Hapus',
      confirmIcon: Icons.delete_outline,
    );

    testWidgets('menampilkan judul, pesan, dan tombol aksi', (tester) async {
      await _bukaDialog(tester, dialog);

      expect(find.text('Hapus Data'), findsOneWidget);
      expect(find.textContaining('menghapus data ini'), findsOneWidget);
      expect(find.byIcon(Icons.delete_forever_rounded), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Hapus'), findsOneWidget);

      await _lepas(tester);
    });

    testWidgets('tombol Batal menutup dengan hasil false', (tester) async {
      bool? hasil;
      await _bukaDialog(tester, dialog, onResult: (v) => hasil = v);

      await tester.tap(find.text('Batal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(hasil, isFalse);
      await _lepas(tester);
    });

    testWidgets('tombol konfirmasi menutup dengan hasil true', (tester) async {
      bool? hasil;
      await _bukaDialog(tester, dialog, onResult: (v) => hasil = v);

      await tester.tap(find.text('Hapus'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(hasil, isTrue);
      await _lepas(tester);
    });

    testWidgets('menampilkan detail tambahan', (tester) async {
      await _bukaDialog(
        tester,
        const AwesomeConfirmDialog(
          title: 'Hapus',
          message: 'Yakin?',
          icon: Icons.warning_amber_rounded,
          color: Colors.red,
          detail: Text('Detail ekstra'),
        ),
      );

      expect(find.text('Detail ekstra'), findsOneWidget);
      await _lepas(tester);
    });

    testWidgets('reduce motion: tampil tanpa animasi & tanpa timer',
        (tester) async {
      await _bukaDialog(tester, dialog, reduceMotion: true);

      expect(find.text('Hapus Data'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _lepas(tester);
    });
  });

  group('AwesomeLoadingDialog', () {
    testWidgets('menampilkan pesan dan spinner', (tester) async {
      await _bukaDialog(
        tester,
        const AwesomeLoadingDialog(message: 'Menyiapkan data...'),
      );

      expect(find.text('Menyiapkan data...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _lepas(tester);
    });

    testWidgets('reduce motion: tampil tanpa error', (tester) async {
      await _bukaDialog(
        tester,
        const AwesomeLoadingDialog(message: 'Menyiapkan data...'),
        reduceMotion: true,
      );

      expect(find.text('Menyiapkan data...'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _lepas(tester);
    });
  });

  group('AwesomeSuccessDialog', () {
    const dialog = AwesomeSuccessDialog(
      title: 'Guru Berhasil Ditambahkan',
      subtitle: 'Akun guru baru telah berhasil dibuat.',
      confirmText: 'Tambah Guru Lagi',
    );

    testWidgets('menampilkan judul, deskripsi, centang, dan tombol penutup',
        (tester) async {
      await _bukaDialog(tester, dialog);

      expect(find.text('Guru Berhasil Ditambahkan'), findsOneWidget);
      expect(find.textContaining('berhasil dibuat'), findsOneWidget);
      expect(find.byType(AnimatedCheckmark), findsOneWidget);
      expect(find.text('Tambah Guru Lagi'), findsOneWidget);

      await _lepas(tester);
    });

    testWidgets('tombol penutup menutup popup', (tester) async {
      var ditutup = false;
      await _bukaDialog(tester, dialog, onResult: (_) => ditutup = true);

      await tester.tap(find.text('Tambah Guru Lagi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(ditutup, isTrue);
      await _lepas(tester);
    });

    testWidgets('onDone dipanggil saat tombol penutup ditekan', (tester) async {
      var selesai = false;
      await _bukaDialog(
        tester,
        AwesomeSuccessDialog(
          title: 'Siswa Berhasil Ditambahkan',
          subtitle: 'Budi (123) berhasil ditambahkan.',
          onDone: () => selesai = true,
        ),
      );

      await tester.tap(find.text('Selesai'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(selesai, isTrue);
      await _lepas(tester);
    });

    testWidgets('reduce motion: tampil tanpa animasi & tanpa timer',
        (tester) async {
      await _bukaDialog(tester, dialog, reduceMotion: true);

      expect(find.text('Guru Berhasil Ditambahkan'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _lepas(tester);
    });
  });
}
