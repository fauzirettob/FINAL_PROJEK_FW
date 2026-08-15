import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:absensi_siswa/models/admin.dart';
import 'package:absensi_siswa/providers/auth_provider.dart';
import 'package:absensi_siswa/screens/auth/manage_admin_screen.dart';

// Mock hasil generate mockito (dipakai juga oleh auth_provider_test.dart).
// NiceMock: method yang tidak di-stub mengembalikan nilai default yang aman
// (mis. Future<void>.value()), sehingga stubbing `Future<void>` aman.
import 'auth_provider_test.mocks.dart';

/// Membuat daftar admin dummy dengan jumlah tertentu.
List<Admin> _daftarAdmin(int jumlah) {
  return List.generate(jumlah, (i) {
    return Admin(
      id: 'admin-$i',
      nama: 'Admin ${i + 1}',
      email: 'admin${i + 1}@school.sch.id',
      createdAt: DateTime(2026, 1, 1),
    );
  });
}

/// Pump ManageAdminScreen dengan [fs] yang mengembalikan [admins],
/// lalu tunggu proses pemuatan selesai.
Future<void> _pumpScreen(
  WidgetTester tester, {
  required MockFirestoreService fs,
  required List<Admin> admins,
}) async {
  // syncAdminCounter tidak perlu di-stub: nice mock mengembalikan
  // Future<void>.value() secara default.
  when(fs.getAllAdmin()).thenAnswer((_) async => admins);

  await _pumpWithService(tester, fs);
  await tester.pumpAndSettle();
}

/// Pump ManageAdminScreen memakai [fs] yang sudah di-stub, tanpa menunggu
/// pemuatan selesai (dipakai untuk menguji state loading).
Future<void> _pumpWithService(
  WidgetTester tester,
  MockFirestoreService fs,
) async {
  final mockAuth = MockFirebaseAuth();
  when(mockAuth.authStateChanges()).thenAnswer((_) => const Stream.empty());

  final authProvider = AuthProvider(auth: mockAuth, firestoreService: fs);

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: MaterialApp(
        home: ManageAdminScreen(firestoreService: fs),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Indikator slot admin', () {
    testWidgets('slot tersedia: menampilkan jumlah terpakai dan sisa slot',
        (tester) async {
      final fs = MockFirestoreService();
      await _pumpScreen(tester, fs: fs, admins: _daftarAdmin(2));

      // Daftar admin ikut termuat (bukti data dipakai sebagai sumber hitungan).
      expect(find.text('Admin 1'), findsOneWidget);
      expect(find.text('Admin 2'), findsOneWidget);

      expect(
        find.text('Slot admin: 2/3 terpakai (1 slot tersedia)'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('slot penuh: menampilkan peringatan penuh', (tester) async {
      final fs = MockFirestoreService();
      await _pumpScreen(tester, fs: fs, admins: _daftarAdmin(3));

      expect(find.text('Admin 3'), findsOneWidget);
      expect(
        find.textContaining('Slot admin penuh (3/3)'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    });

    testWidgets('melebihi batas: menampilkan peringatan merah', (tester) async {
      final fs = MockFirestoreService();
      await _pumpScreen(tester, fs: fs, admins: _daftarAdmin(4));

      expect(find.text('Admin 4'), findsOneWidget);
      expect(
        find.textContaining('Jumlah admin melebihi batas (4/3)'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    });

    testWidgets('loading: menampilkan "Memeriksa slot admin..."',
        (tester) async {
      final fs = MockFirestoreService();
      // Pemuatan ditahan → layar tetap dalam state loading.
      final completer = Completer<void>();
      when(fs.syncAdminCounter()).thenAnswer((_) => completer.future);
      when(fs.getAllAdmin()).thenAnswer((_) async => _daftarAdmin(2));

      await _pumpWithService(tester, fs);
      await tester.pump();

      expect(find.text('Memeriksa slot admin...'), findsOneWidget);
      expect(find.textContaining('Slot admin:'), findsNothing);

      // Selesaikan pemuatan agar tidak ada pekerjaan yang menggantung.
      completer.complete();
      await tester.pumpAndSettle();

      expect(
        find.text('Slot admin: 2/3 terpakai (1 slot tersedia)'),
        findsOneWidget,
      );
    });
  });

  group('Hapus admin', () {
    testWidgets(
        'konfirmasi → deleteAdmin dipanggil → admin hilang dari daftar',
        (tester) async {
      // Daftar admin dibuat mutable agar penghapusan benar-benar terlihat
      // setelah daftar dimuat ulang.
      final admins = _daftarAdmin(2);
      final fs = MockFirestoreService();
      when(fs.getAllAdmin()).thenAnswer((_) async => admins);
      when(fs.deleteAdmin(any)).thenAnswer((invocation) async {
        final id = invocation.positionalArguments.first as String;
        admins.removeWhere((a) => a.id == id);
      });

      await _pumpWithService(tester, fs);
      await tester.pumpAndSettle();

      expect(find.text('Admin 2'), findsOneWidget);

      // Tekan tombol hapus pada kartu 'Admin 2' (ikon hapus kedua).
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      // Frame pertama membangun rute dialog, frame kedua menyelesaikan
      // animasi masuk dialog konfirmasi.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Dialog konfirmasi muncul dan menjelaskan penghapusan manual Auth.
      expect(find.text('Hapus Admin'), findsOneWidget);
      expect(
        find.textContaining('Firebase Authentication'),
        findsOneWidget,
      );

      await tester.tap(find.text('Hapus'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // deleteAdmin dipanggil dengan UID admin yang benar (admin-1 = Admin 2).
      verify(fs.deleteAdmin('admin-1')).called(1);

      // Dialog sukses tampil. Jangan pakai pumpAndSettle selama dialog ini
      // terbuka karena partikel perayaan beranimasi berulang tanpa henti.
      expect(find.text('Berhasil Dihapus'), findsOneWidget);
      await tester.tap(find.text('Selesai'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Daftar dimuat ulang setelah dialog ditutup.
      await tester.pumpAndSettle();

      // Daftar dimuat ulang: 'Admin 2' hilang dan slot menjadi 1/3.
      expect(find.text('Admin 2'), findsNothing);
      expect(find.text('Admin 1'), findsOneWidget);
      expect(
        find.text('Slot admin: 1/3 terpakai (2 slot tersedia)'),
        findsOneWidget,
      );
    });
  });
}
