import 'package:cloud_firestore/cloud_firestore.dart';

class Keluhan {
  final String id;
  final String? siswaId;
  final String? siswaNama;
  final String? kelas;
  final String namaOrtu;
  final String hpOrtu;
  final String judul;
  final String deskripsi;
  final DateTime tanggal;
  final String status; // 'pending', 'dibaca', 'selesai'
  final String? catatanGuru;
  final DateTime? tanggalDitindak;
  final String? guruId;

  Keluhan({
    required this.id,
    this.siswaId,
    this.siswaNama,
    this.kelas,
    required this.namaOrtu,
    required this.hpOrtu,
    required this.judul,
    required this.deskripsi,
    required this.tanggal,
    this.status = 'pending',
    this.catatanGuru,
    this.tanggalDitindak,
    this.guruId,
  });

  factory Keluhan.fromMap(Map<String, dynamic> data, String id) {
    return Keluhan(
      id: id,
      siswaId: data['siswaId'],
      siswaNama: data['siswaNama'],
      kelas: data['kelas'],
      namaOrtu: data['namaOrtu'] ?? '',
      hpOrtu: data['hpOrtu'] ?? '',
      judul: data['judul'] ?? '',
      deskripsi: data['deskripsi'] ?? '',
      tanggal: data['tanggal'] is Timestamp
          ? (data['tanggal'] as Timestamp).toDate()
          : DateTime.now(),
      status: data['status'] ?? 'pending',
      catatanGuru: data['catatanGuru'],
      tanggalDitindak: data['tanggalDitindak'] is Timestamp
          ? (data['tanggalDitindak'] as Timestamp).toDate()
          : null,
      guruId: data['guruId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (siswaId != null) 'siswaId': siswaId,
      if (siswaNama != null) 'siswaNama': siswaNama,
      if (kelas != null) 'kelas': kelas,
      'namaOrtu': namaOrtu,
      'hpOrtu': hpOrtu,
      'judul': judul,
      'deskripsi': deskripsi,
      'tanggal': Timestamp.fromDate(tanggal),
      'status': status,
      if (catatanGuru != null) 'catatanGuru': catatanGuru,
      if (tanggalDitindak != null)
        'tanggalDitindak': Timestamp.fromDate(tanggalDitindak!),
      if (guruId != null) 'guruId': guruId,
    };
  }
}
