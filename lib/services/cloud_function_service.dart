import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Service untuk memanggil Cloud Functions dari Firebase.
///
 /// Method [addGuru] membuat akun guru baru via Admin SDK
 /// tanpa mengubah session admin yang sedang login.
class CloudFunctionService {
  final FirebaseFunctions _functions;

  CloudFunctionService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  /// Panggil Cloud Function `addGuru` untuk membuat akun guru baru.
  ///
  /// [email]    — Email guru (wajib)
  /// [password] — Password minimal 6 karakter (wajib)
  /// [nama]     — Nama lengkap guru (wajib)
  ///
  /// Return Map dengan key `success` (bool) dan `uid` (String).
  ///
  /// Throw [FirebaseFunctionsException] jika Cloud Function menolak.
  Future<Map<String, dynamic>> addGuru({
    required String email,
    required String password,
    required String nama,
  }) async {
    try {
      final result = await _functions.httpsCallable('addGuru').call({
        'email': email,
        'password': password,
        'nama': nama,
      });

      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('CloudFunctionService.addGuru error [${e.code}]: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('CloudFunctionService.addGuru unexpected error: $e');
      rethrow;
    }
  }
}
