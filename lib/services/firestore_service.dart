import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/siswa.dart';
import '../models/absensi.dart';
import '../models/guru.dart';
import '../models/teguran.dart';
import '../models/keluhan.dart';

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

  // --- TEGURAN ---

  Future<void> addTeguran(Teguran teguran) async {
    await _db.collection('teguran').doc(teguran.id).set(teguran.toMap());
  }

  Stream<List<Teguran>> getTeguranStream() {
    return _db
        .collection('teguran')
        .orderBy('tanggal', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Teguran.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<Teguran>> getTeguranByGuruId(String guruId) {
    return _db
        .collection('teguran')
        .where('guruId', isEqualTo: guruId)
        .orderBy('tanggal', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Teguran.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<Teguran>> getTeguranBySiswaId(String siswaId) {
    return _db
        .collection('teguran')
        .where('siswaId', isEqualTo: siswaId)
        .orderBy('tanggal', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Teguran.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> updateTeguran(String id, Map<String, dynamic> data) async {
    await _db.collection('teguran').doc(id).update(data);
  }

  Future<void> deleteTeguran(String id) async {
    await _db.collection('teguran').doc(id).delete();
  }

  // --- KELUHAN ---

  Future<void> addKeluhan(Keluhan keluhan) async {
    await _db.collection('keluhan').doc(keluhan.id).set(keluhan.toMap());
  }

  Stream<List<Keluhan>> getKeluhanStream() {
    return _db
        .collection('keluhan')
        .orderBy('tanggal', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Keluhan.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Keluhan untuk siswa tertentu (berguna untuk guru melihat per siswa)
  Stream<List<Keluhan>> getKeluhanBySiswaId(String siswaId) {
    return _db
        .collection('keluhan')
        .where('siswaId', isEqualTo: siswaId)
        .orderBy('tanggal', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Keluhan.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Keluhan dari orang tua tertentu berdasarkan nomor HP
  Stream<List<Keluhan>> getKeluhanByHpOrtu(String hpOrtu) {
    return _db
        .collection('keluhan')
        .where('hpOrtu', isEqualTo: hpOrtu)
        .orderBy('tanggal', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Keluhan.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Keluhan untuk guru tertentu
  Stream<List<Keluhan>> getKeluhanByGuruId(String guruId) {
    return _db
        .collection('keluhan')
        .where('guruId', isEqualTo: guruId)
        .orderBy('tanggal', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Keluhan.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> updateKeluhan(String id, Map<String, dynamic> data) async {
    await _db.collection('keluhan').doc(id).update(data);
  }

  Future<void> deleteKeluhan(String id) async {
    await _db.collection('keluhan').doc(id).delete();
  }
}
