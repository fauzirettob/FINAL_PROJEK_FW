import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:absensi_siswa/services/notification_scheduler.dart';

void main() {
  group('NotificationScheduler.getSettings', () {
    test('mengembalikan nilai default saat belum ada pengaturan', () async {
      SharedPreferences.setMockInitialValues({});

      final settings = await NotificationScheduler.getSettings();

      expect(settings.enabled, isFalse);
      expect(settings.hour, equals(14));
      expect(settings.minute, equals(0));
      expect(settings.kelas, isNull);
    });

    test('mengembalikan nilai yang sudah disimpan di SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'auto_notify_enabled': true,
        'auto_notify_hour': 8,
        'auto_notify_minute': 30,
        'auto_notify_kelas': 'X-A',
      });

      final settings = await NotificationScheduler.getSettings();

      expect(settings.enabled, isTrue);
      expect(settings.hour, equals(8));
      expect(settings.minute, equals(30));
      expect(settings.kelas, equals('X-A'));
    });

    test('mengembalikan false untuk enabled jika tidak diset', () async {
      SharedPreferences.setMockInitialValues({
        'auto_notify_hour': 10,
      });

      final settings = await NotificationScheduler.getSettings();

      expect(settings.enabled, isFalse);
      expect(settings.hour, equals(10));
    });

    test('mengembalikan kelas null jika tidak diset', () async {
      SharedPreferences.setMockInitialValues({
        'auto_notify_enabled': true,
      });

      final settings = await NotificationScheduler.getSettings();

      expect(settings.enabled, isTrue);
      expect(settings.kelas, isNull);
    });
  });

  group('NotificationScheduler.saveSettings', () {
    test('menyimpan pengaturan ke SharedPreferences (Workmanager error diabaikan)', () async {
      SharedPreferences.setMockInitialValues({});

      // saveSettings juga memanggil Workmanager (schedule/cancel task)
      // yang tidak tersedia di test environment — error diabaikan
      try {
        await NotificationScheduler.saveSettings(
          enabled: true,
          hour: 10,
          minute: 30,
          kelas: 'X-A',
        );
      } catch (_) {
        // Workmanager tidak tersedia di test — expected
      }

      final settings = await NotificationScheduler.getSettings();

      expect(settings.enabled, isTrue);
      expect(settings.hour, equals(10));
      expect(settings.minute, equals(30));
      expect(settings.kelas, equals('X-A'));
    });

    test('menghapus kelas dari SharedPreferences saat kelas null', () async {
      SharedPreferences.setMockInitialValues({
        'auto_notify_enabled': true,
        'auto_notify_hour': 14,
        'auto_notify_minute': 0,
        'auto_notify_kelas': 'X-A',
      });

      try {
        await NotificationScheduler.saveSettings(
          enabled: false,
          hour: 14,
          minute: 0,
        );
      } catch (_) {
        // Workmanager tidak tersedia di test — expected
      }

      final settings = await NotificationScheduler.getSettings();

      expect(settings.enabled, isFalse);
      expect(settings.kelas, isNull);
    });

    test('mengubah nilai jam dan menit', () async {
      SharedPreferences.setMockInitialValues({
        'auto_notify_enabled': true,
        'auto_notify_hour': 14,
        'auto_notify_minute': 0,
      });

      try {
        await NotificationScheduler.saveSettings(
          enabled: true,
          hour: 7,
          minute: 45,
        );
      } catch (_) {
        // Workmanager tidak tersedia di test — expected
      }

      final settings = await NotificationScheduler.getSettings();

      expect(settings.hour, equals(7));
      expect(settings.minute, equals(45));
    });
  });
}
