import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:absensi_siswa/widgets/animations.dart';

/// Bungkus widget dengan MediaQuery yang bisa diset reduce motion.
Widget _wrap(Widget child, {bool reduceMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('EntranceAnimation', () {
    testWidgets('langsung menampilkan konten saat reduce motion aktif',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const EntranceAnimation(child: Text('konten')),
            reduceMotion: true),
      );

      // Konten tampil penuh tanpa lapisan animasi (tidak ada Opacity wrapper).
      expect(find.text('konten'), findsOneWidget);
      expect(find.byType(Opacity), findsNothing);
    });

    testWidgets('dengan delay, reduce motion tidak menyisakan timer tertunda',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EntranceAnimation(
            delay: Duration(seconds: 5),
            child: Text('konten'),
          ),
          reduceMotion: true,
        ),
      );

      // Konten tampil langsung; timer delay dibatalkan sehingga tidak ada
      // "Timer is still pending" saat test selesai.
      expect(find.text('konten'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('memutar animasi fade-in saat reduce motion nonaktif',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const EntranceAnimation(child: Text('konten'))),
      );

      // Frame awal: opacity 0 (masih muncul).
      var opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.0);

      await tester.pumpAndSettle();

      // Setelah animasi selesai: opacity penuh.
      opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 1.0);
    });
  });

  group('PressableScale', () {
    testWidgets('tetap bisa diketuk saat reduce motion aktif', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          PressableScale(
            onTap: () => tapped = true,
            child: const Text('kartu'),
          ),
          reduceMotion: true,
        ),
      );

      await tester.tap(find.text('kartu'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('FloatAnimation', () {
    testWidgets('langsung menampilkan konten saat reduce motion aktif',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const FloatAnimation(child: Text('konten')),
            reduceMotion: true),
      );

      expect(find.text('konten'), findsOneWidget);
      // Tidak ada transform melayang di dalam FloatAnimation.
      final floats = find.descendant(
        of: find.byType(FloatAnimation),
        matching: find.byType(Transform),
      );
      expect(floats, findsNothing);
    });

    testWidgets('melayang naik-turun (Transform) saat animasi aktif',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const FloatAnimation(child: Text('konten'))),
      );

      final floats = find.descendant(
        of: find.byType(FloatAnimation),
        matching: find.byType(Transform),
      );
      expect(floats, findsWidgets);

      // Lepas widget agar controller berulang dihentikan sebelum test selesai.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });
  });

  group('CountUpNumber', () {
    testWidgets('langsung menampilkan nilai akhir saat reduce motion aktif',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const CountUpNumber(value: 42), reduceMotion: true),
      );

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('menampilkan nilai akhir setelah animasi selesai',
        (tester) async {
      await tester.pumpWidget(_wrap(const CountUpNumber(value: 42)));

      // Belum selesai: nilai awal 0 (atau masih berhitung).
      expect(find.text('0'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('42'), findsOneWidget);
    });
  });
}
