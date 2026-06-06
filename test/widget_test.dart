import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:absensi_siswa/main.dart';
import 'package:absensi_siswa/providers/auth_provider.dart';
import 'auth_provider_test.mocks.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    final mockAuth = MockFirebaseAuth();
    final mockFirestore = MockFirestoreService();

    // Pastikan authStateChanges tidak mengirim event apa pun
    when(mockAuth.authStateChanges()).thenAnswer((_) => const Stream.empty());

    final provider = AuthProvider(
      auth: mockAuth,
      firestoreService: mockFirestore,
    );

    // Gunakan parameter authProvider agar MyApp tidak membuat AuthProvider
    // sendiri (yang membutuhkan Firebase.initializeApp)
    await tester.pumpWidget(
      MyApp(authProvider: provider),
    );

    // Tunggu hingga animasi splash selesai agar tidak ada pending timer
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify that the app loads
    expect(find.byType(MyApp), findsOneWidget);
  });
}
