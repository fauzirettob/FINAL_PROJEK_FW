import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  // GANTI DENGAN TOKEN FONNTE ANDA
  static const String _token = 'eRU3ZNqSZ2gEZ6Lg7k8k';
  static const String _url = 'https://api.fonnte.com/send';

  /// Format nomor HP ke format internasional (62...)
  static String _formatNomor(String hp) {
    return hp.startsWith('0')
        ? '62${hp.substring(1)}'
        : hp.startsWith('62')
            ? hp
            : '62$hp';
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
Guru SMA Negeri 11 Ambon
''';

    try {
      final httpClient = client ?? http.Client();
      try {
        final res = await httpClient.post(
          Uri.parse(_url),
          headers: {'Authorization': _token},
          body: {'target': target, 'message': pesan},
        );
        if (res.statusCode == 200) {
          debugPrint('WA berhasil terkirim ke $target');
          return true;
        } else {
          debugPrint('WA gagal (${res.statusCode}): ${res.body}');
          return false;
        }
      } finally {
        if (client == null) httpClient.close();
      }
    } catch (e) {
      debugPrint('WA error: $e');
      return false;
    }
  }

  /// Kirim notifikasi teguran (peringatan) ke orang tua siswa
  static Future<bool> kirimNotifikasiTeguran({
    required String hpOrtu,
    required String namaSiswa,
    required String judul,
    required String deskripsi,
    required String tanggal,
    http.Client? client,
  }) async {
    final target = _formatNomor(hpOrtu);

    final pesan =
        '''
*⚠️ Teguran Siswa - SAM*

Yth. Orang Tua/Wali,

Putra/i Anda *$namaSiswa* mendapatkan teguran dari sekolah:

📋 *Judul:* $judul
📝 *Deskripsi:* $deskripsi
📅 *Tanggal:* $tanggal

Mohon perhatian dan bimbingan untuk putra/Putri Anda.

Terima kasih.
- Guru SMA Negeri 11 Ambon
''';

    try {
      final httpClient = client ?? http.Client();
      try {
        final res = await httpClient.post(
          Uri.parse(_url),
          headers: {'Authorization': _token},
          body: {'target': target, 'message': pesan},
        );
        if (res.statusCode == 200) {
          debugPrint('WA Teguran berhasil terkirim ke $target');
          return true;
        } else {
          debugPrint('WA Teguran gagal (${res.statusCode}): ${res.body}');
          return false;
        }
      } finally {
        if (client == null) httpClient.close();
      }
    } catch (e) {
      debugPrint('WA Teguran error: $e');
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
- Guru SMA Negeri 11 Ambon
''';

    try {
      final httpClient = client ?? http.Client();
      try {
        final res = await httpClient.post(
          Uri.parse(_url),
          headers: {'Authorization': _token},
          body: {'target': target, 'message': pesan},
        );
        if (res.statusCode == 200) {
          debugPrint('WA Rekap berhasil terkirim ke $target');
          return true;
        } else {
          debugPrint('WA Rekap gagal (${res.statusCode}): ${res.body}');
          return false;
        }
      } finally {
        if (client == null) httpClient.close();
      }
    } catch (e) {
      debugPrint('WA Rekap error: $e');
      return false;
    }
  }
}
