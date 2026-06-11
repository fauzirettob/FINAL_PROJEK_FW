import 'package:cloud_firestore/cloud_firestore.dart';

class Siswa {
  final String id;
  final String nama;
  final String nis;
  final String kelas;
  final String namaOrtu;
  final String hpOrtu;
  final String? fotoUrl;
  final DateTime createdAt;

  Siswa({
    required this.id,
    required this.nama,
    required this.nis,
    required this.kelas,
    required this.namaOrtu,
    required this.hpOrtu,
    this.fotoUrl,
    required this.createdAt,
  });

  factory Siswa.fromMap(Map<String, dynamic> data, String id) {
    return Siswa(
      id: id,
      nama: data['nama'] ?? '',
      nis: data['nis'] ?? '',
      kelas: data['kelas'] ?? '',
      namaOrtu: data['namaOrtu'] ?? '',
      hpOrtu: data['hpOrtu'] ?? '',
      fotoUrl: data['fotoUrl'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'nis': nis,
      'kelas': kelas,
      'namaOrtu': namaOrtu,
      'hpOrtu': hpOrtu,
      'fotoUrl': fotoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
