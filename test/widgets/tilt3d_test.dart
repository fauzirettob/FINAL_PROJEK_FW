import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:absensi_siswa/widgets/tilt3d.dart';

Widget _wrap(Widget child, {bool reduceMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: Center(child: child),
      ),
    ),
  );
}

void main() {
  group('Tilt3D', () {
    testWidgets('menampilkan konten anak', (tester) async {
      await tester.pumpWidget(_wrap(const Tilt3D(
        child: Text('kartu'),
      )));

      expect(find.text('kartu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hover memiringkan kartu dalam ruang 3D (animasi aktif)',
        (tester) async {
      await tester.pumpWidget(_wrap(const Tilt3D(
        child: SizedBox(width: 200, height: 100),
      )));

      // Transform di dalam Tilt3D adalah penanda animasi tilt 3D.
      final tiltTransforms = find.descendant(
        of: find.byType(Tilt3D),
        matching: find.byType(Transform),
      );
      expect(tiltTransforms, findsWidgets);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      // Pindahkan kursor ke pojok kanan-atas kartu → memicu onHover.
      await gesture.moveTo(const Offset(170, 40));
      await tester.pump(const Duration(milliseconds: 350));

      expect(tester.takeException(), isNull);

      // Kursor keluar → kartu kembali datar tanpa error.
      await gesture.moveTo(const Offset(10, 300));
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduce motion: konten tampil datar tanpa animasi 3D',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const Tilt3D(child: Text('kartu')),
        reduceMotion: true,
      ));

      expect(find.text('kartu'), findsOneWidget);
      // Tanpa animasi 3D: tidak ada Transform dari Tilt3D di dalam pohon.
      final tiltTransforms = find.descendant(
        of: find.byType(Tilt3D),
        matching: find.byType(Transform),
      );
      expect(tiltTransforms, findsNothing);
    });
  });
}
