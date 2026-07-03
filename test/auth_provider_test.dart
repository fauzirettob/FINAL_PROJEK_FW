import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:absensi_siswa/providers/auth_provider.dart';
import 'package:absensi_siswa/services/firestore_service.dart';
import 'package:absensi_siswa/models/guru.dart';
import 'package:absensi_siswa/models/admin.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseAuth>(),
  MockSpec<FirestoreService>(),
  MockSpec<User>(),
  MockSpec<UserCredential>(),
])
import 'auth_provider_test.mocks.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirestoreService mockFirestore;
  late MockUser mockUser;
  late MockUserCredential mockCredential;

  /// Helper: creates an AuthProvider with a controlled auth stream.
  /// [initialUser] controls what the authStateChanges stream emits.
  AuthProvider createProvider({User? initialUser}) {
    when(mockAuth.authStateChanges())
        .thenAnswer((_) => Stream.value(initialUser));

    final provider = AuthProvider(
      auth: mockAuth,
      firestoreService: mockFirestore,
    );
    return provider;
  }

  setUp(() {
    // Inisialisasi SharedPreferences untuk test environment
    SharedPreferences.setMockInitialValues({});

    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirestoreService();
    mockUser = MockUser();
    mockCredential = MockUserCredential();

    // Default: currentUser = null (setel secara eksplisit untuk konsistensi)
    when(mockAuth.currentUser).thenReturn(null);
  });

  // ─────────────────────────────────────────────────────────────
  // Constructor — Auth State Listener (GURU & ADMIN)
  // ─────────────────────────────────────────────────────────────
  group('Constructor — auth state listener', () {
    test('isAuthenticated dan guru/admin bernilai null saat user null', () async {
      when(mockAuth.currentUser).thenReturn(null);

      final provider = createProvider(initialUser: null);
      await Future(() {});

      expect(provider.isAuthenticated, isFalse);
      expect(provider.guru, isNull);
      expect(provider.admin, isNull);
      expect(provider.role, isNull);
    });

    // ── GURU startup ──

    test('memuat guru dari Firestore ketika user sudah login (startup)', () async {
      when(mockUser.uid).thenReturn('guru-123');
      when(mockAuth.currentUser).thenReturn(mockUser);

      final testGuru = Guru(
        id: 'guru-123',
        nama: 'Bpk. Budi',
        email: 'budi@school.sch.id',
        createdAt: DateTime.now(),
      );
      when(mockFirestore.getGuru('guru-123'))
          .thenAnswer((_) async => testGuru);

      final provider = createProvider(initialUser: mockUser);
      await Future(() {});

      expect(provider.isAuthenticated, isTrue);
      expect(provider.guru, isNotNull);
      expect(provider.guru!.nama, equals('Bpk. Budi'));
      expect(provider.isGuru, isTrue);
      expect(provider.isAdmin, isFalse);
      expect(provider.role, equals('guru'));
    });

    test('guru tetap null jika getGuru mengembalikan null', () async {
      when(mockUser.uid).thenReturn('guru-456');
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockFirestore.getGuru('guru-456'))
          .thenAnswer((_) async => null);

      final provider = createProvider(initialUser: mockUser);
      await Future(() {});

      expect(provider.isAuthenticated, isTrue);
      expect(provider.guru, isNull);
      expect(provider.role, isNull);
    });

    test('guru tetap null jika getGuru melempar error', () async {
      when(mockUser.uid).thenReturn('guru-789');
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockFirestore.getGuru('guru-789'))
          .thenThrow(Exception('Firestore error'));

      final provider = createProvider(initialUser: mockUser);
      await Future(() {});

      expect(provider.isAuthenticated, isTrue);
      expect(provider.guru, isNull);
      expect(provider.role, isNull);
    });

    test(
      'RACE CONDITION: guru sudah terisi ketika notifyListeners dipanggil '
      'setelah auth state change',
      () async {
        when(mockUser.uid).thenReturn('guru-race');
        when(mockAuth.currentUser).thenReturn(mockUser);

        final testGuru = Guru(
          id: 'guru-race',
          nama: 'Race Guru',
          email: 'race@school.sch.id',
          createdAt: DateTime.now(),
        );
        when(mockFirestore.getGuru('guru-race'))
            .thenAnswer((_) async => testGuru);

        Guru? guruSaatNotify;

        final provider = createProvider(initialUser: mockUser);
        provider.addListener(() {
          guruSaatNotify = provider.guru;
        });

        await Future(() {});

        expect(guruSaatNotify, isNotNull);
        expect(guruSaatNotify!.nama, equals('Race Guru'));
        expect(provider.guru, isNotNull);
      },
    );

    // ── ADMIN startup ──

    test('memuat admin dari Firestore ketika user sudah login (startup)', () async {
      when(mockUser.uid).thenReturn('admin-123');
      when(mockAuth.currentUser).thenReturn(mockUser);

      final testAdmin = Admin(
        id: 'admin-123',
        nama: 'Admin Satu',
        email: 'admin@school.sch.id',
        createdAt: DateTime.now(),
      );
      when(mockFirestore.getAdmin('admin-123'))
          .thenAnswer((_) async => testAdmin);

      final provider = createProvider(initialUser: mockUser);
      await Future(() {});

      expect(provider.isAuthenticated, isTrue);
      expect(provider.admin, isNotNull);
      expect(provider.admin!.nama, equals('Admin Satu'));
      expect(provider.isAdmin, isTrue);
      expect(provider.isGuru, isFalse);
      expect(provider.role, equals('admin'));
    });

    test('admin tetap null jika getAdmin mengembalikan null', () async {
      when(mockUser.uid).thenReturn('admin-456');
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockFirestore.getAdmin('admin-456'))
          .thenAnswer((_) async => null);

      final provider = createProvider(initialUser: mockUser);
      await Future(() {});

      expect(provider.isAuthenticated, isTrue);
      expect(provider.admin, isNull);
      expect(provider.role, isNull);
    });

    test('admin tetap null jika getAdmin melempar error', () async {
      when(mockUser.uid).thenReturn('admin-789');
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockFirestore.getAdmin('admin-789'))
          .thenThrow(Exception('Firestore error'));

      final provider = createProvider(initialUser: mockUser);
      await Future(() {});

      expect(provider.isAuthenticated, isTrue);
      expect(provider.admin, isNull);
      expect(provider.role, isNull);
    });

    // ── Early exit: auth state refire tidak reload data ──

    test(
      'EARLY EXIT: auth state refire dengan data guru sudah lengkap — '
      'tidak reload dari Firestore',
      () async {
        when(mockUser.uid).thenReturn('guru-early');
        when(mockAuth.currentUser).thenReturn(mockUser);

        final streamController = StreamController<User?>.broadcast();
        when(mockAuth.authStateChanges())
            .thenAnswer((_) => streamController.stream);

        final testGuru = Guru(
          id: 'guru-early',
          nama: 'Guru Early',
          email: 'early@school.sch.id',
          createdAt: DateTime.now(),
        );
        when(mockFirestore.getGuru('guru-early'))
            .thenAnswer((_) async => testGuru);

        final provider = AuthProvider(
          auth: mockAuth,
          firestoreService: mockFirestore,
        );

        // Kirim user pertama — muat data dari Firestore
        streamController.add(mockUser);
        await Future(() {});
        expect(provider.isAuthenticated, isTrue);
        expect(provider.guru, isNotNull);
        expect(provider.guru!.nama, equals('Guru Early'));

        // Reset mock getGuru agar gagal jika dipanggil lagi
        when(mockFirestore.getGuru('guru-early'))
            .thenThrow(Exception('getGuru tidak boleh dipanggil ulang!'));

        // Kirim auth state refire (user yang sama) — harus skip reload
        streamController.add(mockUser);
        await Future(() {});

        // Data harus tetap intact (tidak di-reload)
        expect(provider.isAuthenticated, isTrue);
        expect(provider.guru, isNotNull);
        expect(provider.guru!.nama, equals('Guru Early'));
        expect(provider.role, equals('guru'));

        await streamController.close();
      },
    );

    test(
      'EARLY EXIT: auth state refire dengan data admin sudah lengkap — '
      'tidak reload dari Firestore',
      () async {
        when(mockUser.uid).thenReturn('admin-early');
        when(mockAuth.currentUser).thenReturn(mockUser);

        final streamController = StreamController<User?>.broadcast();
        when(mockAuth.authStateChanges())
            .thenAnswer((_) => streamController.stream);

        final testAdmin = Admin(
          id: 'admin-early',
          nama: 'Admin Early',
          email: 'early@school.sch.id',
          createdAt: DateTime.now(),
        );
        when(mockFirestore.getAdmin('admin-early'))
            .thenAnswer((_) async => testAdmin);

        final provider = AuthProvider(
          auth: mockAuth,
          firestoreService: mockFirestore,
        );

        // Kirim user pertama — muat data dari Firestore
        streamController.add(mockUser);
        await Future(() {});
        expect(provider.isAuthenticated, isTrue);
        expect(provider.admin, isNotNull);
        expect(provider.admin!.nama, equals('Admin Early'));

        // Reset mock getAdmin agar gagal jika dipanggil lagi
        when(mockFirestore.getAdmin('admin-early'))
            .thenThrow(Exception('getAdmin tidak boleh dipanggil ulang!'));

        // Kirim auth state refire (user yang sama) — harus skip reload
        streamController.add(mockUser);
        await Future(() {});

        // Data harus tetap intact
        expect(provider.isAuthenticated, isTrue);
        expect(provider.admin, isNotNull);
        expect(provider.admin!.nama, equals('Admin Early'));
        expect(provider.role, equals('admin'));

        await streamController.close();
      },
    );

    test(
      'FALLBACK tidak mereset role yang sudah ada ketika query gagal',
      () async {
        when(mockUser.uid).thenReturn('guru-fallback');
        when(mockAuth.currentUser).thenReturn(mockUser);

        final streamController = StreamController<User?>.broadcast();
        when(mockAuth.authStateChanges())
            .thenAnswer((_) => streamController.stream);

        final testGuru = Guru(
          id: 'guru-fallback',
          nama: 'Guru Fallback',
          email: 'fallback@school.sch.id',
          createdAt: DateTime.now(),
        );
        when(mockFirestore.getGuru('guru-fallback'))
            .thenAnswer((_) async => testGuru);

        final provider = AuthProvider(
          auth: mockAuth,
          firestoreService: mockFirestore,
        );

        // Muat guru sukses
        streamController.add(mockUser);
        await Future(() {});
        expect(provider.guru, isNotNull);
        expect(provider.role, equals('guru'));

        // Kirim ulang user, tapi sekarang getGuru gagal
        when(mockFirestore.getGuru('guru-fallback'))
            .thenThrow(Exception('Transient Firestore error'));
        when(mockFirestore.getAdmin('guru-fallback'))
            .thenThrow(Exception('Admin juga gagal'));

        streamController.add(mockUser);
        await Future(() {});

        // Role harus tetap 'guru' (tidak direset ke null)
        expect(provider.role, equals('guru'));
        // Guru mungkin null karena query gagal, tapi role tetap
        // (tergantung implementasi: guru bisa null jika query gagal,
        //  karena _guru di-set ulang di catch/finally)
        // Yang penting role tidak hilang
        expect(provider.role, isNotNull);

        await streamController.close();
      },
    );
  });

  // ─────────────────────────────────────────────────────────────
  // login() — GURU & ADMIN
  // ─────────────────────────────────────────────────────────────
  group('login()', () {
    test('berhasil login dan memuat data guru', () async {
      when(mockUser.uid).thenReturn('guru-login');
      when(mockCredential.user).thenReturn(mockUser);
      when(mockAuth.currentUser).thenReturn(mockUser);

      when(mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockCredential);

      final testGuru = Guru(
        id: 'guru-login',
        nama: 'Login Guru',
        email: 'login@school.sch.id',
        createdAt: DateTime.now(),
      );
      when(mockFirestore.getGuru('guru-login'))
          .thenAnswer((_) async => testGuru);

      when(mockAuth.authStateChanges())
          .thenAnswer((_) => const Stream.empty());

      final provider = AuthProvider(
        auth: mockAuth,
        firestoreService: mockFirestore,
      );

      bool notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.login('test@email.com', 'password123');
      await Future(() {});

      expect(provider.isAuthenticated, isTrue);
      expect(provider.guru, isNotNull);
      expect(provider.guru!.nama, equals('Login Guru'));
      expect(provider.role, equals('guru'));
      expect(provider.isGuru, isTrue);
      expect(provider.isAdmin, isFalse);
      expect(notified, isTrue);
    });

    test('login dengan guru null di Firestore melempar error', () async {
      when(mockUser.uid).thenReturn('guru-null');
      when(mockCredential.user).thenReturn(mockUser);
      when(mockAuth.currentUser).thenReturn(mockUser);

      when(mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockCredential);

      when(mockFirestore.getGuru('guru-null'))
          .thenAnswer((_) async => null);

      when(mockAuth.authStateChanges())
          .thenAnswer((_) => const Stream.empty());

      final provider = AuthProvider(
        auth: mockAuth,
        firestoreService: mockFirestore,
      );

      expect(
        () => provider.login('test@email.com', 'password123'),
        throwsA(isA<Exception>()),
      );
      await Future(() {});

      expect(provider.isAuthenticated, isFalse);
      expect(provider.guru, isNull);
      expect(provider.role, isNull);
    });

    test('login gagal melempar error dari FirebaseAuth', () async {
      when(mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(FirebaseAuthException(code: 'user-not-found'));

      when(mockAuth.authStateChanges())
          .thenAnswer((_) => const Stream.empty());

      final provider = AuthProvider(
        auth: mockAuth,
        firestoreService: mockFirestore,
      );

      expect(
        provider.login('wrong@email.com', 'wrong'),
        throwsA(isA<FirebaseAuthException>()),
      );

      expect(provider.isAuthenticated, isFalse);
      expect(provider.guru, isNull);
      expect(provider.admin, isNull);
      expect(provider.role, isNull);
    });

    // ── ADMIN login ──

    test('berhasil login admin dan memuat data admin', () async {
      when(mockUser.uid).thenReturn('admin-login');
      when(mockCredential.user).thenReturn(mockUser);
      when(mockAuth.currentUser).thenReturn(mockUser);

      when(mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockCredential);

      final testAdmin = Admin(
        id: 'admin-login',
        nama: 'Login Admin',
        email: 'admin@school.sch.id',
        createdAt: DateTime.now(),
      );
      when(mockFirestore.getAdmin('admin-login'))
          .thenAnswer((_) async => testAdmin);

      when(mockAuth.authStateChanges())
          .thenAnswer((_) => const Stream.empty());

      final provider = AuthProvider(
        auth: mockAuth,
        firestoreService: mockFirestore,
      );

      bool notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.login('admin@email.com', 'password123', role: 'admin');
      await Future(() {});

      expect(provider.isAuthenticated, isTrue);
      expect(provider.admin, isNotNull);
      expect(provider.admin!.nama, equals('Login Admin'));
      expect(provider.role, equals('admin'));
      expect(provider.isAdmin, isTrue);
      expect(provider.isGuru, isFalse);
      expect(provider.guru, isNull);
      expect(notified, isTrue);
    });

    test('login admin dengan admin null di Firestore melempar error', () async {
      when(mockUser.uid).thenReturn('admin-null');
      when(mockCredential.user).thenReturn(mockUser);
      when(mockAuth.currentUser).thenReturn(mockUser);

      when(mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockCredential);

      when(mockFirestore.getAdmin('admin-null'))
          .thenAnswer((_) async => null);

      when(mockAuth.authStateChanges())
          .thenAnswer((_) => const Stream.empty());

      final provider = AuthProvider(
        auth: mockAuth,
        firestoreService: mockFirestore,
      );

      expect(
        () => provider.login('admin@email.com', 'password123', role: 'admin'),
        throwsA(isA<Exception>()),
      );
      await Future(() {});

      expect(provider.isAuthenticated, isFalse);
      expect(provider.admin, isNull);
      expect(provider.role, isNull);
    });

    test('login admin gagal dengan Firestore error (sign out + rethrow)', () async {
      when(mockUser.uid).thenReturn('admin-error');
      when(mockCredential.user).thenReturn(mockUser);
      when(mockAuth.currentUser).thenReturn(mockUser);

      when(mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockCredential);

      when(mockFirestore.getAdmin('admin-error'))
          .thenThrow(Exception('Firestore permission denied'));

      when(mockAuth.signOut()).thenAnswer((_) async => {});

      when(mockAuth.authStateChanges())
          .thenAnswer((_) => const Stream.empty());

      final provider = AuthProvider(
        auth: mockAuth,
        firestoreService: mockFirestore,
      );

      expect(
        () => provider.login('admin@email.com', 'password123', role: 'admin'),
        throwsA(isA<Exception>()),
      );
      await Future(() {});

      // State harus di-reset total
      expect(provider.isAuthenticated, isFalse);
      expect(provider.admin, isNull);
      expect(provider.role, isNull);

      // signOut harus dipanggil
      verify(mockAuth.signOut()).called(1);
    });

    test('login guru dengan role=\'guru\' eksplisit sama dengan tanpa role', () async {
      when(mockUser.uid).thenReturn('guru-eksplisit');
      when(mockCredential.user).thenReturn(mockUser);
      when(mockAuth.currentUser).thenReturn(mockUser);

      when(mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockCredential);

      final testGuru = Guru(
        id: 'guru-eksplisit',
        nama: 'Guru Eksplisit',
        email: 'eksplisit@school.sch.id',
        createdAt: DateTime.now(),
      );
      when(mockFirestore.getGuru('guru-eksplisit'))
          .thenAnswer((_) async => testGuru);

      when(mockAuth.authStateChanges())
          .thenAnswer((_) => const Stream.empty());

      final provider = AuthProvider(
        auth: mockAuth,
        firestoreService: mockFirestore,
      );

      await provider.login('guru@email.com', 'pass', role: 'guru');
      await Future(() {});

      expect(provider.isAuthenticated, isTrue);
      expect(provider.guru, isNotNull);
      expect(provider.role, equals('guru'));
      expect(provider.isGuru, isTrue);
      expect(provider.isAdmin, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // register() — GURU & ADMIN
  // ─────────────────────────────────────────────────────────────
  group('register()', () {
    test('berhasil registrasi guru, simpan guru, lalu sign-out', () async {
      when(mockUser.uid).thenReturn('guru-reg');
      when(mockCredential.user).thenReturn(mockUser);

      when(mockAuth.createUserWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockCredential);

      when(mockFirestore.addGuru(any)).thenAnswer((_) async => {});
      when(mockAuth.signOut()).thenAnswer((_) async => {});

      final authStreamController = StreamController<User?>.broadcast();
      when(mockAuth.authStateChanges())
          .thenAnswer((_) => authStreamController.stream);

      final provider = AuthProvider(
        auth: mockAuth,
        firestoreService: mockFirestore,
      );

      bool notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.register(
        'new@school.sch.id', 'password123', 'Guru Baru',
      );
      await Future(() {});

      expect(provider.isAuthenticated, isFalse);
      expect(provider.guru, isNull);

      verify(mockFirestore.addGuru(argThat(
        hasProps({'nama': 'Guru Baru', 'email': 'new@school.sch.id'}),
      ))).called(1);
      verify(mockAuth.signOut()).called(1);
      expect(notified, isTrue);
    });

    test('registrasi guru gagal karena email sudah terdaftar', () async {
      when(mockAuth.createUserWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(
        FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'The email address is already in use by another account.',
        ),
      );

      when(mockAuth.authStateChanges())
          .thenAnswer((_) => const Stream.empty());

      final provider = AuthProvider(
        auth: mockAuth,
        firestoreService: mockFirestore,
      );

      expect(
        provider.register('existing@school.sch.id', 'password123', 'Guru Duplikat'),
        throwsA(isA<FirebaseAuthException>()),
      );
      await Future(() {});

      expect(provider.isAuthenticated, isFalse);
      expect(provider.guru, isNull);

      verifyNever(mockFirestore.addGuru(any));
      verifyNever(mockFirestore.getGuru(any));
      verifyNever(mockAuth.signOut());
    });

    test('addGuru gagal → rollback: auth user dihapus dan error dilempar', () async {
      when(mockUser.uid).thenReturn('guru-rollback');
      when(mockCredential.user).thenReturn(mockUser);

      when(mockAuth.createUserWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockCredential);

      when(mockFirestore.addGuru(any))
          .thenThrow(Exception('Firestore write error'));
      when(mockUser.delete()).thenAnswer((_) async => {});

      when(mockAuth.authStateChanges())
          .thenAnswer((_) => const Stream.empty());

      final provider = AuthProvider(
        auth: mockAuth,
        firestoreService: mockFirestore,
      );

      expect(
        provider.register('rollback@school.sch.id', 'password123', 'Guru Rollback'),
        throwsA(isA<Exception>()),
      );
      await Future(() {});

      verify(mockUser.delete()).called(1);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.guru, isNull);
      verifyNever(mockAuth.signOut());
    });

    // ── ADMIN registration ──

    test('berhasil registrasi admin, simpan admin, lalu sign-out', () async {
      when(mockUser.uid).thenReturn('admin-reg');
      when(mockCredential.user).thenReturn(mockUser);

      when(mockAuth.createUserWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockCredential);

      when(mockFirestore.addAdmin(any)).thenAnswer((_) async => {});
      when(mockAuth.signOut()).thenAnswer((_) async => {});

      final authStreamController = StreamController<User?>.broadcast();
      when(mockAuth.authStateChanges())
          .thenAnswer((_) => authStreamController.stream);

      final provider = AuthProvider(
        auth: mockAuth,
        firestoreService: mockFirestore,
      );

      bool notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.register(
        'admin@school.sch.id', 'password123', 'Admin Baru',
        role: 'admin',
      );
      await Future(() {});

      // Setelah register admin, user di-sign-out
      expect(provider.isAuthenticated, isFalse);
      expect(provider.admin, isNull);

      // Verifikasi admin disimpan ke Firestore
      verify(mockFirestore.addAdmin(argThat(
        hasAdminProps({'nama': 'Admin Baru', 'email': 'admin@school.sch.id'}),
      ))).called(1);

      // signOut dipanggil
      verify(mockAuth.signOut()).called(1);
      expect(notified, isTrue);
    });

    test('registrasi admin gagal karena email sudah terdaftar', () async {
      when(mockAuth.createUserWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(
        FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'The email address is already in use.',
        ),
      );

      when(mockAuth.authStateChanges())
          .thenAnswer((_) => const Stream.empty());

      final provider = AuthProvider(
        auth: mockAuth,
        firestoreService: mockFirestore,
      );

      expect(
        provider.register(
          'existing@school.sch.id', 'password123', 'Admin Duplikat',
          role: 'admin',
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
      await Future(() {});

      expect(provider.isAuthenticated, isFalse);
      expect(provider.admin, isNull);

      // Tidak ada Firestore atau signOut yang dipanggil
      verifyNever(mockFirestore.addAdmin(any));
      verifyNever(mockFirestore.getAdmin(any));
      verifyNever(mockAuth.signOut());
    });

    test('addAdmin gagal → rollback: auth user dihapus dan error dilempar', () async {
      when(mockUser.uid).thenReturn('admin-rollback');
      when(mockCredential.user).thenReturn(mockUser);

      when(mockAuth.createUserWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockCredential);

      when(mockFirestore.addAdmin(any))
          .thenThrow(Exception('Firestore write error'));
      when(mockUser.delete()).thenAnswer((_) async => {});

      when(mockAuth.authStateChanges())
          .thenAnswer((_) => const Stream.empty());

      final provider = AuthProvider(
        auth: mockAuth,
        firestoreService: mockFirestore,
      );

      expect(
        provider.register(
          'rollback@school.sch.id', 'password123', 'Admin Rollback',
          role: 'admin',
        ),
        throwsA(isA<Exception>()),
      );
      await Future(() {});

      verify(mockUser.delete()).called(1);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.admin, isNull);
      verifyNever(mockAuth.signOut());
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Role Switching
  // ─────────────────────────────────────────────────────────────
  group('role switching', () {
    test(
      'auth state listener: start admin, sign out, start guru — '
      'role berganti ke guru',
      () async {
        final streamController = StreamController<User?>.broadcast();
        when(mockAuth.authStateChanges())
            .thenAnswer((_) => streamController.stream);

        when(mockUser.uid).thenReturn('user-123');
        when(mockAuth.currentUser).thenReturn(mockUser);

        final testAdmin = Admin(
          id: 'user-123',
          nama: 'User Admin',
          email: 'user@school.sch.id',
          createdAt: DateTime.now(),
        );
        when(mockFirestore.getAdmin('user-123'))
            .thenAnswer((_) async => testAdmin);

        final provider = AuthProvider(
          auth: mockAuth,
          firestoreService: mockFirestore,
        );

        // Muat sebagai admin
        streamController.add(mockUser);
        await Future(() {});
        expect(provider.isAdmin, isTrue);
        expect(provider.role, equals('admin'));

        // Sign out
        when(mockAuth.currentUser).thenReturn(null);
        streamController.add(null);
        await Future(() {});
        expect(provider.isAuthenticated, isFalse);
        expect(provider.role, isNull);

        // Login sebagai guru (user yang sama, tapi guru doc yang berbeda)
        // Dalam skenario ini user-123 di collection guru
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockFirestore.getAdmin('user-123'))
            .thenAnswer((_) async => null); // Bukan admin lagi
        when(mockFirestore.getGuru('user-123'))
            .thenAnswer((_) async => Guru(
              id: 'user-123',
              nama: 'User Guru',
              email: 'user@school.sch.id',
              createdAt: DateTime.now(),
            ));

        streamController.add(mockUser);
        await Future(() {});
        expect(provider.isGuru, isTrue);
        expect(provider.role, equals('guru'));
        expect(provider.admin, isNull);

        await streamController.close();
      },
    );
  });

  // ─────────────────────────────────────────────────────────────
  // logout()
  // ─────────────────────────────────────────────────────────────
  group('logout()', () {
    test('logout guru menghapus session dan role', () async {
      when(mockUser.uid).thenReturn('guru-logout');
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockFirestore.getGuru('guru-logout'))
          .thenAnswer((_) async => Guru(
                id: 'guru-logout',
                nama: 'Logout Guru',
                email: 'logout@school.sch.id',
                createdAt: DateTime.now(),
              ));

      final streamController = StreamController<User?>.broadcast();
      when(mockAuth.authStateChanges()).thenAnswer((_) => streamController.stream);
      when(mockAuth.signOut()).thenAnswer((_) async {
        streamController.add(null);
      });

      final provider = AuthProvider(
        auth: mockAuth,
        firestoreService: mockFirestore,
      );

      streamController.add(mockUser);
      await Future(() {});
      expect(provider.isAuthenticated, isTrue);
      expect(provider.isGuru, isTrue);

      await provider.logout();
      await Future(() {});

      expect(provider.isAuthenticated, isFalse);
      expect(provider.guru, isNull);
      expect(provider.role, isNull);
    });

    test('logout admin menghapus session dan role', () async {
      when(mockUser.uid).thenReturn('admin-logout');
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockFirestore.getAdmin('admin-logout'))
          .thenAnswer((_) async => Admin(
                id: 'admin-logout',
                nama: 'Logout Admin',
                email: 'logout@school.sch.id',
                createdAt: DateTime.now(),
              ));

      final streamController = StreamController<User?>.broadcast();
      when(mockAuth.authStateChanges()).thenAnswer((_) => streamController.stream);
      when(mockAuth.signOut()).thenAnswer((_) async {
        streamController.add(null);
      });

      final provider = AuthProvider(
        auth: mockAuth,
        firestoreService: mockFirestore,
      );

      streamController.add(mockUser);
      await Future(() {});
      expect(provider.isAuthenticated, isTrue);
      expect(provider.isAdmin, isTrue);

      await provider.logout();
      await Future(() {});

      expect(provider.isAuthenticated, isFalse);
      expect(provider.admin, isNull);
      expect(provider.role, isNull);
    });

    test('logout lalu login ulang — admin termuat dari Firestore', () async {
      final streamController = StreamController<User?>.broadcast();
      when(mockAuth.authStateChanges())
          .thenAnswer((_) => streamController.stream);

      when(mockUser.uid).thenReturn('admin-relogin');
      when(mockAuth.currentUser).thenReturn(mockUser);

      // Login awal sebagai admin
      when(mockFirestore.getAdmin('admin-relogin')).thenAnswer((_) async => Admin(
        id: 'admin-relogin',
        nama: 'Admin Awal',
        email: 'awal@school.sch.id',
        createdAt: DateTime.now(),
      ));

      when(mockAuth.signOut()).thenAnswer((_) async {
        streamController.add(null);
      });

      final provider = AuthProvider(
        auth: mockAuth,
        firestoreService: mockFirestore,
      );

      streamController.add(mockUser);
      await Future(() {});
      expect(provider.isAdmin, isTrue);

      // Logout
      await provider.logout();
      await Future(() {});
      expect(provider.isAuthenticated, isFalse);

      // Login ulang sebagai admin (data baru dari Firestore)
      when(mockFirestore.getAdmin('admin-relogin')).thenAnswer((_) async => Admin(
        id: 'admin-relogin',
        nama: 'Admin Login Ulang',
        email: 'lagi@school.sch.id',
        createdAt: DateTime.now(),
      ));

      streamController.add(mockUser);
      await Future(() {});

      expect(provider.isAuthenticated, isTrue);
      expect(provider.isAdmin, isTrue);
      expect(provider.admin!.nama, equals('Admin Login Ulang'));
      // 2x getAdmin: 1x login awal, 1x login ulang
      verify(mockFirestore.getAdmin('admin-relogin')).called(2);

      await streamController.close();
    });
  });
}

// ─────────────────────────────────────────────────────────────
// Helper matchers
// ─────────────────────────────────────────────────────────────
/// Matcher untuk field Guru
Matcher hasProps(Map<String, dynamic> props) {
  return _HasProps(props);
}

class _HasProps extends Matcher {
  final Map<String, dynamic> props;
  _HasProps(this.props);

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item is! Guru) return false;
    return props.entries.every((e) {
      if (e.key == 'nama') return item.nama == e.value;
      if (e.key == 'email') return item.email == e.value;
      if (e.key == 'id') return item.id == e.value;
      return false;
    });
  }

  @override
  Description describe(Description description) {
    return description.add('Guru with $props');
  }
}

/// Matcher untuk field Admin
Matcher hasAdminProps(Map<String, dynamic> props) {
  return _HasAdminProps(props);
}

class _HasAdminProps extends Matcher {
  final Map<String, dynamic> props;
  _HasAdminProps(this.props);

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item is! Admin) return false;
    return props.entries.every((e) {
      if (e.key == 'nama') return item.nama == e.value;
      if (e.key == 'email') return item.email == e.value;
      if (e.key == 'id') return item.id == e.value;
      return false;
    });
  }

  @override
  Description describe(Description description) {
    return description.add('Admin with $props');
  }
}
