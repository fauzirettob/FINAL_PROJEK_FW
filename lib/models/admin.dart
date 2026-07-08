import 'package:cloud_firestore/cloud_firestore.dart';

class Admin {
  final String id;
  final String nama;
  final String email;
  final String role;
  final String? fotoUrl;
  final DateTime createdAt;

  Admin({
    required this.id,
    required this.nama,
    required this.email,
    this.role = 'admin',
    this.fotoUrl,
    required this.createdAt,
  });

  factory Admin.fromMap(Map<String, dynamic> data, String id) {
    return Admin(
      id: id,
      nama: data['nama'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'admin',
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

  Admin copyWith({String? fotoUrl}) {
    return Admin(
      id: id,
      nama: nama,
      email: email,
      role: role,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      createdAt: createdAt,
    );
  }
}
