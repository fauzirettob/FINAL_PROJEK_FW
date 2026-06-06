import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Upload file foto ke Firebase Storage dan return URL download.
  Future<String> uploadFoto({
    required File file,
    required String absensiId,
  }) async {
    final fileName = 'absensi/$absensiId.jpg';
    final ref = _storage.ref().child(fileName);

    await ref.putFile(
      file,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      ),
    );

    final downloadUrl = await ref.getDownloadURL();
    return downloadUrl;
  }

  /// Hapus foto dari Storage berdasarkan URL (optional, untuk cleanup).
  Future<void> hapusFoto(String fotoUrl) async {
    try {
      final ref = _storage.refFromURL(fotoUrl);
      await ref.delete();
    } catch (e) {
      // Abaikan jika file tidak ditemukan
    }
  }
}
