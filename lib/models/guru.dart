import 'package:cloud_firestore/cloud_firestore.dart';

class Guru {
  final String id;
  final String nama;
  final String email;
  final DateTime createdAt;

  Guru({
    required this.id,
    required this.nama,
    required this.email,
    required this.createdAt,
  });

  factory Guru.fromMap(Map<String, dynamic> data, String id) {
    return Guru(
      id: id,
      nama: data['nama'] ?? '',
      email: data['email'] ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
