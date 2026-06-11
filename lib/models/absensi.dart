import 'package:cloud_firestore/cloud_firestore.dart';

class Absensi {
  final String id;
  final String siswaId;
  final String siswaNama;
  final String kelas;
  final DateTime tanggal;
  final String status; // hadir, izin, sakit, alpa
  final String jam;
  final bool dikirim;
  final String guruId;
  final String? fotoUrl;

  Absensi({
    required this.id,
    required this.siswaId,
    required this.siswaNama,
    required this.kelas,
    required this.tanggal,
    required this.status,
    required this.jam,
    this.dikirim = false,
    required this.guruId,
    this.fotoUrl,
  });

  factory Absensi.fromMap(Map<String, dynamic> data, String id) {
    return Absensi(
      id: id,
      siswaId: data['siswaId'] ?? '',
      siswaNama: data['siswaNama'] ?? '',
      kelas: data['kelas'] ?? '',
      tanggal: data['tanggal'] is Timestamp
          ? (data['tanggal'] as Timestamp).toDate()
          : DateTime.now(),
      status: data['status'] ?? 'hadir',
      jam: data['jam'] ?? '',
      dikirim: data['dikirim'] == true,
      guruId: data['guruId'] ?? '',
      fotoUrl: data['fotoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'siswaId': siswaId,
      'siswaNama': siswaNama,
      'kelas': kelas,
      'tanggal': Timestamp.fromDate(tanggal),
      'status': status,
      'jam': jam,
      'dikirim': dikirim,
      'guruId': guruId,
      if (fotoUrl != null) 'fotoUrl': fotoUrl,
    };
  }
}
