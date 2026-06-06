import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:absensi_siswa/services/storage_service.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseStorage>(),
  MockSpec<Reference>(),
  MockSpec<UploadTask>(),
  MockSpec<TaskSnapshot>(),
])
import 'storage_service_test.mocks.dart';

/// Subclass MockUploadTask untuk meng-override `then` secara langsung,
/// karena Mockito tidak bisa men-stub generic method `then<S>` dengan benar
/// ketika dipanggil oleh `await`.
class _TestUploadTask extends MockUploadTask {
  final TaskSnapshot _snapshot;

  _TestUploadTask(this._snapshot);

  @override
  Future<S> then<S>(
    FutureOr<S> Function(TaskSnapshot)? onValue, {
    Function? onError,
  }) async {
    if (onValue != null) {
      await onValue(_snapshot);
    }
    return Future.value(_snapshot as dynamic) as Future<S>;
  }
}

void main() {
  late MockFirebaseStorage mockStorage;
  late MockReference mockRef;
  late MockReference mockChildRef;
  late MockTaskSnapshot mockTaskSnapshot;
  late StorageService service;
  late File testFile;

  setUp(() {
    mockStorage = MockFirebaseStorage();
    mockRef = MockReference();
    mockChildRef = MockReference();
    mockTaskSnapshot = MockTaskSnapshot();
    testFile = File('test.jpg');

    service = StorageService(storage: mockStorage);
  });

  group('StorageService', () {
    group('uploadFoto()', () {
      const absensiId = 'abs-123';
      const expectedFileName = 'absensi/abs-123.jpg';
      const downloadUrl = 'https://storage.example.com/absensi/abs-123.jpg';

      setUp(() {
        when(mockStorage.ref()).thenReturn(mockRef);
        when(mockRef.child(expectedFileName)).thenReturn(mockChildRef);
        when(mockChildRef.putFile(any, any))
            .thenAnswer((_) => _TestUploadTask(mockTaskSnapshot));
        when(mockChildRef.getDownloadURL()).thenAnswer((_) async => downloadUrl);
      });

      test('berhasil upload foto dan mengembalikan URL download', () async {
        final result = await service.uploadFoto(
          file: testFile,
          absensiId: absensiId,
        );

        expect(result, equals(downloadUrl));
        verify(mockStorage.ref()).called(1);
        verify(mockRef.child(expectedFileName)).called(1);
        verify(mockChildRef.putFile(testFile, any)).called(1);
        verify(mockChildRef.getDownloadURL()).called(1);
      });

      test('mengirim metadata yang benar ke putFile', () async {
        await service.uploadFoto(file: testFile, absensiId: absensiId);

        final captured =
            verify(mockChildRef.putFile(captureAny, captureAny)).captured;
        expect(captured[0], equals(testFile));
        final metadata = captured[1] as SettableMetadata;
        expect(metadata.contentType, equals('image/jpeg'));
        expect(metadata.customMetadata, containsPair('uploadedAt', isNotEmpty));
      });

      test('melempar error ketika putFile gagal', () async {
        when(mockChildRef.putFile(any, any))
            .thenThrow(Exception('Upload failed'));

        expect(
          service.uploadFoto(file: testFile, absensiId: absensiId),
          throwsA(isA<Exception>()),
        );
        verifyNever(mockChildRef.getDownloadURL());
      });

      test('melempar error ketika getDownloadURL gagal', () async {
        when(mockChildRef.getDownloadURL())
            .thenAnswer((_) => Future.error(Exception('URL fetch failed')));

        expect(
          service.uploadFoto(file: testFile, absensiId: absensiId),
          throwsA(isA<Exception>()),
        );
      });

      test('melempar FirebaseException dari Firebase Storage', () async {
        when(mockChildRef.putFile(any, any)).thenThrow(
          FirebaseException(
            plugin: 'firebase_storage',
            message: 'Object does not exist',
            code: 'object-not-found',
          ),
        );

        expect(
          service.uploadFoto(file: testFile, absensiId: absensiId),
          throwsA(isA<FirebaseException>()),
        );
      });
    });

    group('hapusFoto()', () {
      const fotoUrl = 'https://storage.example.com/absensi/abc.jpg';

      test('berhasil menghapus foto', () async {
        when(mockStorage.refFromURL(fotoUrl)).thenReturn(mockChildRef);
        when(mockChildRef.delete()).thenAnswer((_) async => {});

        await service.hapusFoto(fotoUrl);
        verify(mockStorage.refFromURL(fotoUrl)).called(1);
        verify(mockChildRef.delete()).called(1);
      });

      test('tidak melempar error jika file tidak ditemukan', () async {
        when(mockStorage.refFromURL(fotoUrl)).thenReturn(mockChildRef);
        when(mockChildRef.delete()).thenThrow(
          FirebaseException(
            plugin: 'firebase_storage',
            message: 'Object does not exist',
            code: 'object-not-found',
          ),
        );

        await service.hapusFoto(fotoUrl);
        verify(mockStorage.refFromURL(fotoUrl)).called(1);
        verify(mockChildRef.delete()).called(1);
      });

      test('tidak melempar error untuk error lainnya (silent catch)', () async {
        when(mockStorage.refFromURL(fotoUrl)).thenReturn(mockChildRef);
        when(mockChildRef.delete()).thenThrow(Exception('Unknown error'));

        await service.hapusFoto(fotoUrl);
        verify(mockStorage.refFromURL(fotoUrl)).called(1);
        verify(mockChildRef.delete()).called(1);
      });

      test('refFromURL juga di-catch silent oleh hapusFoto', () async {
        when(mockStorage.refFromURL(fotoUrl))
            .thenThrow(Exception('Invalid URL'));

        await service.hapusFoto(fotoUrl);
        verify(mockStorage.refFromURL(fotoUrl)).called(1);
        verifyNever(mockChildRef.delete());
      });
    });
  });
}
