import 'package:cloud_firestore/cloud_firestore.dart';

class Siswa {
  final String id;
  final String nama;
  final String nis;
  final String kelas;
  final String kategori;
  final String namaOrtu;
  final String hpOrtu;
  final String pinOrtu;
  final String? fotoUrl;
  final DateTime createdAt;

  Siswa({
    required this.id,
    required this.nama,
    required this.nis,
    required this.kelas,
    required this.kategori,
    required this.namaOrtu,
    required this.hpOrtu,
    this.pinOrtu = '',
    this.fotoUrl,
    required this.createdAt,
  });

  factory Siswa.fromMap(Map<String, dynamic> data, String id) {
    return Siswa(
      id: id,
      nama: data['nama'] ?? '',
      nis: data['nis'] ?? '',
      kelas: data['kelas'] ?? '',
      kategori: data['kategori'] ?? '',
      namaOrtu: data['namaOrtu'] ?? '',
      hpOrtu: data['hpOrtu'] ?? '',
      pinOrtu: data['pinOrtu'] ?? '',
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
      'kategori': kategori,
      'namaOrtu': namaOrtu,
      'hpOrtu': hpOrtu,
      'pinOrtu': pinOrtu,
      'fotoUrl': fotoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
