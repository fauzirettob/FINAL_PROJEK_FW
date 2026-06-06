import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:absensi_siswa/models/guru.dart';

void main() {
  group('Guru.fromMap', () {
    test('memetakan data lengkap dari Firestore ke Guru', () {
      final now = DateTime.now();
      final data = {
        'nama': 'Bpk. Budi Santoso',
        'email': 'budi@school.sch.id',
        'createdAt': Timestamp.fromDate(now),
      };

      final guru = Guru.fromMap(data, 'guru-1');

      expect(guru.id, equals('guru-1'));
      expect(guru.nama, equals('Bpk. Budi Santoso'));
      expect(guru.email, equals('budi@school.sch.id'));
      expect(guru.createdAt, equals(now));
    });

    test('data dengan field null menggunakan nilai default', () {
      final data = <String, dynamic>{};

      final guru = Guru.fromMap(data, 'guru-2');

      expect(guru.id, equals('guru-2'));
      expect(guru.nama, equals(''));
      expect(guru.email, equals(''));
      expect(guru.createdAt, isA<DateTime>());
    });

    test('data dengan nama kosong tetap valid', () {
      final now = DateTime.now();
      final data = {
        'nama': '',
        'email': 'test@school.sch.id',
        'createdAt': Timestamp.fromDate(now),
      };

      final guru = Guru.fromMap(data, 'guru-3');

      expect(guru.nama, equals(''));
      expect(guru.email, equals('test@school.sch.id'));
    });
  });

  group('Guru.toMap', () {
    test('mengkonversi Guru ke Map dengan benar', () {
      final now = DateTime.now();
      final guru = Guru(
        id: 'guru-1',
        nama: 'Bpk. Budi Santoso',
        email: 'budi@school.sch.id',
        createdAt: now,
      );

      final map = guru.toMap();

      expect(map['nama'], equals('Bpk. Budi Santoso'));
      expect(map['email'], equals('budi@school.sch.id'));
      expect(map['createdAt'], isA<Timestamp>());
      expect((map['createdAt'] as Timestamp).toDate(), equals(now));
    });

    test('toMap lalu fromMap menghasilkan objek yang setara', () {
      final now = DateTime.now();
      final guru = Guru(
        id: 'guru-1',
        nama: 'Bpk. Budi Santoso',
        email: 'budi@school.sch.id',
        createdAt: now,
      );

      final map = guru.toMap();
      final restored = Guru.fromMap(map, 'guru-1');

      expect(restored.nama, equals(guru.nama));
      expect(restored.email, equals(guru.email));
      expect(restored.createdAt, equals(guru.createdAt));
    });
  });

  group('Guru constructor', () {
    test('membuat objek Guru dengan nilai minimal', () {
      final now = DateTime.now();
      final guru = Guru(
        id: 'guru-min',
        nama: 'Min',
        email: 'min@school.sch.id',
        createdAt: now,
      );

      expect(guru.id, equals('guru-min'));
      expect(guru.nama, equals('Min'));
      expect(guru.email, equals('min@school.sch.id'));
      expect(guru.createdAt, equals(now));
    });

    test('dua objek Guru dengan data sama memiliki properti yang sama', () {
      final now = DateTime.now();
      final guru1 = Guru(
        id: 'guru-x',
        nama: 'X',
        email: 'x@school.sch.id',
        createdAt: now,
      );
      final guru2 = Guru(
        id: 'guru-x',
        nama: 'X',
        email: 'x@school.sch.id',
        createdAt: now,
      );

      expect(guru1.id, equals(guru2.id));
      expect(guru1.nama, equals(guru2.nama));
      expect(guru1.email, equals(guru2.email));
      expect(guru1.createdAt, equals(guru2.createdAt));
    });
  });
}
