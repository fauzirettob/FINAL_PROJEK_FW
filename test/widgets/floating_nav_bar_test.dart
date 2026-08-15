import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:absensi_siswa/widgets/floating_nav_bar.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: const SizedBox(),
      bottomNavigationBar: child,
    ),
  );
}

const _items = [
  FloatingNavItem(
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    label: 'Beranda',
  ),
  FloatingNavItem(
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    label: 'Profil',
  ),
];

void main() {
  group('FloatingNavBar', () {
    testWidgets('menampilkan semua label item', (tester) async {
      await tester.pumpWidget(_wrap(FloatingNavBar(
        items: _items,
        currentIndex: 0,
        onTap: (_) {},
      )));

      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
    });

    testWidgets('item aktif menampilkan ikon aktif (filled)', (tester) async {
      await tester.pumpWidget(_wrap(FloatingNavBar(
        items: _items,
        currentIndex: 0,
        onTap: (_) {},
      )));

      // Beranda aktif → ikon "home" (filled), Profil → "person_outline".
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsNothing);
    });

    testWidgets('ketukan memanggil onTap dengan indeks yang benar',
        (tester) async {
      var tappedIndex = -1;
      await tester.pumpWidget(_wrap(FloatingNavBar(
        items: _items,
        currentIndex: 0,
        onTap: (i) => tappedIndex = i,
      )));

      await tester.tap(find.text('Profil'));
      await tester.pump();

      expect(tappedIndex, 1);
    });

    testWidgets('hover memperbesar item (efek menggelembung)', (tester) async {
      await tester.pumpWidget(_wrap(FloatingNavBar(
        items: _items,
        currentIndex: 0,
        onTap: (_) {},
      )));

      double scaleOf(String label) {
        final scale = tester.widget<AnimatedScale>(find
            .ancestor(of: find.text(label), matching: find.byType(AnimatedScale))
            .first);
        return scale.scale;
      }

      // Sebelum hover: skala normal.
      expect(scaleOf('Beranda'), 1.0);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(tester.getCenter(find.text('Beranda')));
      await tester.pumpAndSettle();

      // Setelah hover: skala membesar (menggelembung).
      expect(scaleOf('Beranda'), greaterThan(1.0));
      expect(scaleOf('Profil'), 1.0);
    });

    testWidgets('tidak overflow di layar sempit (360px)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(FloatingNavBar(
        items: _items,
        currentIndex: 0,
        onTap: (_) {},
      )));

      // Tidak ada RenderFlex overflow.
      expect(tester.takeException(), isNull);
      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
    });
  });
}
