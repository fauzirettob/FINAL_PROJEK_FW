import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/siswa.dart';
import '../models/absensi.dart';
import '../models/guru.dart';
import '../models/admin.dart';

class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  // --- SISWA ---
  Future<void> addSiswa(Siswa siswa) async {
    await _db.collection('siswa').doc(siswa.id).set(siswa.toMap());
  }

  Stream<List<Siswa>> getSiswaStream() {
    return _db
        .collection('siswa')
        .orderBy('nama')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Siswa.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<List<Siswa>> getAllSiswa() async {
    final snapshot = await _db.collection('siswa').orderBy('nama').get();
    return snapshot.docs
        .map((doc) => Siswa.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> updateSiswa(String id, Map<String, dynamic> data) async {
    await _db.collection('siswa').doc(id).update(data);
  }

  Future<void> deleteSiswa(String siswaId) async {
    await _db.collection('siswa').doc(siswaId).delete();
  }

  Future<Siswa?> getSiswaByNIS(String nis) async {
    final q = await _db
        .collection('siswa')
        .where('nis', isEqualTo: nis)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return Siswa.fromMap(q.docs.first.data(), q.docs.first.id);
  }

  Future<Siswa?> getSiswaById(String id) async {
    final doc = await _db.collection('siswa').doc(id).get();
    if (!doc.exists) return null;
    return Siswa.fromMap(doc.data()!, doc.id);
  }

  /// Cari siswa berdasarkan nomor HP orang tua
  Future<List<Siswa>> getSiswaByHpOrtu(String hpOrtu) async {
    final q = await _db
        .collection('siswa')
        .where('hpOrtu', isEqualTo: hpOrtu)
        .get();
    return q.docs
        .map((doc) => Siswa.fromMap(doc.data(), doc.id))
        .toList();
  }

  // --- GURU ---
  Future<void> addGuru(Guru guru) async {
    await _db.collection('guru').doc(guru.id).set(guru.toMap());
  }

  Future<Guru?> getGuru(String id) async {
    final doc = await _db.collection('guru').doc(id).get();
    if (!doc.exists) return null;
    return Guru.fromMap(doc.data()!, doc.id);
  }

  Future<List<Guru>> getAllGuru() async {
    final snapshot = await _db.collection('guru').orderBy('nama').get();
    return snapshot.docs
        .map((doc) => Guru.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> deleteGuru(String id) async {
    await _db.collection('guru').doc(id).delete();
  }

  // --- ADMIN ---
  Future<void> addAdmin(Admin admin) async {
    // 1. Simpan dokumen admin terlebih dahulu (create rule: isOwner(userId))
    await _db.collection('admin').doc(admin.id).set(admin.toMap());

    // 2. Update counter setelah admin doc sudah ada (write rule: isAdmin() jadi terpenuhi)
    await _ensureAdminCounterExists();
    await _db.collection('_counters').doc('admin_count').update({
      'count': FieldValue.increment(1),
    });
  }

  Future<Admin?> getAdmin(String id) async {
    final doc = await _db.collection('admin').doc(id).get();
    if (!doc.exists) return null;
    return Admin.fromMap(doc.data()!, doc.id);
  }

  Future<List<Admin>> getAllAdmin() async {
    final snapshot = await _db.collection('admin').orderBy('nama').get();
    return snapshot.docs
        .map((doc) => Admin.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> deleteAdmin(String id) async {
    final batch = _db.batch();
    batch.delete(_db.collection('admin').doc(id));
    batch.update(_db.collection('_counters').doc('admin_count'), {
      'count': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  /// Inisialisasi counter dokumen admin_count jika belum ada.
  /// Tidak membaca collection 'admin' (bisa kena permission-denied saat registrasi).
  /// Cukup set count=0; akan dikoreksi oleh addAdmin/deleteAdmin.
  Future<void> _ensureAdminCounterExists() async {
    final doc = await _db.collection('_counters').doc('admin_count').get();
    if (!doc.exists) {
      await _db.collection('_counters').doc('admin_count').set({
        'count': 0,
      });
    }
  }

  /// Sinkronkan counter admin dengan jumlah aktual dari collection admin.
  /// Panggil dari halaman kelola admin (admin sudah terautentikasi).
  Future<void> syncAdminCounter() async {
    final snapshot = await _db.collection('admin').get();
    await _db.collection('_counters').doc('admin_count').set({
      'count': snapshot.docs.length,
    });
  }

  /// Stream jumlah admin secara real-time via counter doc
  Stream<int> getAdminCountStream() {
    return _db
        .collection('_counters')
        .doc('admin_count')
        .snapshots()
        .map((doc) => (doc.data()?['count'] as int?) ?? 0);
  }

  /// Ambil jumlah admin saat ini dari counter doc
  Future<int> getAdminCount() async {
    try {
      final doc = await _db.collection('_counters').doc('admin_count').get();
      return (doc.data()?['count'] as int?) ?? 0;
    } catch (e) {
      // Fallback: hitung langsung dari collection jika counter belum ada
      final snapshot = await _db.collection('admin').get();
      return snapshot.docs.length;
    }
  }

  // --- ABSENSI ---
  Future<void> addAbsensi(Absensi absensi) async {
    await _db.collection('absensi').doc(absensi.id).set(absensi.toMap());
  }

  Stream<List<Absensi>> getAbsensiHariIni(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    return _db
        .collection('absensi')
        .where('tanggal', isGreaterThanOrEqualTo: start)
        .where('tanggal', isLessThan: end)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Absensi.fromMap(doc.data(), doc.id))
              .toList()
              ..sort((a, b) => b.jam.compareTo(a.jam)),
        );
  }

  /// Data absensi untuk seorang siswa, diurutkan dari terbaru.
  Stream<List<Absensi>> getAbsensiBySiswaId(String siswaId) {
    return _db
        .collection('absensi')
        .where('siswaId', isEqualTo: siswaId)
        .orderBy('tanggal', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Absensi.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Semua data absensi, diurutkan dari terbaru.
  Stream<List<Absensi>> getAllAbsensi() {
    return _db
        .collection('absensi')
        .orderBy('tanggal', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Absensi.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Hapus absensi dari Firestore berdasarkan ID.
  Future<void> deleteAbsensi(String absensiId) async {
    await _db.collection('absensi').doc(absensiId).delete();
  }

  /// Hapus semua absensi milik seorang siswa berdasarkan siswaId.
  Future<void> deleteAbsensiBySiswaId(String siswaId) async {
    final snapshot = await _db
        .collection('absensi')
        .where('siswaId', isEqualTo: siswaId)
        .get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// --- NEW: ABSENSI PER KELAS ---

  /// Ambil absensi untuk kelas dan tanggal tertentu
  Future<List<Absensi>> getAbsensiByKelasAndDate(String kelas, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final snapshot = await _db
        .collection('absensi')
        .where('kelas', isEqualTo: kelas)
        .where('tanggal', isGreaterThanOrEqualTo: start)
        .where('tanggal', isLessThan: end)
        .get();

    return snapshot.docs
        .map((doc) => Absensi.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Update field tertentu pada dokumen absensi
  Future<void> updateAbsensi(String id, Map<String, dynamic> data) async {
    await _db.collection('absensi').doc(id).update(data);
  }

  /// Simpan banyak absensi sekaligus dalam batch
  Future<void> batchSaveAbsensi(List<Absensi> records) async {
    final batch = _db.batch();
    for (final record in records) {
      batch.set(
        _db.collection('absensi').doc(record.id),
        record.toMap(),
      );
    }
    await batch.commit();
  }

  /// --- LOCK KELAS ---

  /// Cek apakah kelas sudah dikunci untuk tanggal tertentu
  Future<bool> isKelasLocked(String kelas, DateTime date) async {
    final docId = '${kelas}_${DateFormat('yyyy-MM-dd').format(date)}';
    final doc = await _db.collection('kelas_locks').doc(docId).get();
    return doc.exists && doc.data()?['isLocked'] == true;
  }

  /// Kunci kelas untuk tanggal tertentu (cegah perubahan absensi)
  Future<void> lockKelas(String kelas, DateTime date, String lockedBy) async {
    final docId = '${kelas}_${DateFormat('yyyy-MM-dd').format(date)}';
    await _db.collection('kelas_locks').doc(docId).set({
      'kelas': kelas,
      'tanggal': Timestamp.fromDate(date),
      'isLocked': true,
      'lockedAt': Timestamp.now(),
      'lockedBy': lockedBy,
    });
  }

  /// --- NOTIFIKASI KELAS ---

  /// Cek apakah notifikasi sudah pernah dikirim untuk kelas+ tanggal
  Future<bool> isNotifikasiKelasSent(String kelas, DateTime date) async {
    final docId = '${kelas}_${DateFormat('yyyy-MM-dd').format(date)}';
    final doc = await _db.collection('kelas_notifikasi').doc(docId).get();
    return doc.exists && doc.data()?['dikirim'] == true;
  }

  /// Tandai notifikasi sudah dikirim untuk kelas+ tanggal
  Future<void> markNotifikasiKelasSent(String kelas, DateTime date) async {
    final docId = '${kelas}_${DateFormat('yyyy-MM-dd').format(date)}';
    await _db.collection('kelas_notifikasi').doc(docId).set({
      'kelas': kelas,
      'tanggal': Timestamp.fromDate(date),
      'dikirim': true,
      'dikirimAt': Timestamp.now(),
    });
  }
}
