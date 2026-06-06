import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/guru.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth;
  final FirestoreService _firestoreService;
  User? _user;
  Guru? _guru;
  bool _isRegistering = false;
  bool _isLoggingIn = false;

  User? get user => _user;
  Guru? get guru => _guru;
  bool get isAuthenticated => _user != null;

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
    // Jangan ganggu proses login atau register yang sedang berlangsung.
    if (_isRegistering || _isLoggingIn) return;

    // Jika guru sudah terload untuk user yang sama, jangan reload dari Firestore.
    if (user != null && _guru != null && _guru!.id == user.uid) {
      _user = user;
      notifyListeners();
      return;
    }

    _user = user;
    if (user != null) {
      try {
        _guru = await _firestoreService.getGuru(user.uid);
      } catch (e) {
        debugPrint('Error loading guru: $e');
        _guru = null;
      }
    } else {
      _guru = null;
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _isLoggingIn = true;
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      // _onAuthStateChanged tidak akan mengganggu karena _isLoggingIn = true.
      // Pastikan guru sudah ter-load sebelum login() selesai.
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        _user = _auth.currentUser;
        _guru = await _firestoreService.getGuru(uid);
        notifyListeners();
      }
    } catch (e) {
      // Reset state jika login gagal agar tidak ada data parsial.
      _user = null;
      _guru = null;
      // Jika signIn berhasil tapi getGuru gagal, sign out dari Firebase
      // agar state tetap konsisten.
      try { await _auth.signOut(); } catch (_) {}
      notifyListeners();
      rethrow;
    } finally {
      _isLoggingIn = false;
    }
  }

  Future<void> register(String email, String password, String nama) async {
    _isRegistering = true;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw Exception('Gagal membuat akun: user tidak ditemukan');
      }

      final guru = Guru(
        id: credential.user!.uid,
        nama: nama,
        email: email,
        createdAt: DateTime.now(),
      );

      try {
        await _firestoreService.addGuru(guru);
      } catch (e) {
        // Jika penyimpanan data guru gagal, hapus auth user
        // untuk mencegah akun yatim (tanpa data Firestore).
        try {
          await credential.user!.delete();
        } catch (deleteError) {
          debugPrint('Gagal menghapus auth user setelah error addGuru: $deleteError');
        }
        rethrow;
      }

      // Sign out agar user tidak auto-login — user harus login manual
      await _auth.signOut();
    } finally {
      _isRegistering = false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    // _onAuthStateChanged akan dipanggil dengan user = null
  }
}
