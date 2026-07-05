import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mockito/mockito.dart';

import 'package:absensi_siswa/models/siswa.dart';
import 'package:absensi_siswa/models/guru.dart';
import 'package:absensi_siswa/screens/auth/olah_data_screen.dart';
import 'auth_provider_test.mocks.dart';
import 'firebase_test_helper.dart';

void main() {
  late MockFirestoreService mockFirestore;

  setUpAll(() async {
    await setupFirebaseMocks();
  });

  setUp(() async {
    mockFirestore = MockFirestoreService();
    await initializeDateFormatting('id', null);
  });

  Widget buildOlahDataScreen() {
    return MaterialApp(
      home: OlahDataScreen(firestoreService: mockFirestore),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Stats row
  // ─────────────────────────────────────────────────────────────
  group('OlahDataScreen — Stats row', () {
    testWidgets('menampilkan 0 ketika tidak ada data', (tester) async {
      // Setup mock: tidak ada siswa & guru
      when(mockFirestore.getAllSiswa()).thenAnswer(
        (_) => Future.value([]),
      );
      when(mockFirestore.getAllGuru()).thenAnswer(
        (_) => Future.value([]),
      );

      await tester.pumpWidget(buildOlahDataScreen());
      await tester.pumpAndSettle();

      // Stats: Siswa=0, Guru=0
      expect(find.text('0'), findsNWidgets(2));
      expect(find.text('Siswa'), findsOneWidget);
      expect(find.text('Guru'), findsOneWidget);
    });

    testWidgets('menampilkan jumlah siswa dan guru dengan benar',
        (tester) async {
      when(mockFirestore.getAllSiswa()).thenAnswer(
        (_) => Future.value([
          Siswa(id: 's1', nama: 'Andi', nis: '001', kelas: 'X-A',
              namaOrtu: 'Bpk Andi', hpOrtu: '0811', createdAt: DateTime.now()),
          Siswa(id: 's2', nama: 'Budi', nis: '002', kelas: 'X-A',
              namaOrtu: 'Bpk Budi', hpOrtu: '0812', createdAt: DateTime.now()),
          Siswa(id: 's3', nama: 'Caca', nis: '003', kelas: 'X-B',
              namaOrtu: 'Bpk Caca', hpOrtu: '0813', createdAt: DateTime.now()),
        ]),
      );
      when(mockFirestore.getAllGuru()).thenAnswer(
        (_) => Future.value([
          Guru(id: 'g1', nama: 'Guru Satu', email: 'g1@school.sch.id',
              createdAt: DateTime.now()),
          Guru(id: 'g2', nama: 'Guru Dua', email: 'g2@school.sch.id',
              createdAt: DateTime.now()),
        ]),
      );

      await tester.pumpWidget(buildOlahDataScreen());
      await tester.pumpAndSettle();

      // Stats: Siswa=3, Guru=2
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Siswa'), findsOneWidget);
      expect(find.text('Guru'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Daftar Guru
  // ─────────────────────────────────────────────────────────────
  group('OlahDataScreen — Daftar Guru', () {
    testWidgets('menampilkan teks kosong ketika tidak ada guru',
        (tester) async {
      when(mockFirestore.getAllSiswa()).thenAnswer(
        (_) => Future.value([]),
      );
      when(mockFirestore.getAllGuru()).thenAnswer(
        (_) => Future.value([]),
      );

      await tester.pumpWidget(buildOlahDataScreen());
      await tester.pumpAndSettle();

      // Verifikasi teks kosong
      expect(find.text('Belum ada data guru'), findsOneWidget);
    });

    testWidgets('menampilkan data guru dari Firestore', (tester) async {
      final guruList = [
        Guru(id: 'g1', nama: 'Susi Susanti', email: 'susi@school.sch.id',
            createdAt: DateTime(2025, 1, 15)),
        Guru(id: 'g2', nama: 'Bambang Pamungkas', email: 'bambang@school.sch.id',
            createdAt: DateTime(2025, 3, 20)),
      ];

      when(mockFirestore.getAllSiswa()).thenAnswer(
        (_) => Future.value([]),
      );
      when(mockFirestore.getAllGuru()).thenAnswer(
        (_) => Future.value(guruList),
      );

      await tester.pumpWidget(buildOlahDataScreen());
      await tester.pumpAndSettle();

      // Verifikasi data guru muncul
      expect(find.text('Susi Susanti'), findsOneWidget);
      expect(find.text('Bambang Pamungkas'), findsOneWidget);
      expect(find.text('susi@school.sch.id'), findsOneWidget);
      expect(find.text('bambang@school.sch.id'), findsOneWidget);
    });

    testWidgets('search berdasarkan nama guru berfungsi', (tester) async {
      final guruList = [
        Guru(id: 'g1', nama: 'Susi Susanti', email: 'susi@school.sch.id',
            createdAt: DateTime(2025, 1, 15)),
        Guru(id: 'g2', nama: 'Bambang Pamungkas', email: 'bambang@school.sch.id',
            createdAt: DateTime(2025, 3, 20)),
        Guru(id: 'g3', nama: 'Budi Santoso', email: 'budi@school.sch.id',
            createdAt: DateTime(2025, 5, 10)),
      ];

      when(mockFirestore.getAllSiswa()).thenAnswer(
        (_) => Future.value([]),
      );
      when(mockFirestore.getAllGuru()).thenAnswer(
        (_) => Future.value(guruList),
      );

      await tester.pumpWidget(buildOlahDataScreen());
      await tester.pumpAndSettle();

      // Ketik "bambang" di search field
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'bambang');
      await tester.pumpAndSettle();

      // Hanya Bambang yang tampil
      expect(find.text('Bambang Pamungkas'), findsOneWidget);
      expect(find.text('Susi Susanti'), findsNothing);
      expect(find.text('Budi Santoso'), findsNothing);
    });

    testWidgets('search berdasarkan email guru berfungsi', (tester) async {
      final guruList = [
        Guru(id: 'g1', nama: 'Susi Susanti', email: 'susi@school.sch.id',
            createdAt: DateTime(2025, 1, 15)),
        Guru(id: 'g2', nama: 'Bambang Pamungkas', email: 'bambang@school.sch.id',
            createdAt: DateTime(2025, 3, 20)),
      ];

      when(mockFirestore.getAllSiswa()).thenAnswer(
        (_) => Future.value([]),
      );
      when(mockFirestore.getAllGuru()).thenAnswer(
        (_) => Future.value(guruList),
      );

      await tester.pumpWidget(buildOlahDataScreen());
      await tester.pumpAndSettle();

      // Cari berdasarkan email
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'bambang@school');
      await tester.pumpAndSettle();

      // Hanya Bambang yang tampil
      expect(find.text('Bambang Pamungkas'), findsOneWidget);
      expect(find.text('Susi Susanti'), findsNothing);
    });

    testWidgets('search tidak menemukan guru — menampilkan daftar kosong',
        (tester) async {
      final guruList = [
        Guru(id: 'g1', nama: 'Susi Susanti', email: 'susi@school.sch.id',
            createdAt: DateTime(2025, 1, 15)),
      ];

      when(mockFirestore.getAllSiswa()).thenAnswer(
        (_) => Future.value([]),
      );
      when(mockFirestore.getAllGuru()).thenAnswer(
        (_) => Future.value(guruList),
      );

      await tester.pumpWidget(buildOlahDataScreen());
      await tester.pumpAndSettle();

      // Cari dengan kata yang tidak ada
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'zzzzz');
      await tester.pumpAndSettle();

      // Tidak ada guru yang tampil, tapi teks kosong belum muncul
      // karena setelah filter, list kosong tidak menampilkan teks kosong
      expect(find.text('Susi Susanti'), findsNothing);
    });
  });
}
