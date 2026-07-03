import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mockito/mockito.dart';

import 'package:absensi_siswa/models/absensi.dart';
import 'package:absensi_siswa/models/siswa.dart';
import 'package:absensi_siswa/models/guru.dart';
import 'package:absensi_siswa/screens/auth/olah_data_screen.dart';
import 'package:absensi_siswa/services/firestore_service.dart';
import 'auth_provider_test.mocks.dart';

/// Helper: creates an Absensi with default values for testing
Absensi createAbsensi({
  required String id,
  required String jam,
  required String nama,
  required String kelas,
  String status = 'hadir',
}) {
  return Absensi(
    id: id,
    siswaId: 'siswa-$id',
    siswaNama: nama,
    kelas: kelas,
    tanggal: DateTime(2026, 7, 4),
    status: status,
    jam: jam,
    guruId: 'guru-1',
  );
}

void main() {
  late MockFirestoreService mockFirestore;

  setUp(() async {
    mockFirestore = MockFirestoreService();
    await initializeDateFormatting('id', null);
  });

  Widget buildOlahDataScreen() {
    return MaterialApp(
      home: OlahDataScreen(firestoreService: mockFirestore),
    );
  }

  group('OlahDataScreen — Rekap Absensi tab', () {
    testWidgets('menampilkan pesan kosong ketika tidak ada data absensi',
        (tester) async {
      // Setup mock: tidak ada data absensi, siswa, guru
      when(mockFirestore.getAllAbsensi()).thenAnswer(
        (_) => Stream<List<Absensi>>.value([]),
      );
      when(mockFirestore.getSiswaStream()).thenAnswer(
        (_) => Stream<List<Siswa>>.value([]),
      );
      when(mockFirestore.getAllGuru()).thenAnswer(
        (_) => Future.value([]),
      );

      await tester.pumpWidget(buildOlahDataScreen());
      await tester.pumpAndSettle();

      // Verifikasi statistik menampilkan 0
      expect(find.text('0'), findsNWidgets(3)); // absensi=0, siswa=0, guru=0

      // Verifikasi teks kosong muncul
      expect(find.text('Tidak ada data absensi'), findsOneWidget);
    });

    testWidgets('menampilkan data absensi dari Firestore dengan benar',
        (tester) async {
      final absensiList = [
        createAbsensi(id: '1', jam: '08:00', nama: 'Budi Santoso', kelas: 'X-A'),
        createAbsensi(id: '2', jam: '10:30', nama: 'Siti Aminah', kelas: 'X-B', status: 'sakit'),
        createAbsensi(id: '3', jam: '07:15', nama: 'Andi Pratama', kelas: 'X-A', status: 'izin'),
        createAbsensi(id: '4', jam: '13:45', nama: 'Dewi Lestari', kelas: 'XI-A', status: 'alpa'),
      ];

      when(mockFirestore.getAllAbsensi()).thenAnswer(
        (_) => Stream<List<Absensi>>.value(absensiList),
      );
      when(mockFirestore.getSiswaStream()).thenAnswer(
        (_) => Stream<List<Siswa>>.value([]),
      );
      when(mockFirestore.getAllGuru()).thenAnswer(
        (_) => Future.value([]),
      );

      await tester.pumpWidget(buildOlahDataScreen());
      await tester.pumpAndSettle();

      // Verifikasi semua nama siswa muncul
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('Siti Aminah'), findsOneWidget);
      expect(find.text('Andi Pratama'), findsOneWidget);
      expect(find.text('Dewi Lestari'), findsOneWidget);

      // Verifikasi kelas dan jam
      expect(find.textContaining('X-A'), findsWidgets);
      expect(find.textContaining('X-B'), findsOneWidget);
      expect(find.textContaining('XI-A'), findsOneWidget);

      // Verifikasi status badges
      expect(find.text('Hadir'), findsOneWidget);
      expect(find.text('Sakit'), findsOneWidget);
      expect(find.text('Izin'), findsOneWidget);
      expect(find.text('Alpa'), findsOneWidget);

      // Verifikasi header section (tanggal)
      expect(find.textContaining('Sabtu'), findsOneWidget);
      expect(find.text('4 data'), findsOneWidget);
    });

    testWidgets('filter absensi berdasarkan status berfungsi',
        (tester) async {
      final absensiList = [
        createAbsensi(id: '1', jam: '08:00', nama: 'Budi', kelas: 'X-A', status: 'hadir'),
        createAbsensi(id: '2', jam: '09:00', nama: 'Siti', kelas: 'X-A', status: 'sakit'),
        createAbsensi(id: '3', jam: '10:00', nama: 'Andi', kelas: 'X-A', status: 'hadir'),
      ];

      when(mockFirestore.getAllAbsensi()).thenAnswer(
        (_) => Stream<List<Absensi>>.value(absensiList),
      );
      when(mockFirestore.getSiswaStream()).thenAnswer(
        (_) => Stream<List<Siswa>>.value([]),
      );
      when(mockFirestore.getAllGuru()).thenAnswer(
        (_) => Future.value([]),
      );

      await tester.pumpWidget(buildOlahDataScreen());
      await tester.pumpAndSettle();

      // Verifikasi semua data tampil awal
      expect(find.text('Budi'), findsOneWidget);
      expect(find.text('Siti'), findsOneWidget);
      expect(find.text('Andi'), findsOneWidget);

      // Tap dropdown filter
      await tester.tap(find.byType(DropdownButton<String?>).first);
      await tester.pumpAndSettle();

      // Tap "Sakit" dari menu dropdown (yang muncul di overlay)
      await tester.tap(find.text('Sakit').last);
      await tester.pumpAndSettle();

      // Setelah filter, hanya Siti yang tampil (status sakit)
      expect(find.text('Siti'), findsOneWidget);
    });

    testWidgets('search absensi berdasarkan nama siswa berfungsi',
        (tester) async {
      final absensiList = [
        createAbsensi(id: '1', jam: '08:00', nama: 'Budi Santoso', kelas: 'X-A'),
        createAbsensi(id: '2', jam: '10:30', nama: 'Siti Aminah', kelas: 'X-B'),
        createAbsensi(id: '3', jam: '07:15', nama: 'Budi Utomo', kelas: 'X-C'),
      ];

      when(mockFirestore.getAllAbsensi()).thenAnswer(
        (_) => Stream<List<Absensi>>.value(absensiList),
      );
      when(mockFirestore.getSiswaStream()).thenAnswer(
        (_) => Stream<List<Siswa>>.value([]),
      );
      when(mockFirestore.getAllGuru()).thenAnswer(
        (_) => Future.value([]),
      );

      await tester.pumpWidget(buildOlahDataScreen());
      await tester.pumpAndSettle();

      // Ketik "Siti" di search field
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'siti');
      await tester.pumpAndSettle();

      // Hanya Siti yang tampil
      expect(find.text('Siti Aminah'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsNothing);
      expect(find.text('Budi Utomo'), findsNothing);
    });
  });

  group('OlahDataScreen — Daftar Guru tab', () {
    testWidgets('menampilkan data guru dari Firestore', (tester) async {
      final guruList = [
        Guru(id: 'g1', nama: 'Susi Susanti', email: 'susi@school.sch.id', createdAt: DateTime(2025, 1, 15)),
        Guru(id: 'g2', nama: 'Bambang Pamungkas', email: 'bambang@school.sch.id', createdAt: DateTime(2025, 3, 20)),
      ];

      when(mockFirestore.getAllAbsensi()).thenAnswer(
        (_) => Stream<List<Absensi>>.value([]),
      );
      when(mockFirestore.getSiswaStream()).thenAnswer(
        (_) => Stream<List<Siswa>>.value([]),
      );
      when(mockFirestore.getAllGuru()).thenAnswer(
        (_) => Future.value(guruList),
      );

      await tester.pumpWidget(buildOlahDataScreen());
      await tester.pumpAndSettle();

      // Switch ke tab Daftar Guru
      await tester.tap(find.text('Daftar Guru'));
      await tester.pumpAndSettle();

      // Verifikasi data guru muncul
      expect(find.text('Susi Susanti'), findsOneWidget);
      expect(find.text('Bambang Pamungkas'), findsOneWidget);
      expect(find.text('susi@school.sch.id'), findsOneWidget);
      expect(find.text('bambang@school.sch.id'), findsOneWidget);
    });
  });

  group('OlahDataScreen — Stats row', () {
    testWidgets('menampilkan statistik yang benar', (tester) async {
      final absensiList = [
        createAbsensi(id: '1', jam: '08:00', nama: 'Budi', kelas: 'X-A'),
        createAbsensi(id: '2', jam: '09:00', nama: 'Siti', kelas: 'X-B'),
      ];

      when(mockFirestore.getAllAbsensi()).thenAnswer(
        (_) => Stream<List<Absensi>>.value(absensiList),
      );
      when(mockFirestore.getSiswaStream()).thenAnswer(
        (_) => Stream<List<Siswa>>.value([
          Siswa(id: 's1', nama: 'Budi', nis: '001', kelas: 'X-A', namaOrtu: 'Bpk Budi', hpOrtu: '0812', createdAt: DateTime.now()),
        ]),
      );
      when(mockFirestore.getAllGuru()).thenAnswer(
        (_) => Future.value([
          Guru(id: 'g1', nama: 'Guru 1', email: 'g1@school.sch.id', createdAt: DateTime.now()),
        ]),
      );

      await tester.pumpWidget(buildOlahDataScreen());
      await tester.pumpAndSettle();

      // Statistik: Absensi=2, Siswa=1, Guru=1
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsWidgets); // siswa dan guru sama-sama 1
    });
  });
}
