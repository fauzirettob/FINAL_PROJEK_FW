import 'package:cloud_firestore/cloud_firestore.dart';

class Guru {
  final String id;
  final String nip;
  final String nama;
  final String email;
  final String role;
  final String? fotoUrl;
  final List<String> mapelList;
  final List<String> kelasList;
  final String? waliKelas;
  final DateTime createdAt;

  Guru({
    required this.id,
    this.nip = '',
    required this.nama,
    required this.email,
    this.role = 'guru',
    this.fotoUrl,
    this.mapelList = const [],
    this.kelasList = const [],
    this.waliKelas,
    required this.createdAt,
  });

  /// Apakah guru ini adalah wali kelas
  bool get isWaliKelas => waliKelas != null && waliKelas!.isNotEmpty;

  /// Konversi aman dari dynamic ke List<String>.
  /// Menangani null, tipe bukan List, dan isi yang bukan String.
  static List<String> _safeStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }

  factory Guru.fromMap(Map<String, dynamic> data, String id) {
    return Guru(
      id: id,
      nip: data['nip'] ?? '',
      nama: data['nama'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'guru',
      fotoUrl: data['fotoUrl'],
      mapelList: _safeStringList(data['mapelList']),
      kelasList: _safeStringList(data['kelasList']),
      waliKelas: data['waliKelas'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nip': nip,
      'nama': nama,
      'email': email,
      'role': role,
      'fotoUrl': fotoUrl,
      'mapelList': mapelList,
      'kelasList': kelasList,
      'waliKelas': waliKelas,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Guru copyWith({String? fotoUrl, List<String>? mapelList, List<String>? kelasList, String? waliKelas}) {
    return Guru(
      id: id,
      nip: nip,
      nama: nama,
      email: email,
      role: role,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      mapelList: mapelList ?? this.mapelList,
      kelasList: kelasList ?? this.kelasList,
      waliKelas: waliKelas ?? this.waliKelas,
      createdAt: createdAt,
    );
  }
}
