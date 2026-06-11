import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:absensi_siswa/models/siswa.dart';

void main() {
  group('Siswa.fromMap', () {
    test('memetakan data lengkap dari Firestore ke Siswa', () {
      final now = DateTime.now();
      final data = {
        'nama': 'Andi Pratama',
        'nis': '2024001',
        'kelas': 'X-A',
        'namaOrtu': 'Bpk. Andi',
        'hpOrtu': '081234567890',
        'fotoUrl': 'https://example.com/andi.jpg',
        'createdAt': Timestamp.fromDate(now),
      };

      final siswa = Siswa.fromMap(data, 'siswa-1');

      expect(siswa.id, equals('siswa-1'));
      expect(siswa.nama, equals('Andi Pratama'));
      expect(siswa.nis, equals('2024001'));
      expect(siswa.kelas, equals('X-A'));
      expect(siswa.namaOrtu, equals('Bpk. Andi'));
      expect(siswa.hpOrtu, equals('081234567890'));
      expect(siswa.fotoUrl, equals('https://example.com/andi.jpg'));
      expect(siswa.createdAt, equals(now));
    });

    test('data dengan field null menggunakan nilai default', () {
      final data = <String, dynamic>{};

      final siswa = Siswa.fromMap(data, 'siswa-2');

      expect(siswa.id, equals('siswa-2'));
      expect(siswa.nama, equals(''));
      expect(siswa.nis, equals(''));
      expect(siswa.kelas, equals(''));
      expect(siswa.namaOrtu, equals(''));
      expect(siswa.hpOrtu, equals(''));
      expect(siswa.fotoUrl, isNull);
      expect(siswa.createdAt, isA<DateTime>());
    });

    test('data dengan fotoUrl null tetap valid', () {
      final now = DateTime.now();
      final data = {
        'nama': 'Budi',
        'nis': '2024002',
        'kelas': 'X-A',
        'namaOrtu': 'Bpk. Budi',
        'hpOrtu': '081234567891',
        'createdAt': Timestamp.fromDate(now),
      };

      final siswa = Siswa.fromMap(data, 'siswa-3');

      expect(siswa.nama, equals('Budi'));
      expect(siswa.fotoUrl, isNull);
    });

    test('data dengan field string kosong tetap valid', () {
      final now = DateTime.now();
      final data = {
        'nama': 'Caca',
        'nis': '',
        'kelas': 'X-A',
        'namaOrtu': '',
        'hpOrtu': '',
        'createdAt': Timestamp.fromDate(now),
      };

      final siswa = Siswa.fromMap(data, 'siswa-4');

      expect(siswa.nis, equals(''));
      expect(siswa.namaOrtu, equals(''));
      expect(siswa.hpOrtu, equals(''));
    });
  });

  group('Siswa.toMap', () {
    test('mengkonversi Siswa ke Map dengan benar', () {
      final now = DateTime.now();
      final siswa = Siswa(
        id: 'siswa-1',
        nama: 'Andi Pratama',
        nis: '2024001',
        kelas: 'X-A',
        namaOrtu: 'Bpk. Andi',
        hpOrtu: '081234567890',
        fotoUrl: 'https://example.com/andi.jpg',
        createdAt: now,
      );

      final map = siswa.toMap();

      expect(map['nama'], equals('Andi Pratama'));
      expect(map['nis'], equals('2024001'));
      expect(map['kelas'], equals('X-A'));
      expect(map['namaOrtu'], equals('Bpk. Andi'));
      expect(map['hpOrtu'], equals('081234567890'));
      expect(map['fotoUrl'], equals('https://example.com/andi.jpg'));
      expect(map['createdAt'], isA<Timestamp>());
      expect((map['createdAt'] as Timestamp).toDate(), equals(now));
    });

    test('toMap tidak menyertakan fotoUrl jika null', () {
      final now = DateTime.now();
      final siswa = Siswa(
        id: 'siswa-2',
        nama: 'Budi',
        nis: '2024002',
        kelas: 'X-A',
        namaOrtu: 'Bpk. Budi',
        hpOrtu: '081234567891',
        createdAt: now,
      );

      final map = siswa.toMap();

      expect(map['fotoUrl'], isNull);
    });

    test('toMap lalu fromMap menghasilkan objek yang setara', () {
      final now = DateTime.now();
      final siswa = Siswa(
        id: 'siswa-1',
        nama: 'Andi Pratama',
        nis: '2024001',
        kelas: 'X-A',
        namaOrtu: 'Bpk. Andi',
        hpOrtu: '081234567890',
        fotoUrl: 'https://example.com/andi.jpg',
        createdAt: now,
      );

      final map = siswa.toMap();
      final restored = Siswa.fromMap(map, 'siswa-1');

      expect(restored.nama, equals(siswa.nama));
      expect(restored.nis, equals(siswa.nis));
      expect(restored.kelas, equals(siswa.kelas));
      expect(restored.namaOrtu, equals(siswa.namaOrtu));
      expect(restored.hpOrtu, equals(siswa.hpOrtu));
      expect(restored.fotoUrl, equals(siswa.fotoUrl));
      expect(restored.createdAt, equals(siswa.createdAt));
    });
  });

  group('Siswa constructor', () {
    test('membuat objek Siswa dengan nilai minimal', () {
      final now = DateTime.now();
      final siswa = Siswa(
        id: 'siswa-min',
        nama: 'Min',
        nis: '0000',
        kelas: 'X-A',
        namaOrtu: 'Orang Tua',
        hpOrtu: '081234567890',
        createdAt: now,
      );

      expect(siswa.id, equals('siswa-min'));
      expect(siswa.fotoUrl, isNull);
    });
  });
}
