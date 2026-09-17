import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import '../models/guru.dart';
import '../models/admin.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth;
  final FirestoreService _firestoreService;
  User? _user;
  Guru? _guru;
  Admin? _admin;
  String? _role;
  bool _isRegistering = false;
  bool _isLoggingIn = false;
  bool _isReLoggingIn = false; // guard untuk re-login otomatis setelah tambah guru

  // Kredensial admin disimpan di memory DAN SharedPreferences
  // Digunakan untuk re-login otomatis setelah menambah guru baru
  String? _adminEmail;
  String? _adminPassword;

  User? get user => _user;
  Guru? get guru => _guru;
  Admin? get admin => _admin;
  String? get role => _role;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _role == 'admin';
  bool get isGuru => _role == 'guru';
  bool get isWaliKelas => _role == 'guru' && (_guru?.isWaliKelas ?? false);

  AuthProvider({
    FirebaseAuth? auth,
    FirestoreService? firestoreService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestoreService = firestoreService ?? FirestoreService() {
    _auth.authStateChanges().listen((User? user) {
      _onAuthStateChanged(user);
    });
  }

  Future<void> _onAuthStateChanged(User? user) async {
    // Jangan ganggu proses login, register, atau re-login yang sedang berlangsung.
    if (_isRegistering || _isLoggingIn || _isReLoggingIn) return;

    // Restore kredensial admin dari SharedPreferences jika belum ada di memory
    if (_adminEmail == null || _adminPassword == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _adminEmail = prefs.getString('admin_email');
        _adminPassword = prefs.getString('admin_password');
        if (_adminEmail != null) {
          debugPrint('✅ Kredensial admin di-restore dari SharedPreferences');
        }
      } catch (e) {
        debugPrint('Gagal restore kredensial admin: $e');
      }
    }

    if (user == null) {
      _user = null;
      _guru = null;
      _admin = null;
      _role = null;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_role');
      } catch (e) {
        debugPrint('Gagal hapus role dari SharedPreferences: $e');
      }
      notifyListeners();
      return;
    }

    // Jika data profil sudah lengkap untuk user yang sama, skip reload Firestore.
    // Ini mencegah auth listener menimpa data yang baru di-set oleh login().
    if (_user != null && _user!.uid == user.uid && _role != null) {
      if ((_role == 'admin' && _admin != null) ||
          (_role == 'guru' && _guru != null)) {
        // Hanya update referensi user (token), tanpa reload data
        _user = user;
        notifyListeners();
        return;
      }
    }

    _user = user;

    // Coba load role dari SharedPreferences dulu
    String? savedRole;
    try {
      final prefs = await SharedPreferences.getInstance();
      savedRole = prefs.getString('user_role');
    } catch (e) {
      debugPrint('Gagal akses SharedPreferences (savedRole): $e');
    }

    if (savedRole == 'admin') {
      try {
        _admin = await _firestoreService.getAdmin(user.uid);
        if (_admin != null) {
          _role = 'admin';
          _guru = null;
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint('Error loading admin: $e');
      }
    } else if (savedRole == 'guru') {
      try {
        _guru = await _firestoreService.getGuru(user.uid);
        if (_guru != null) {
          _role = 'guru';
          _admin = null;
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint('Error loading guru: $e');
      }
    }

    // Fallback: coba admin dulu
    try {
      _admin = await _firestoreService.getAdmin(user.uid);
      if (_admin != null) {
        _role = 'admin';
        _guru = null;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_role', 'admin');
        } catch (e) {
          debugPrint('Gagal simpan role admin ke SharedPreferences: $e');
        }
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Error loading admin (fallback): $e');
    }

    // Fallback: coba guru
    try {
      _guru = await _firestoreService.getGuru(user.uid);
      if (_guru != null) {
        _role = 'guru';
        _admin = null;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_role', 'guru');
        } catch (e) {
          debugPrint('Gagal simpan role guru ke SharedPreferences: $e');
        }
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Error loading guru (fallback): $e');
    }

    // ═══ SELF-REPAIR: profil tidak ditemukan di kedua collection ═══
    // Buat profil guru sebagai default (guru tidak dibatasi seperti admin).
    debugPrint('🔧 Self-repair (_onAuthStateChanged): profil tidak ditemukan untuk ${user.uid}, membuat profil guru...');
    try {
      final newGuru = Guru(
        id: user.uid,
        nama: _getDisplayName(),
        email: user.email ?? '',
        createdAt: DateTime.now(),
      );
      await _firestoreService.addGuru(newGuru);
      _guru = newGuru;
      _role = 'guru';
      _admin = null;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_role', 'guru');
      } catch (_) {}
      debugPrint('✅ Self-repair: profil guru berhasil dibuat untuk ${user.uid}');
    } catch (repairError) {
      debugPrint('❌ Self-repair (_onAuthStateChanged) gagal: $repairError');
      if (_role == null) {
        _admin = null;
        _guru = null;
      }
    }
    notifyListeners();
  }

  /// Ambil nama tampilan dari Firebase Auth user untuk self-repair.
  String _getDisplayName() {
    final displayName = _auth.currentUser?.displayName;
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final email = _auth.currentUser?.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'User';
  }

  /// Simpan role ke SharedPreferences.
  Future<void> _saveRole(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', role);
    } catch (e) {
      debugPrint('Gagal simpan role ke SharedPreferences: $e');
    }
  }

  Future<void> login(String email, String password, {String? role}) async {
    if (_isLoggingIn) return; // Cegah double-click
    _isLoggingIn = true;
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        _user = _auth.currentUser;

        if (role == 'admin') {
          try {
            _admin = await _firestoreService.getAdmin(uid);
          } catch (e) {
            _user = null;
            _admin = null;
            _role = null;
            rethrow;
          }
          if (_admin != null) {
            _role = 'admin';
            _guru = null;
            await _saveRole('admin');
          } else {
            // ═══ SELF-REPAIR ═══
            // Dokumen admin tidak ditemukan. Cek collection guru sebagai
            // fallback — mungkin user memilih role yang salah.
            debugPrint('🔧 Self-repair: admin doc tidak ditemukan untuk $uid, cek collection guru...');
            try {
              _guru = await _firestoreService.getGuru(uid);
            } catch (_) {
              _guru = null;
            }

            if (_guru != null) {
              // Ditemukan di collection guru — role yang dipilih salah.
              // Auto-login sebagai guru.
              debugPrint('🔧 Self-repair: ditemukan sebagai GURU. Auto-login sebagai guru.');
              _role = 'guru';
              _admin = null;
              await _saveRole('guru');
            } else {
              // Tidak ditemukan di kedua collection — buat profil admin baru.
              debugPrint('🔧 Self-repair: tidak ada profil. Membuat profil admin baru untuk $uid...');
              try {
                final newAdmin = Admin(
                  id: uid,
                  nama: _getDisplayName(),
                  email: email,
                  createdAt: DateTime.now(),
                );
                await _firestoreService.addAdmin(newAdmin);
                _admin = newAdmin;
                _role = 'admin';
                _guru = null;
                await _saveRole('admin');
                debugPrint('✅ Self-repair: profil admin berhasil dibuat untuk $uid');
              } catch (repairError) {
                debugPrint('❌ Self-repair gagal membuat profil admin: $repairError');
                _user = null;
                _admin = null;
                _role = null;
                await _auth.signOut();
                rethrow;
              }
            }
          }

          // Simpan kredensial admin di memory DAN SharedPreferences
          _adminEmail = email;
          _adminPassword = password;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('admin_email', email);
            await prefs.setString('admin_password', password);
          } catch (e) {
            debugPrint('Gagal simpan kredensial admin ke SharedPreferences: $e');
          }
          debugPrint('✅ Kredensial admin disimpan untuk re-login');
        } else {
          try {
            _guru = await _firestoreService.getGuru(uid);
          } catch (e) {
            _user = null;
            _guru = null;
            _role = null;
            rethrow;
          }
          if (_guru != null) {
            _role = 'guru';
            _admin = null;
            await _saveRole('guru');
          } else {
            // ═══ SELF-REPAIR ═══
            // Dokumen guru tidak ditemukan. Cek collection admin sebagai
            // fallback — mungkin user memilih role yang salah.
            debugPrint('🔧 Self-repair: guru doc tidak ditemukan untuk $uid, cek collection admin...');
            try {
              _admin = await _firestoreService.getAdmin(uid);
            } catch (_) {
              _admin = null;
            }

            if (_admin != null) {
              // Ditemukan di collection admin — role yang dipilih salah.
              // Auto-login sebagai admin.
              debugPrint('🔧 Self-repair: ditemukan sebagai ADMIN. Auto-login sebagai admin.');
              _role = 'admin';
              _guru = null;
              await _saveRole('admin');

              // Simpan kredensial admin untuk re-login
              _adminEmail = email;
              _adminPassword = password;
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('admin_email', email);
                await prefs.setString('admin_password', password);
              } catch (_) {}
            } else {
              // Tidak ditemukan di kedua collection — buat profil guru baru.
              debugPrint('🔧 Self-repair: tidak ada profil. Membuat profil guru baru untuk $uid...');
              try {
                final newGuru = Guru(
                  id: uid,
                  nama: _getDisplayName(),
                  email: email,
                  createdAt: DateTime.now(),
                );
                await _firestoreService.addGuru(newGuru);
                _guru = newGuru;
                _role = 'guru';
                _admin = null;
                await _saveRole('guru');
                debugPrint('✅ Self-repair: profil guru berhasil dibuat untuk $uid');
              } catch (repairError) {
                debugPrint('❌ Self-repair gagal membuat profil guru: $repairError');
                _user = null;
                _guru = null;
                _role = null;
                await _auth.signOut();
                rethrow;
              }
            }
          }
        }

        notifyListeners();
      }
    } catch (e) {
      // Hapus kredensial admin jika login gagal
      _adminEmail = null;
      _adminPassword = null;
      _user = null;
      _guru = null;
      _admin = null;
      _role = null;
      try {
        await _auth.signOut();
      } catch (_) {}
      notifyListeners();
      rethrow;
    } finally {
      _isLoggingIn = false;
    }
  }

  /// Membuat akun guru baru tanpa mengganggu session admin.
  ///
  /// Strategi:
  /// 1. Gunakan kredensial admin yang sudah tersimpan di memory
  /// 2. Buat akun guru via [register] (sign-out admin otomatis)
  /// 3. Re-login sebagai admin menggunakan kredensial yang disimpan
  ///
  /// Mengembalikan `true` jika berhasil, `false` jika gagal.
  Future<bool> registerGuruByAdmin(
      String email, String password, String nama, {String nip = '', List<String> mapelList = const [], List<String> kelasList = const [], String? waliKelas}) async {
    // Coba restore dari SharedPreferences jika null
    if (_adminEmail == null || _adminPassword == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _adminEmail = prefs.getString('admin_email');
        _adminPassword = prefs.getString('admin_password');
      } catch (e) {
        debugPrint('Gagal restore kredensial admin: $e');
      }
    }

    if (_adminEmail == null || _adminPassword == null) {
      debugPrint('❌ registerGuruByAdmin: kredensial admin tidak tersedia');
      return false;
    }

    final savedAdminEmail = _adminEmail!;
    final savedAdminPassword = _adminPassword!;

    // Guard auth listener agar tidak reset state selama proses re-login.
    // Gunakan flag terpisah (_isReLoggingIn) agar tidak bertabrakan dengan
    // guard double-click di dalam login() yang menggunakan _isLoggingIn.
    _isReLoggingIn = true;

    try {
      // 1. Buat akun guru (sign-out admin otomatis terjadi di dalam register)
      await register(email, password, nama,
          role: 'guru', keepAdminSession: true, nip: nip, mapelList: mapelList, kelasList: kelasList, waliKelas: waliKelas);

      // 2. Re-login sebagai admin
      await login(savedAdminEmail, savedAdminPassword, role: 'admin');

      debugPrint('✅ Guru berhasil ditambahkan, admin kembali login');
      return true;
    } catch (e) {
      debugPrint('❌ registerGuruByAdmin error: $e');
      // Coba re-login admin agar session Firebase Auth tetap aktif,
      // meskipun registrasi guru gagal (misal error Firestore).
      try {
        await login(savedAdminEmail, savedAdminPassword, role: 'admin');
        debugPrint('✅ registerGuruByAdmin: admin session restored after error');
      } catch (_) {
        debugPrint('❌ registerGuruByAdmin: gagal restore admin session after error');
      }
      rethrow; // biarkan caller (TambahGuruScreen) yang handle error spesifik
    } finally {
      _isReLoggingIn = false;
    }
  }

  Future<void> register(String email, String password, String nama,
      {String role = 'guru', bool keepAdminSession = false, String nip = '', List<String> mapelList = const [], List<String> kelasList = const [], String? waliKelas}) async {
    _isRegistering = true;
    UserCredential? credential;

    try {
      // 1. Buat user di Firebase Auth
      credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw Exception('Gagal membuat akun: user tidak ditemukan');
      }

      final uid = credential.user!.uid;
      debugPrint('✅ Auth user created: $uid ($email)');

      // 2. Simpan data ke Firestore
      try {
        if (role == 'admin') {
          final admin = Admin(
            id: uid,
            nama: nama,
            email: email,
            createdAt: DateTime.now(),
          );
          debugPrint('📤 Menyimpan admin ke Firestore: $uid');
          await _firestoreService.addAdmin(admin);
          debugPrint('✅ Admin berhasil disimpan ke Firestore');
        } else {
          final guru = Guru(
            id: uid,
            nip: nip,
            nama: nama,
            email: email,
            mapelList: mapelList,
            kelasList: kelasList,
            waliKelas: waliKelas,
            createdAt: DateTime.now(),
          );
          debugPrint('📤 Menyimpan guru ke Firestore: $uid');
          await _firestoreService.addGuru(guru);
          debugPrint('✅ Guru berhasil disimpan ke Firestore');
        }
      } catch (firestoreError) {
        // Rollback: hapus auth user jika Firestore gagal
        debugPrint('❌ Firestore error: $firestoreError');
        try {
          await credential.user!.delete();
          debugPrint('✅ Rollback: auth user dihapus');
        } catch (deleteError) {
          debugPrint('❌ Gagal rollback auth user: $deleteError');
        }
        rethrow;
      }

      // 3. Sign out agar user tidak auto-login
      await _auth.signOut();
      debugPrint('✅ Registrasi selesai, user di-sign-out');

    } on FirebaseAuthException catch (e) {
      // Error dari Firebase Auth (email terdaftar, password lemah, dll)
      debugPrint('❌ FirebaseAuthException: code=${e.code}, message=${e.message}');
      rethrow;

    } on FirebaseException catch (e) {
      // Error dari Firestore (rules, jaringan, dll)
      debugPrint('❌ FirebaseException: code=${e.code}, message=${e.message}');
      debugPrint('   collection=admin, operation=set, role=$role');
      rethrow;

    } finally {
      _isRegistering = false;
      if (!keepAdminSession) {
        _user = null;
        _guru = null;
        _admin = null;
        _role = null;
        notifyListeners();
      }
    }
  }

  /// Update data guru setelah perubahan profil (misal foto profil)
  void updateGuru(Guru updated) {
    _guru = updated;
    notifyListeners();
  }

  /// Update data admin setelah perubahan profil (misal foto profil)
  void updateAdmin(Admin updated) {
    _admin = updated;
    notifyListeners();
  }

  Future<void> logout() async {
    // Hapus kredensial admin dari memory DAN SharedPreferences
    _adminEmail = null;
    _adminPassword = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_role');
      await prefs.remove('admin_email');
      await prefs.remove('admin_password');
    } catch (e) {
      debugPrint('Gagal hapus data saat logout: $e');
    }
    await _auth.signOut();
  }
}
