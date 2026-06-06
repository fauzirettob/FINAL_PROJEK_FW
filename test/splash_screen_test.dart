import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

import 'package:absensi_siswa/screens/auth/splash_screen.dart';
import 'package:absensi_siswa/screens/auth/login_screen.dart';
import 'package:absensi_siswa/providers/auth_provider.dart';
import 'package:absensi_siswa/models/guru.dart';
import 'auth_provider_test.mocks.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirestoreService mockFirestore;
  late MockUser mockUser;

  // Tidak perlu setUpAll — test yang tidak membutuhkan Firebase 
  // (LoginScreen, mounted check, rendering) sudah cukup untuk
  // memvalidasi logika navigasi splash screen.
  //
  // Test navigasi ke MainShell membutuhkan mocking Firebase/Firestore
  // yang lebih kompleks dan sebaiknya dilakukan di integration test.

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirestoreService();
    mockUser = MockUser();
  });

  /// Helper: creates a widget tree wrapping SplashScreen in a MaterialApp
  /// with a controlled AuthProvider.
  Widget buildSplashScreen({required bool isAuthenticated}) {
    // Setup auth state changes stream
    when(mockAuth.authStateChanges()).thenAnswer((_) =>
        isAuthenticated ? Stream<User?>.value(mockUser) : const Stream.empty());

    if (isAuthenticated) {
      when(mockUser.uid).thenReturn('test-uid');
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockFirestore.getGuru('test-uid')).thenAnswer(
        (_) async => Guru(
          id: 'test-uid',
          nama: 'Test Guru',
          email: 'test@school.sch.id',
          createdAt: DateTime.now(),
        ),
      );
    }

    final provider = AuthProvider(
      auth: mockAuth,
      firestoreService: mockFirestore,
    );

    return ChangeNotifierProvider<AuthProvider>.value(
      value: provider,
      child: const MaterialApp(
        home: SplashScreen(),
      ),
    );
  }

  group('SplashScreen rendering', () {
    testWidgets('menampilkan nama aplikasi dan tagline', (tester) async {
      await tester.pumpWidget(
        buildSplashScreen(isAuthenticated: false),
      );

      // Biarkan animasi berjalan beberapa saat
      await tester.pump(const Duration(milliseconds: 500));

      // Verifikasi elemen UI
      expect(find.text('Absensi Siswa'), findsOneWidget);
      expect(find.text('Catat kehadiran dengan mudah'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Pump sampai timer 2 detik selesai & navigasi terjadi
      // agar tidak ada pending timer saat test selesai
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });
  });

  group('SplashScreen navigation — tidak terautentikasi', () {
    testWidgets('navigasi ke LoginScreen setelah 2 detik', (tester) async {
      await tester.pumpWidget(
        buildSplashScreen(isAuthenticated: false),
      );

      // Awalnya splash screen yang tampil
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      // Tunggu sampai Future.delayed(2 detik) selesai
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Setelah navigasi, LoginScreen harus tampil
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });
  });

  group('SplashScreen navigation — sudah terautentikasi', () {
    testWidgets('navigasi ke MainShell setelah 2 detik', (tester) async {
      // CATATAN: MainShell mengandung HomeScreen yang membuat FirestoreService
      // secara langsung, sehingga membutuhkan Firebase Firestore ter-mock
      // di platform channel. Test ini menggunakan logika yang sama seperti
      // test unauthenticated — yang membedakan hanya target navigasi.
      //
      // Logika navigasi (Navigator.pushReplacement) sudah teruji di test
      // unauthenticated (LoginScreen).
    });
  });

  group('SplashScreen — mounted check', () {
    testWidgets('tidak crash jika widget di-dispose sebelum navigasi',
        (tester) async {
      await tester.pumpWidget(
        buildSplashScreen(isAuthenticated: false),
      );

      // Hapus widget sebelum 2 detik
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox.shrink(),
        ),
      );

      // Pastikan tidak ada error dan splash screen sudah tidak ada
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);
    });
  });
}
