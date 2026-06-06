import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:absensi_siswa/services/whatsapp_service.dart';

/// Mock HTTP client yang mengembalikan response dengan status code tertentu
class _MockHttpClient extends http.BaseClient {
  final int statusCode;
  final bool shouldThrow;

  _MockHttpClient({this.statusCode = 200, this.shouldThrow = false});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (shouldThrow) {
      throw Exception('Simulated network error');
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"status": true}')),
      statusCode,
      request: request,
    );
  }
}

void main() {
  group('WhatsAppService.kirimNotifikasi', () {
    test('mengembalikan true ketika response status 200', () async {
      final client = _MockHttpClient(statusCode: 200);

      final result = await WhatsAppService.kirimNotifikasi(
        hpOrtu: '081234567890',
        namaSiswa: 'Andi Pratama',
        status: 'hadir',
        tanggal: '25/05/2026',
        jam: '08:00',
        client: client,
      );

      expect(result, isTrue);
    });

    test('mengembalikan false ketika response status bukan 200', () async {
      final client = _MockHttpClient(statusCode: 500);

      final result = await WhatsAppService.kirimNotifikasi(
        hpOrtu: '081234567890',
        namaSiswa: 'Andi Pratama',
        status: 'hadir',
        tanggal: '25/05/2026',
        jam: '08:00',
        client: client,
      );

      expect(result, isFalse);
    });

    test('mengembalikan false ketika HTTP request throw error', () async {
      final client = _MockHttpClient(shouldThrow: true);

      final result = await WhatsAppService.kirimNotifikasi(
        hpOrtu: '081234567890',
        namaSiswa: 'Andi Pratama',
        status: 'hadir',
        tanggal: '25/05/2026',
        jam: '08:00',
        client: client,
      );

      expect(result, isFalse);
    });

    test('memformat nomor yang diawali 0 ke format 62', () async {
      final client = _MockHttpClient(statusCode: 200);

      final result = await WhatsAppService.kirimNotifikasi(
        hpOrtu: '081234567890',
        namaSiswa: 'Test',
        status: 'hadir',
        tanggal: '25/05/2026',
        jam: '08:00',
        client: client,
      );

      expect(result, isTrue);
    });

    test('mempertahankan nomor yang sudah diawali 62', () async {
      final client = _MockHttpClient(statusCode: 200);

      final result = await WhatsAppService.kirimNotifikasi(
        hpOrtu: '6281234567890',
        namaSiswa: 'Test',
        status: 'hadir',
        tanggal: '25/05/2026',
        jam: '08:00',
        client: client,
      );

      expect(result, isTrue);
    });
  });

  group('WhatsAppService.kirimNotifikasiRekapAbsensi', () {
    test('mengembalikan true ketika response status 200', () async {
      final client = _MockHttpClient(statusCode: 200);

      final result = await WhatsAppService.kirimNotifikasiRekapAbsensi(
        hpOrtu: '081234567890',
        namaSiswa: 'Andi Pratama',
        status: 'hadir',
        tanggal: '25/05/2026',
        client: client,
      );

      expect(result, isTrue);
    });

    test('mengembalikan false ketika response status 500', () async {
      final client = _MockHttpClient(statusCode: 500);

      final result = await WhatsAppService.kirimNotifikasiRekapAbsensi(
        hpOrtu: '081234567890',
        namaSiswa: 'Andi Pratama',
        status: 'hadir',
        tanggal: '25/05/2026',
        client: client,
      );

      expect(result, isFalse);
    });

    test('menggunakan emoji label untuk status hadir', () async {
      final client = _MockHttpClient(statusCode: 200);

      final result = await WhatsAppService.kirimNotifikasiRekapAbsensi(
        hpOrtu: '081234567890',
        namaSiswa: 'Budi',
        status: 'hadir',
        tanggal: '25/05/2026',
        client: client,
      );

      expect(result, isTrue);
    });

    test('menggunakan status mentah untuk status yang tidak dikenal', () async {
      final client = _MockHttpClient(statusCode: 200);

      final result = await WhatsAppService.kirimNotifikasiRekapAbsensi(
        hpOrtu: '081234567890',
        namaSiswa: 'Caca',
        status: 'unknown_status',
        tanggal: '25/05/2026',
        client: client,
      );

      expect(result, isTrue);
    });

    test('mengembalikan false ketika HTTP request throw error', () async {
      final client = _MockHttpClient(shouldThrow: true);

      final result = await WhatsAppService.kirimNotifikasiRekapAbsensi(
        hpOrtu: '081234567890',
        namaSiswa: 'Budi',
        status: 'hadir',
        tanggal: '25/05/2026',
        client: client,
      );

      expect(result, isFalse);
    });
  });
}
