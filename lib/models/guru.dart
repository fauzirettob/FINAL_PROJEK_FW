import 'package:cloud_firestore/cloud_firestore.dart';

class Guru {
  final String id;
  final String nama;
  final String email;
  final String role;
  final String? fotoUrl;
  final DateTime createdAt;

  Guru({
    required this.id,
    required this.nama,
    required this.email,
    this.role = 'guru',
    this.fotoUrl,
    required this.createdAt,
  });

  factory Guru.fromMap(Map<String, dynamic> data, String id) {
    return Guru(
      id: id,
      nama: data['nama'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'guru',
      fotoUrl: data['fotoUrl'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'email': email,
      'role': role,
      'fotoUrl': fotoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Guru copyWith({String? fotoUrl}) {
    return Guru(
      id: id,
      nama: nama,
      email: email,
      role: role,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      createdAt: createdAt,
    );
  }
}
