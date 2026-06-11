import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:absensi_siswa/models/absensi.dart';

void main() {
  /// Helper: creates an Absensi with default values for testing
  Absensi createAbsensi({
    required String id,
    required String jam,
    String status = 'hadir',
    String nama = 'Test Siswa',
    String kelas = 'X-A',
  }) {
    return Absensi(
      id: id,
      siswaId: 'siswa-$id',
      siswaNama: nama,
      kelas: kelas,
      tanggal: DateTime.now(),
      status: status,
      jam: jam,
      guruId: 'guru-1',
    );
  }

  // ============================================================
  // Sorting logic — ini adalah logika yang kita perbaiki
  // dari .orderBy('jam') di Firestore menjadi sort di Dart
  // ============================================================
  group('Sorting absensi by jam descending', () {
    test('mengurutkan beberapa data dari jam terbaru ke terlama', () {
      final list = [
        createAbsensi(id: '1', jam: '08:00'),
        createAbsensi(id: '2', jam: '10:30'),
        createAbsensi(id: '3', jam: '07:15'),
        createAbsensi(id: '4', jam: '13:45'),
      ];

      // Ini adalah logika sorting yang ada di getAbsensiHariIni
      list.sort((a, b) => b.jam.compareTo(a.jam));

      expect(list.length, equals(4));
      expect(list[0].jam, equals('13:45'));
      expect(list[1].jam, equals('10:30'));
      expect(list[2].jam, equals('08:00'));
      expect(list[3].jam, equals('07:15'));
      expect(list[0].id, equals('4'));
      expect(list[1].id, equals('2'));
      expect(list[2].id, equals('1'));
      expect(list[3].id, equals('3'));
    });

    test('data dengan jam yang sama tetap stabil', () {
      final list = [
        createAbsensi(id: '1', jam: '08:00', nama: 'Andi'),
        createAbsensi(id: '2', jam: '08:00', nama: 'Budi'),
        createAbsensi(id: '3', jam: '07:00', nama: 'Caca'),
      ];

      list.sort((a, b) => b.jam.compareTo(a.jam));

      expect(list[0].jam, equals('08:00'));
      expect(list[1].jam, equals('08:00'));
      expect(list[2].jam, equals('07:00'));
    });

    test('data dengan jam kosong ditempatkan di akhir', () {
      final list = [
        createAbsensi(id: '1', jam: '10:00'),
        createAbsensi(id: '2', jam: ''),
        createAbsensi(id: '3', jam: '08:00'),
      ];

      list.sort((a, b) => b.jam.compareTo(a.jam));

      expect(list[0].jam, equals('10:00'));
      expect(list[1].jam, equals('08:00'));
      expect(list[2].jam, equals(''));
    });

    test('list kosong tidak error', () {
      final list = <Absensi>[];
      list.sort((a, b) => b.jam.compareTo(a.jam));
      expect(list, isEmpty);
    });

    test('list dengan 1 item tidak berubah', () {
      final list = [createAbsensi(id: '1', jam: '09:00')];
      list.sort((a, b) => b.jam.compareTo(a.jam));
      expect(list.length, equals(1));
      expect(list.first.jam, equals('09:00'));
    });

    test('jam dengan format 24 jam (HH:mm) diurutkan secara alphabetical', () {
      final list = [
        createAbsensi(id: '1', jam: '23:59'),
        createAbsensi(id: '2', jam: '00:01'),
        createAbsensi(id: '3', jam: '12:00'),
      ];

      list.sort((a, b) => b.jam.compareTo(a.jam));

      // '23:59' > '12:00' > '00:01' (string comparison works for 24h format)
      expect(list[0].jam, equals('23:59'));
      expect(list[1].jam, equals('12:00'));
      expect(list[2].jam, equals('00:01'));
    });
  });

  // ============================================================
  // Date range computation — logika untuk filter tanggal hari ini
  // ============================================================
  group('Date range computation for getAbsensiHariIni', () {
    test('menghitung start dan end dari DateTime yang diberikan', () {
      final testDate = DateTime(2026, 5, 25, 14, 30, 45);
      final start = DateTime(testDate.year, testDate.month, testDate.day);
      final end = start.add(const Duration(days: 1));

      expect(start, equals(DateTime(2026, 5, 25)));
      expect(start.hour, equals(0));
      expect(start.minute, equals(0));
      expect(start.second, equals(0));
      expect(end, equals(DateTime(2026, 5, 26)));
    });

    test('bekerja dengan tanggal yang berbeda-beda', () {
      final dates = [
        DateTime(2026, 1, 1),
        DateTime(2026, 12, 31, 23, 59),
        DateTime(2026, 6, 15, 8, 0),
      ];

      for (final date in dates) {
        final start = DateTime(date.year, date.month, date.day);
        final end = start.add(const Duration(days: 1));

        expect(start.year, equals(date.year));
        expect(start.month, equals(date.month));
        expect(start.day, equals(date.day));
        expect(start.hour, equals(0));
        // end = start + 1 day, including across month/year boundaries
        expect(end.difference(start).inDays, equals(1));
      }
    });
  });

  // ============================================================
  // Absensi.fromMap — memetakan data Firestore ke model Absensi
  // ============================================================
  group('Absensi.fromMap mapping', () {
    test('memetakan data lengkap dari Firestore ke Absensi', () {
      final now = DateTime.now();
      final data = {
        'siswaId': 'siswa-1',
        'siswaNama': 'Budi Santoso',
        'kelas': 'X-A',
        'tanggal': Timestamp.fromDate(now),
        'status': 'hadir',
        'jam': '08:00',
        'dikirim': true,
        'guruId': 'guru-1',
      };

      final absensi = Absensi.fromMap(data, 'abs-1');

      expect(absensi.id, equals('abs-1'));
      expect(absensi.siswaId, equals('siswa-1'));
      expect(absensi.siswaNama, equals('Budi Santoso'));
      expect(absensi.kelas, equals('X-A'));
      expect(absensi.status, equals('hadir'));
      expect(absensi.jam, equals('08:00'));
      expect(absensi.dikirim, isTrue);
      expect(absensi.guruId, equals('guru-1'));
      expect(absensi.fotoUrl, isNull);
    });

    test('data dengan field null menggunakan nilai default', () {
      final data = <String, dynamic>{};

      final absensi = Absensi.fromMap(data, 'abs-2');

      expect(absensi.id, equals('abs-2'));
      expect(absensi.siswaId, equals(''));
      expect(absensi.siswaNama, equals(''));
      expect(absensi.kelas, equals(''));
      expect(absensi.status, equals('hadir')); // default di model
      expect(absensi.jam, equals(''));
      expect(absensi.dikirim, isFalse);
      expect(absensi.guruId, equals(''));
      expect(absensi.fotoUrl, isNull);
    });

    test('data dengan field status kosong tetap valid', () {
      final data = {
        'siswaId': 'siswa-3',
        'siswaNama': 'Caca',
        'status': '',
        'jam': '10:00',
        'guruId': 'guru-1',
      };

      final absensi = Absensi.fromMap(data, 'abs-3');

      expect(absensi.status, equals(''));
      expect(absensi.jam, equals('10:00'));
    });

    test('data dengan dikirim string tetap diparsed dengan benar', () {
      final data = {
        'dikirim': 'true', // string, bukan boolean
        'siswaId': '1', 'siswaNama': 'a', 'kelas': 'a',
        'status': 'hadir', 'jam': '08:00', 'guruId': '1',
      };

      final absensi = Absensi.fromMap(data, 'abs-4');

      // 'true' == true -> false karena bukan boolean
      expect(absensi.dikirim, isFalse);
    });
  });

  // ============================================================
  // Absensi.toMap — memetakan model Absensi ke Firestore document
  // ============================================================
  group('Absensi.toMap', () {
    test('mengkonversi Absensi ke Map dengan benar', () {
            final absensi = createAbsensi(id: '1', jam: '08:00');

      final map = absensi.toMap();

      expect(map['siswaId'], equals('siswa-1'));
      expect(map['siswaNama'], equals('Test Siswa'));
      expect(map['kelas'], equals('X-A'));
      expect(map['status'], equals('hadir'));
      expect(map['jam'], equals('08:00'));
      expect(map['guruId'], equals('guru-1'));
      expect(map['dikirim'], isFalse);
      expect(map['tanggal'], isA<Timestamp>());
      expect(map.containsKey('fotoUrl'), isFalse);
    });

    test('fotoUrl dimasukkan ke Map jika tidak null', () {
      final absensi = Absensi(
        id: '1',
        siswaId: 's1',
        siswaNama: 'Test',
        kelas: 'X-A',
        tanggal: DateTime.now(),
        status: 'hadir',
        jam: '08:00',
        guruId: 'g1',
        fotoUrl: 'https://example.com/photo.jpg',
      );

      final map = absensi.toMap();

      expect(map['fotoUrl'], equals('https://example.com/photo.jpg'));
    });
  });
}
