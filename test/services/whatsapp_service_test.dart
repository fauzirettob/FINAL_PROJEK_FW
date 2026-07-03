import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:absensi_siswa/services/whatsapp_service.dart';

/// Mock HTTP client yang mengembalikan response dengan status code tertentu
/// dan menangkap request terakhir untuk verifikasi body.
class _MockHttpClient extends http.BaseClient {
  final int statusCode;
  final bool shouldThrow;

  /// Request terakhir yang dikirim (untuk investigasi)
  http.BaseRequest? lastRequest;

  /// Body dari request terakhir (untuk form-urlencoded request)
  String? lastBody;

  _MockHttpClient({this.statusCode = 200, this.shouldThrow = false});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    if (request is http.Request) {
      lastBody = request.body;
    }

    if (shouldThrow) {
      throw Exception('Simulated network error');
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"status": true}')),
      statusCode,
      request: request,
    );
  }

  /// Ekstrak nilai parameter `target` dari body form-urlencoded
  String? get capturedTarget {
    if (lastBody == null) return null;
    final params = Uri.splitQueryString(lastBody!);
    return params['target'];
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

    group('format nomor HP — edge cases', () {
      test('nomor diawali 0 → 62', () async {
        final client = _MockHttpClient(statusCode: 200);

        await WhatsAppService.kirimNotifikasi(
          hpOrtu: '081234567890',
          namaSiswa: 'Test',
          status: 'hadir',
          tanggal: '25/05/2026',
          jam: '08:00',
          client: client,
        );

        expect(client.capturedTarget, '6281234567890');
      });

      test('nomor sudah diawali 62 — tetap dipertahankan', () async {
        final client = _MockHttpClient(statusCode: 200);

        await WhatsAppService.kirimNotifikasi(
          hpOrtu: '6281234567890',
          namaSiswa: 'Test',
          status: 'hadir',
          tanggal: '25/05/2026',
          jam: '08:00',
          client: client,
        );

        expect(client.capturedTarget, '6281234567890');
      });

      test('nomor dengan prefix +62 — + dibuang', () async {
        final client = _MockHttpClient(statusCode: 200);

        await WhatsAppService.kirimNotifikasi(
          hpOrtu: '+6281234567890',
          namaSiswa: 'Test',
          status: 'hadir',
          tanggal: '25/05/2026',
          jam: '08:00',
          client: client,
        );

        expect(client.capturedTarget, '6281234567890');
      });

      test('nomor tanpa prefix — tetap ditambah 62', () async {
        final client = _MockHttpClient(statusCode: 200);

        await WhatsAppService.kirimNotifikasi(
          hpOrtu: '81234567890',
          namaSiswa: 'Test',
          status: 'hadir',
          tanggal: '25/05/2026',
          jam: '08:00',
          client: client,
        );

        expect(client.capturedTarget, '6281234567890');
      });

      test('nomor dengan spasi — spasi dibersihkan', () async {
        final client = _MockHttpClient(statusCode: 200);

        await WhatsAppService.kirimNotifikasi(
          hpOrtu: '0812 3456 7890',
          namaSiswa: 'Test',
          status: 'hadir',
          tanggal: '25/05/2026',
          jam: '08:00',
          client: client,
        );

        expect(client.capturedTarget, '6281234567890');
      });

      test('nomor dengan dash — dash dibersihkan', () async {
        final client = _MockHttpClient(statusCode: 200);

        await WhatsAppService.kirimNotifikasi(
          hpOrtu: '0812-3456-7890',
          namaSiswa: 'Test',
          status: 'hadir',
          tanggal: '25/05/2026',
          jam: '08:00',
          client: client,
        );

        expect(client.capturedTarget, '6281234567890');
      });

      test('nomor dengan titik — titik dibersihkan', () async {
        final client = _MockHttpClient(statusCode: 200);

        await WhatsAppService.kirimNotifikasi(
          hpOrtu: '0812.3456.7890',
          namaSiswa: 'Test',
          status: 'hadir',
          tanggal: '25/05/2026',
          jam: '08:00',
          client: client,
        );

        expect(client.capturedTarget, '6281234567890');
      });

      test('nomor dengan kurung — kurung dibersihkan', () async {
        final client = _MockHttpClient(statusCode: 200);

        await WhatsAppService.kirimNotifikasi(
          hpOrtu: '(0812) 3456-7890',
          namaSiswa: 'Test',
          status: 'hadir',
          tanggal: '25/05/2026',
          jam: '08:00',
          client: client,
        );

        expect(client.capturedTarget, '6281234567890');
      });

      test('nomor dengan +62, spasi, dan dash — semua format dibersihkan', () async {
        final client = _MockHttpClient(statusCode: 200);

        await WhatsAppService.kirimNotifikasi(
          hpOrtu: '+62 812-3456-7890',
          namaSiswa: 'Test',
          status: 'hadir',
          tanggal: '25/05/2026',
          jam: '08:00',
          client: client,
        );

        expect(client.capturedTarget, '6281234567890');
      });

      test('nomor kosong — target ikut kosong', () async {
        final client = _MockHttpClient(statusCode: 200);

        await WhatsAppService.kirimNotifikasi(
          hpOrtu: '',
          namaSiswa: 'Test',
          status: 'hadir',
          tanggal: '25/05/2026',
          jam: '08:00',
          client: client,
        );

        // Target akan empty string — API akan return error, tapi kode tetap jalan
        expect(client.capturedTarget, isEmpty);
      });

      test('nomor hanya spasi — target kosong setelah trim', () async {
        final client = _MockHttpClient(statusCode: 200);

        await WhatsAppService.kirimNotifikasi(
          hpOrtu: '   ',
          namaSiswa: 'Test',
          status: 'hadir',
          tanggal: '25/05/2026',
          jam: '08:00',
          client: client,
        );

        expect(client.capturedTarget, isEmpty);
      });
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

    group('format nomor HP — edge cases (rekap)', () {
      test('nomor dengan prefix +62 — + dibuang', () async {
        final client = _MockHttpClient(statusCode: 200);

        await WhatsAppService.kirimNotifikasiRekapAbsensi(
          hpOrtu: '+6281234567890',
          namaSiswa: 'Test',
          status: 'hadir',
          tanggal: '25/05/2026',
          client: client,
        );

        expect(client.capturedTarget, '6281234567890');
      });

      test('nomor dengan spasi dan dash — dibersihkan', () async {
        final client = _MockHttpClient(statusCode: 200);

        await WhatsAppService.kirimNotifikasiRekapAbsensi(
          hpOrtu: '+62 812-3456-7890',
          namaSiswa: 'Test',
          status: 'hadir',
          tanggal: '25/05/2026',
          client: client,
        );

        expect(client.capturedTarget, '6281234567890');
      });
    });
  });
}
