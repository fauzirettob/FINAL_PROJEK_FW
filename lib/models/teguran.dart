import 'package:cloud_firestore/cloud_firestore.dart';

class Teguran {
  final String id;
  final String siswaId;
  final String siswaNama;
  final String kelas;
  final String guruId;
  final String guruNama;
  final String judul;
  final String deskripsi;
  final DateTime tanggal;
  final bool dikirimWa;

  Teguran({
    required this.id,
    required this.siswaId,
    required this.siswaNama,
    required this.kelas,
    required this.guruId,
    required this.guruNama,
    required this.judul,
    required this.deskripsi,
    required this.tanggal,
    this.dikirimWa = false,
  });

  factory Teguran.fromMap(Map<String, dynamic> data, String id) {
    return Teguran(
      id: id,
      siswaId: data['siswaId'] ?? '',
      siswaNama: data['siswaNama'] ?? '',
      kelas: data['kelas'] ?? '',
      guruId: data['guruId'] ?? '',
      guruNama: data['guruNama'] ?? '',
      judul: data['judul'] ?? '',
      deskripsi: data['deskripsi'] ?? '',
      tanggal: data['tanggal'] is Timestamp
          ? (data['tanggal'] as Timestamp).toDate()
          : DateTime.now(),
      dikirimWa: data['dikirimWa'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'siswaId': siswaId,
      'siswaNama': siswaNama,
      'kelas': kelas,
      'guruId': guruId,
      'guruNama': guruNama,
      'judul': judul,
      'deskripsi': deskripsi,
      'tanggal': Timestamp.fromDate(tanggal),
      'dikirimWa': dikirimWa,
    };
  }
}
