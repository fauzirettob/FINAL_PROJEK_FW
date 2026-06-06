import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:mockito/mockito.dart';

import 'package:absensi_siswa/providers/auth_provider.dart';
import 'package:absensi_siswa/services/firestore_service.dart';
import 'package:absensi_siswa/models/guru.dart';

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
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirestoreService();
    mockUser = MockUser();
    mockCredential = MockUserCredential();
  });

  group('Constructor — auth state listener', () {
    test('isAuthenticated dan guru bernilai null saat user null', () async {
      when(mockAuth.currentUser).thenReturn(null);

      final provider = createProvider(initialUser: null);
      // Tunggu _onAuthStateChanged selesai
      await Future(() {});

      expect(provider.isAuthenticated, isFalse);
      expect(provider.guru, isNull);
    });

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
      // Tunggu _onAuthStateChanged menunggu getGuru selesai
      await Future(() {});

      expect(provider.isAuthenticated, isTrue);
      expect(provider.guru, isNotNull);
      expect(provider.guru!.nama, equals('Bpk. Budi'));
      expect(provider.guru!.id, equals('guru-123'));
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
          // Simpan snapshot guru saat notifyListeners dipanggil
          guruSaatNotify = provider.guru;
        });

        // Tunggu _onAuthStateChanged selesai
        await Future(() {});

        // Verifikasi bahwa saat listener dipanggil, guru sudah terisi
        expect(guruSaatNotify, isNotNull);
        expect(guruSaatNotify!.nama, equals('Race Guru'));
        expect(provider.guru, isNotNull);
      },
    );
  });

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

      // Gunakan Stream.value(null) agar auth listener selesai cepat
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
      expect(notified, isTrue);
    });

    test('login dengan guru null di Firestore', () async {
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

      await provider.login('test@email.com', 'password123');
      await Future(() {});

      expect(provider.isAuthenticated, isTrue);
      expect(provider.guru, isNull);
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
    });
  });

  group('register()', () {
    test('berhasil registrasi, simpan guru, lalu sign-out ke halaman login', () async {
      when(mockUser.uid).thenReturn('guru-reg');
      when(mockCredential.user).thenReturn(mockUser);

      when(mockAuth.createUserWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockCredential);

      when(mockFirestore.addGuru(any)).thenAnswer((_) async => {});

      when(mockAuth.signOut()).thenAnswer((_) async => {});

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

      await provider.register(
        'new@school.sch.id',
        'password123',
        'Guru Baru',
      );
      await Future(() {});

      // Setelah register, user di-sign-out, jadi tidak terautentikasi
      expect(provider.isAuthenticated, isFalse);
      expect(provider.guru, isNull);

      // Verifikasi guru disimpan ke Firestore
      verify(mockFirestore.addGuru(argThat(
        hasProps({
          'nama': 'Guru Baru',
          'email': 'new@school.sch.id',
        }),
      ))).called(1);

      // Verifikasi sign-out dipanggil (user harus login manual)
      verify(mockAuth.signOut()).called(1);

      // Tidak boleh ada notifikasi karena isAuthenticated tidak pernah true
      expect(notified, isFalse);
    });

    test('registrasi gagal karena email sudah terdaftar (email-already-in-use)', () async {
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

      // Register harus melempar error
      expect(
        provider.register(
          'existing@school.sch.id',
          'password123',
          'Guru Duplikat',
        ),
        throwsA(isA<FirebaseAuthException>()),
      );

      await Future(() {});

      // Pastikan state tetap tidak terautentikasi
      expect(provider.isAuthenticated, isFalse);
      expect(provider.guru, isNull);

      // addGuru tidak boleh dipanggil karena registrasi FirebaseAuth gagal
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

      // Simulasi addGuru gagal
      when(mockFirestore.addGuru(any))
          .thenThrow(Exception('Firestore write error'));

      // user.delete() harus berhasil dipanggil saat rollback
      when(mockUser.delete()).thenAnswer((_) async => {});

      when(mockAuth.authStateChanges())
          .thenAnswer((_) => const Stream.empty());

      final provider = AuthProvider(
        auth: mockAuth,
        firestoreService: mockFirestore,
      );

      // Register harus melempar error asli dari addGuru
      expect(
        provider.register(
          'rollback@school.sch.id',
          'password123',
          'Guru Rollback',
        ),
        throwsA(isA<Exception>()),
      );

      await Future(() {});

      // Pastikan auth user dihapus (rollback)
      verify(mockUser.delete()).called(1);

      // Pastikan state tetap tidak terautentikasi
      expect(provider.isAuthenticated, isFalse);
      expect(provider.guru, isNull);

      // signOut tidak boleh dipanggil karena addGuru gagal
      verifyNever(mockAuth.signOut());
    });

    test(
      '_isRegistering mencegah auth listener memproses event '
      'selama register (baik user login maupun sign-out)',
      () async {
        final streamController = StreamController<User?>.broadcast();
        when(mockAuth.authStateChanges())
            .thenAnswer((_) => streamController.stream);

        when(mockUser.uid).thenReturn('guru-reg-safe');
        when(mockCredential.user).thenReturn(mockUser);

        // Simulasi: createUserWithEmailAndPassword memicu auth state change
        when(mockAuth.createUserWithEmailAndPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) async {
          streamController.add(mockUser); // Trigger auth listener (login)
          await Future(() {}); // Biarkan stream event terproses
          return mockCredential;
        });

        when(mockFirestore.addGuru(any)).thenAnswer((_) async => {});

        // Mock signOut — memicu auth state change (sign-out)
        when(mockAuth.signOut()).thenAnswer((_) async {
          streamController.add(null);
        });

        // getGuru TIDAK boleh dipanggil selama register
        when(mockFirestore.getGuru(any)).thenAnswer((_) async {
          throw Exception('getGuru seharusnya tidak dipanggil saat register!');
        });

        final provider = AuthProvider(
          auth: mockAuth,
          firestoreService: mockFirestore,
        );
        await Future(() {});

        await provider.register(
          'new@test.com',
          'pass123',
          'Guru Aman',
        );
        await Future(() {});

        // Setelah register, user di-sign-out, jadi tidak terautentikasi
        expect(provider.isAuthenticated, isFalse);
        expect(provider.guru, isNull);

        // getGuru tidak boleh dipanggil sama sekali
        verifyNever(mockFirestore.getGuru(any));

        // addGuru tetap dipanggil
        verify(mockFirestore.addGuru(any)).called(1);

        // signOut dipanggil
        verify(mockAuth.signOut()).called(1);

        await streamController.close();
      },
    );

    test(
      'auth state change setelah register selesai '
      '— _isRegistering false, user bisa login via stream seperti biasa',
      () async {
        final streamController = StreamController<User?>.broadcast();
        when(mockAuth.authStateChanges())
            .thenAnswer((_) => streamController.stream);

        when(mockUser.uid).thenReturn('guru-post');
        when(mockCredential.user).thenReturn(mockUser);

        when(mockAuth.createUserWithEmailAndPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) async {
          streamController.add(mockUser);
          await Future(() {}); // Biarkan stream event terproses
          return mockCredential;
        });

        when(mockFirestore.addGuru(any)).thenAnswer((_) async => {});

        when(mockAuth.signOut()).thenAnswer((_) async {
          streamController.add(null);
        });

        final provider = AuthProvider(
          auth: mockAuth,
          firestoreService: mockFirestore,
        );
        await Future(() {});

        // Register — user akan di-sign-out otomatis
        await provider.register(
          'post@school.sch.id',
          'password123',
          'Guru Post',
        );
        await Future(() {});

        expect(provider.isAuthenticated, isFalse);
        expect(provider.guru, isNull);

        // Kirim auth state change user login lagi — simulasi login manual
        when(mockFirestore.getGuru('guru-post')).thenAnswer((_) async => Guru(
          id: 'guru-post',
          nama: 'Guru Post',
          email: 'post@school.sch.id',
          createdAt: DateTime.now(),
        ));

        streamController.add(mockUser);
        await Future(() {});

        // Harusnya guru termuat dari Firestore (seperti login biasa)
        expect(provider.isAuthenticated, isTrue);
        expect(provider.guru, isNotNull);
        expect(provider.guru!.nama, equals('Guru Post'));

        // getGuru dipanggil oleh auth listener setelah register selesai
        verify(mockFirestore.getGuru('guru-post')).called(1);

        await streamController.close();
      },
    );
  });

  group('logout()', () {
    test('logout menghapus session dan mengosongkan guru', () async {
      // Setup: user sudah login dengan guru
      when(mockUser.uid).thenReturn('guru-logout');
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockFirestore.getGuru('guru-logout'))
          .thenAnswer((_) async => Guru(
                id: 'guru-logout',
                nama: 'Logout Guru',
                email: 'logout@school.sch.id',
                createdAt: DateTime.now(),
              ));

      // Auth stream: kirim user dulu, lalu null setelah logout
      final streamController = StreamController<User?>.broadcast();
      when(mockAuth.authStateChanges()).thenAnswer((_) => streamController.stream);
      when(mockAuth.signOut()).thenAnswer((_) async {
        streamController.add(null); // Emit null saat logout
      });

      final provider = AuthProvider(
        auth: mockAuth,
        firestoreService: mockFirestore,
      );

      // Tunggu inisialisasi
      streamController.add(mockUser);
      await Future(() {});
      expect(provider.isAuthenticated, isTrue);
      expect(provider.guru, isNotNull);

      // Logout
      await provider.logout();
      await Future(() {});

      expect(provider.isAuthenticated, isFalse);
      expect(provider.guru, isNull);
    });

    test('logout lalu login ulang — guru termuat dari Firestore', () async {
      // Setup: user sudah login
      final streamController = StreamController<User?>.broadcast();
      when(mockAuth.authStateChanges())
          .thenAnswer((_) => streamController.stream);

      when(mockUser.uid).thenReturn('guru-relogin');

      // Siapkan login awal
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockFirestore.getGuru('guru-relogin')).thenAnswer((_) async => Guru(
        id: 'guru-relogin',
        nama: 'Guru Awal',
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

      // Login awal via auth stream
      streamController.add(mockUser);
      await Future(() {});
      expect(provider.isAuthenticated, isTrue);
      expect(provider.guru, isNotNull);

      // Logout
      await provider.logout();
      await Future(() {});
      expect(provider.isAuthenticated, isFalse);
      expect(provider.guru, isNull);

      // Siapkan data guru baru untuk login ulang
      when(mockFirestore.getGuru('guru-relogin')).thenAnswer((_) async => Guru(
        id: 'guru-relogin',
        nama: 'Guru Login Ulang',
        email: 'lagi@school.sch.id',
        createdAt: DateTime.now(),
      ));

      // Login ulang via auth stream
      streamController.add(mockUser);
      await Future(() {});

      // Guru harus termuat dari Firestore
      expect(provider.isAuthenticated, isTrue);
      expect(provider.guru, isNotNull);
      expect(provider.guru!.nama, equals('Guru Login Ulang'));

      // getGuru dipanggil untuk login ulang
      verify(mockFirestore.getGuru('guru-relogin')).called(2); // 1x login awal, 1x login ulang

      await streamController.close();
    });
  });
}

/// Helper matcher untuk memeriksa field Guru tanpa harus menyamakan ID
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
