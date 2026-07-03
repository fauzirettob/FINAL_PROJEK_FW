import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  // GANTI DENGAN TOKEN FONNTE ANDA
  static const String _token = 'kZjToexgoEcpC8zcrvYn';
  static const String _url = 'https://api.fonnte.com/send';

  /// Format nomor HP ke format internasional (62...)
  /// Handle prefix: 0, 62, +62, serta spasi, dash, titik, slash, dan kurung
  static String _formatNomor(String hp) {
    // Bersihkan spasi, dash, titik, slash, kurung, dan karakter non-digit lainnya
    String bersih = hp.trim().replaceAll(RegExp(r'[\s\-()./]'), '');

    if (bersih.isEmpty) return '';

    if (bersih.startsWith('+')) {
      // +628123456789 → 628123456789
      return bersih.substring(1);
    }
    if (bersih.startsWith('0')) {
      // 08123456789 → 628123456789
      return '62${bersih.substring(1)}';
    }
    if (bersih.startsWith('62')) {
      // 628123456789 → 628123456789
      return bersih;
    }
    // Fallback: 8123456789 → 628123456789
    return '62$bersih';
  }

  /// Buka WhatsApp chat ke nomor orang tua siswa
  static Future<void> bukaWhatsApp(String hpOrtu) async {
    final target = _formatNomor(hpOrtu);
    final uri = Uri.parse('https://wa.me/$target');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<bool> kirimNotifikasi({
    required String hpOrtu,
    required String namaSiswa,
    required String status,
    required String tanggal,
    required String jam,
    http.Client? client,
  }) async {
    final target = _formatNomor(hpOrtu);

    final pesan =
        '''
*Notifikasi Kehadiran Siswa*

Yth. Orang Tua/Wali,
Putra/Putri Anda *$namaSiswa* tercatat:
Status: *$status*
Tanggal: $tanggal
Jam: $jam

Terima kasih.
Guru SMA AS-SAMA AMBON 
''';

    debugPrint('📤 WA kirimNotifikasi → target=$target, nama=$namaSiswa, status=$status');

    try {
      final httpClient = client ?? http.Client();
      try {
        final res = await httpClient.post(
          Uri.parse(_url),
          headers: {'Authorization': _token},
          body: {'target': target, 'message': pesan},
        );
        final bodyStr = res.body;
        if (res.statusCode == 200) {
          debugPrint('✅ WA berhasil terkirim ke $target: $bodyStr');
          return true;
        } else {
          debugPrint('❌ WA gagal (${res.statusCode}) ke $target: $bodyStr');
          return false;
        }
      } finally {
        if (client == null) httpClient.close();
      }
    } catch (e) {
      debugPrint('❌ WA error saat kirim ke $target: $e');
      return false;
    }
  }

  /// Kirim notifikasi rekap absensi harian ke orang tua siswa
  static Future<bool> kirimNotifikasiRekapAbsensi({
    required String hpOrtu,
    required String namaSiswa,
    required String status,
    required String tanggal,
    http.Client? client,
  }) async {
    final target = _formatNomor(hpOrtu);

    final statusLabels = {
      'hadir': '✅ Hadir',
      'izin': '📝 Izin',
      'sakit': '🤒 Sakit',
      'alpa': '❌ Alpa',
    };

    final displayStatus = statusLabels[status] ?? status;

    final pesan =
        '''
*Rekap Absensi Harian - SAM*

Yth. Orang Tua/Wali,

Berikut rekap kehadiran putra/i Anda hari ini:

👤 Nama: *$namaSiswa*
📋 Status: $displayStatus
📅 Tanggal: $tanggal

Terima kasih.
- Guru SMA AS-SAMA AMBON 
''';

    debugPrint('📤 WA kirimNotifikasiRekapAbsensi → target=$target, nama=$namaSiswa, status=$status');

    try {
      final httpClient = client ?? http.Client();
      try {
        final res = await httpClient.post(
          Uri.parse(_url),
          headers: {'Authorization': _token},
          body: {'target': target, 'message': pesan},
        );
        final bodyStr = res.body;
        if (res.statusCode == 200) {
          debugPrint('✅ WA Rekap berhasil terkirim ke $target: $bodyStr');
          return true;
        } else {
          debugPrint('❌ WA Rekap gagal (${res.statusCode}) ke $target: $bodyStr');
          return false;
        }
      } finally {
        if (client == null) httpClient.close();
      }
    } catch (e) {
      debugPrint('❌ WA Rekap error saat kirim ke $target: $e');
      return false;
    }
  }
}
