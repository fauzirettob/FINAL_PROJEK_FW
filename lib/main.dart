import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'services/notification_scheduler.dart';
import 'theme/app_theme.dart';
import 'screens/auth/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // App Check dinonaktifkan karena enforcement sudah dimatikan di Firebase Console.
  // Untuk production, aktifkan kembali dengan:
  //   await FirebaseAppCheck.instance.activate(
  //     providerAndroid: const AndroidPlayIntegrityProvider(),
  //   );

  await NotificationScheduler.initialize();

  // Inisialisasi locale untuk DateFormat (Indonesia)
  await initializeDateFormatting('id', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.authProvider});

  final AuthProvider? authProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => authProvider ?? AuthProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'Absensi Siswa',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
