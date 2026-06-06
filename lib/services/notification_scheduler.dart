import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter/widgets.dart';
import '../firebase_options.dart';
import 'firestore_service.dart';
import 'whatsapp_service.dart';

const String _autoNotifyEnabledKey = 'auto_notify_enabled';
const String _autoNotifyHourKey = 'auto_notify_hour';
const String _autoNotifyMinuteKey = 'auto_notify_minute';
const String _autoNotifyKelasKey = 'auto_notify_kelas';
const String _periodicTaskName = 'periodic_notification_task';
const String _periodicTaskUniqueName = 'com.absensi_siswa.periodic_notification';

class NotificationScheduler {
  /// Inisialisasi Workmanager (panggil sekali di main())
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
    );
  }

  /// Register periodic task yang berjalan setiap 15 menit
  static Future<void> schedulePeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      _periodicTaskUniqueName,
      _periodicTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  /// Hentikan periodic task
  static Future<void> cancelPeriodicTask() async {
    await Workmanager().cancelByUniqueName(_periodicTaskUniqueName);
  }

  /// Ambil pengaturan dari SharedPreferences
  static Future<({bool enabled, int hour, int minute, String? kelas})> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_autoNotifyEnabledKey) ?? false;
    final hour = prefs.getInt(_autoNotifyHourKey) ?? 14;
    final minute = prefs.getInt(_autoNotifyMinuteKey) ?? 0;
    final kelas = prefs.getString(_autoNotifyKelasKey);
    return (enabled: enabled, hour: hour, minute: minute, kelas: kelas);
  }

  /// Simpan pengaturan dan kelola task (schedule/cancel)
  static Future<void> saveSettings({
    required bool enabled,
    required int hour,
    required int minute,
    String? kelas,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoNotifyEnabledKey, enabled);
    await prefs.setInt(_autoNotifyHourKey, hour);
    await prefs.setInt(_autoNotifyMinuteKey, minute);
    if (kelas != null) {
      await prefs.setString(_autoNotifyKelasKey, kelas);
    } else {
      await prefs.remove(_autoNotifyKelasKey);
    }

    if (enabled) {
      await schedulePeriodicTask();
    } else {
      await cancelPeriodicTask();
    }
  }
}

/// Callback yang didaftarkan ke Workmanager — dipanggil di background isolate
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _periodicTaskName) {
      return Future.value(true);
    }

    try {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {
      // Firebase sudah terinisialisasi atau error — lanjutkan
    }

    await _handlePeriodicNotification();
    return Future.value(true);
  });
}

/// Handler untuk periodic notification — cek jadwal & kirim rekap
Future<void> _handlePeriodicNotification() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_autoNotifyEnabledKey) ?? false;
    if (!enabled) return;

    final hour = prefs.getInt(_autoNotifyHourKey) ?? 14;
    final minute = prefs.getInt(_autoNotifyMinuteKey) ?? 0;
    final filterKelas = prefs.getString(_autoNotifyKelasKey);

    final now = DateTime.now();
    final scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
    final diff = now.difference(scheduledTime).inMinutes.abs();

    // Kirim hanya jika dalam rentang 15 menit dari jadwal
    if (diff > 15) return;

    final fs = FirestoreService();
    final semuaSiswa = await fs.getAllSiswa();
    if (semuaSiswa.isEmpty) return;

    // Filter berdasarkan kelas jika ditentukan
    final siswaFilterKelas = filterKelas != null
        ? semuaSiswa.where((s) => s.kelas == filterKelas).toList()
        : semuaSiswa;

    final siswaDenganHp = siswaFilterKelas
        .where((s) => s.hpOrtu.isNotEmpty)
        .toList();
    if (siswaDenganHp.isEmpty) return;

    final todayStr = DateFormat('dd/MM/yyyy').format(now);
    final absensiHariIni = await fs.getAbsensiHariIni(now).first;

    final statusMap = <String, String>{};
    for (final a in absensiHariIni) {
      statusMap[a.siswaId] = a.status;
    }

    // Kirim ke maksimal 30 siswa per eksekusi biar tidak timeout
    final maxSend = 30;
    final siswaToSend = siswaDenganHp.take(maxSend).toList();

    for (final siswa in siswaToSend) {
      await WhatsAppService.kirimNotifikasiRekapAbsensi(
        hpOrtu: siswa.hpOrtu,
        namaSiswa: siswa.nama,
        status: statusMap[siswa.id] ?? 'Belum absen',
        tanggal: todayStr,
      );
    }
  } catch (e) {
    // Silent fail — background task tidak boleh throw
  }
}
