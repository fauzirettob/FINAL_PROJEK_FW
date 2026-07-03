import 'package:cloud_firestore/cloud_firestore.dart';

class Admin {
  final String id;
  final String nama;
  final String email;
  final String role;
  final DateTime createdAt;

  Admin({
    required this.id,
    required this.nama,
    required this.email,
    this.role = 'admin',
    required this.createdAt,
  });

  factory Admin.fromMap(Map<String, dynamic> data, String id) {
    return Admin(
      id: id,
      nama: data['nama'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'admin',
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
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
