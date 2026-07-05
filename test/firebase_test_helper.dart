import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';

/// Inisialisasi Firebase mock untuk test environment.
///
/// Menggunakan [setupFirebaseCoreMocks] dari firebase_core_platform_interface
/// untuk memasang mock MethodChannel internal, lalu memastikan
/// [Firebase.initializeApp] sudah dipanggil.
///
/// Ini diperlukan agar widget yang membuat [FirestoreService] secara
/// langsung (seperti LoginScreen) tidak melempar
/// FirebaseException: [core/no-app] saat di-render dalam test.
Future<void> setupFirebaseMocks() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Pasang mock platform channel untuk firebase_core
  setupFirebaseCoreMocks();

  // Initialize Firebase — aman dipanggil berulang karena catch
  // akan menangani [core/duplicate-app] jika sudah ada.
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: 'test:app:id',
        messagingSenderId: 'test-sender',
        projectId: 'test-project',
      ),
    );
  } on FirebaseException catch (e) {
    // Abaikan jika Firebase sudah di-initialize
    if (e.code != 'duplicate-app') rethrow;
  }
}
