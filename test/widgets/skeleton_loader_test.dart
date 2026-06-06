import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:absensi_siswa/widgets/skeleton_loader.dart';

void main() {
  group('SkeletonLoader', () {
    testWidgets('merender child widget dengan benar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonLoader(
              child: Text('Loading content...'),
            ),
          ),
        ),
      );

      // Text child harus muncul
      expect(find.text('Loading content...'), findsOneWidget);
    });

    testWidgets('tidak crash saat dipompa (shimmer animation running)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonLoader(
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      // Pump beberapa frame untuk animasi shimmer
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Widget masih bertahan
      expect(find.byType(SkeletonLoader), findsOneWidget);
    });
  });

  group('SkeletonRect', () {
    testWidgets('merender dengan ukuran yang ditentukan', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonRect(width: 200, height: 50, borderRadius: 12),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.borderRadius, equals(BorderRadius.circular(12)));
    });

    testWidgets('merender dengan nilai default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonRect(height: 100),
          ),
        ),
      );

      expect(find.byType(SkeletonRect), findsOneWidget);
    });
  });

  group('SkeletonCircle', () {
    testWidgets('merender lingkaran dengan ukuran yang ditentukan',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonCircle(size: 64),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.shape, equals(BoxShape.circle));
    });
  });

  group('Screen-specific Skeletons', () {
    testWidgets('RegisterSkeleton merender tanpa error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RegisterSkeleton()),
        ),
      );

      expect(find.byType(RegisterSkeleton), findsOneWidget);
    });

    testWidgets('HomeSkeleton merender tanpa error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: HomeSkeleton()),
        ),
      );

      expect(find.byType(HomeSkeleton), findsOneWidget);
    });

    testWidgets('StudentsSkeleton merender tanpa error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StudentsSkeleton()),
        ),
      );

      expect(find.byType(StudentsSkeleton), findsOneWidget);
    });

    testWidgets('ReportsSkeleton merender tanpa error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ReportsSkeleton()),
        ),
      );

      expect(find.byType(ReportsSkeleton), findsOneWidget);
    });

    testWidgets('ProfileSkeleton merender tanpa error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ProfileSkeleton()),
        ),
      );

      expect(find.byType(ProfileSkeleton), findsOneWidget);
    });

    testWidgets('HistorySkeleton merender tanpa error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: HistorySkeleton()),
        ),
      );

      expect(find.byType(HistorySkeleton), findsOneWidget);
    });

    testWidgets('StudentDetailSkeleton merender tanpa error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StudentDetailSkeleton()),
        ),
      );

      expect(find.byType(StudentDetailSkeleton), findsOneWidget);
    });

    testWidgets('ScanSkeleton merender tanpa error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ScanSkeleton()),
        ),
      );

      expect(find.byType(ScanSkeleton), findsOneWidget);
    });
  });
}
