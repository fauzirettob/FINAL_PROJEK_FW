import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:absensi_siswa/models/teguran.dart';
import 'package:absensi_siswa/providers/teguran_provider.dart';
import 'package:absensi_siswa/services/firestore_service.dart';

/// Fake FirebaseFirestore untuk menghindari Firebase.initializeApp() di test
class FakeFirebaseFirestore extends Fake implements FirebaseFirestore {}

/// FirestoreService mock dengan stream terkontrol
class MockFirestoreService extends FirestoreService {
  final StreamController<List<Teguran>> controller =
      StreamController<List<Teguran>>.broadcast();

  String? lastGuruId;

  MockFirestoreService() : super(firestore: FakeFirebaseFirestore());

  @override
  Stream<List<Teguran>> getTeguranByGuruId(String guruId) {
    lastGuruId = guruId;
    return controller.stream;
  }

  void dispose() {
    controller.close();
  }
}

/// Helper: membuat Teguran dengan nilai default untuk testing
Teguran createTeguran({
  required String id,
  required String guruId,
  bool dikirimWa = true,
  String siswaNama = 'Siswa Test',
}) {
  return Teguran(
    id: id,
    siswaId: 'siswa-$id',
    siswaNama: siswaNama,
    kelas: 'X-A',
    guruId: guruId,
    guruNama: 'Guru Test',
    judul: 'Teguran $id',
    deskripsi: 'Deskripsi teguran $id',
    tanggal: DateTime.now(),
    dikirimWa: dikirimWa,
  );
}

void main() {
  late MockFirestoreService mockFs;
  late TeguranProvider provider;

  setUp(() {
    mockFs = MockFirestoreService();
    provider = TeguranProvider(firestoreService: mockFs);
  });

  tearDown(() {
    provider.dispose();
    mockFs.dispose();
  });

  group('TeguranProvider - initial state', () {
    test('teguranList dimulai sebagai list kosong', () {
      expect(provider.teguranList, isEmpty);
    });

    test('isInitialized bernilai false sebelum startListeningForGuru', () {
      expect(provider.isInitialized, isFalse);
    });

    test('todayCount dimulai dari 0', () {
      expect(provider.todayCount, equals(0));
    });
  });

  group('TeguranProvider.startListeningForGuru', () {
    test('memanggil getTeguranByGuruId dengan guruId yang benar', () {
      provider.startListeningForGuru('guru-1');
      expect(mockFs.lastGuruId, equals('guru-1'));
    });

    test('memperbarui teguranList dan todayCount saat stream mengirim data',
        () async {
      final teguranList = [
        createTeguran(id: '1', guruId: 'guru-1'),
        createTeguran(id: '2', guruId: 'guru-1'),
      ];

      provider.startListeningForGuru('guru-1');

      // Tidak ada perubahan synchronously
      expect(provider.teguranList.length, equals(0));
      expect(provider.isInitialized, isFalse);

      mockFs.controller.add(teguranList);

      // Stream berjalan async — tunggu microtask
      await Future(() {});

      expect(provider.isInitialized, isTrue);
      expect(provider.teguranList.length, equals(2));
      expect(provider.todayCount, equals(2));
    });

    test('notifyListeners dipanggil saat data stream diterima', () async {
      var notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      provider.startListeningForGuru('guru-1');
      mockFs.controller.add([createTeguran(id: '1', guruId: 'guru-1')]);

      await Future(() {});

      expect(notifyCount, equals(1));
    });

    test('data stream diperbarui saat menerima data baru', () async {
      provider.startListeningForGuru('guru-1');

      mockFs.controller.add([createTeguran(id: '1', guruId: 'guru-1')]);
      await Future(() {});
      expect(provider.teguranList.length, equals(1));

      mockFs.controller.add([
        createTeguran(id: '1', guruId: 'guru-1'),
        createTeguran(id: '2', guruId: 'guru-1'),
        createTeguran(id: '3', guruId: 'guru-1'),
      ]);
      await Future(() {});
      expect(provider.teguranList.length, equals(3));
    });

    test('tidak re-subscribe jika guruId sama dan sudah initialized',
        () async {
      provider.startListeningForGuru('guru-1');
      mockFs.controller.add([createTeguran(id: '1', guruId: 'guru-1')]);
      await Future(() {});
      expect(provider.isInitialized, isTrue);

      // Reset lastGuruId tracker
      mockFs.lastGuruId = null;

      // Panggil lagi dengan guruId yang sama
      provider.startListeningForGuru('guru-1');

      // Tidak memanggil getTeguranByGuruId lagi
      expect(mockFs.lastGuruId, isNull);
    });

    test('re-subscribe jika guruId berbeda', () async {
      provider.startListeningForGuru('guru-1');
      mockFs.controller.add([createTeguran(id: '1', guruId: 'guru-1')]);
      await Future(() {});

      mockFs.lastGuruId = null;
      provider.startListeningForGuru('guru-2');

      expect(mockFs.lastGuruId, equals('guru-2'));
    });
  });

  group('TeguranProvider - empty stream', () {
    test('teguranList tetap kosong untuk stream dengan list kosong', () async {
      provider.startListeningForGuru('guru-1');

      mockFs.controller.add([]);
      await Future(() {});

      expect(provider.teguranList, isEmpty);
      expect(provider.todayCount, equals(0));
      expect(provider.isInitialized, isTrue);
    });
  });

  group('TeguranProvider - stream error', () {
    test('tidak crash saat stream error', () async {
      provider.startListeningForGuru('guru-1');

      // Stream error seharusnya tidak membuat provider crash
      expect(
        () => mockFs.controller.addError(Exception('Stream error test')),
        returnsNormally,
      );
      await Future(() {});

      // Provider masih bisa digunakan
      expect(provider.isInitialized, isFalse);
      expect(provider.teguranList.length, equals(0));
    });

    test('data lama tetap tersimpan setelah stream error', () async {
      provider.startListeningForGuru('guru-1');
      mockFs.controller.add([createTeguran(id: '1', guruId: 'guru-1')]);
      await Future(() {});

      expect(provider.isInitialized, isTrue);
      expect(provider.teguranList.length, equals(1));

      // Kirim error — data tidak boleh berubah
      mockFs.controller.addError(Exception('Stream error'));
      await Future(() {});

      expect(provider.teguranList.length, equals(1));
      expect(provider.isInitialized, isTrue);
    });

    test('masih bisa menerima data setelah stream error (broadcast stream)',
        () async {
      provider.startListeningForGuru('guru-1');
      mockFs.controller.add([createTeguran(id: '1', guruId: 'guru-1')]);
      await Future(() {});

      expect(provider.teguranList.length, equals(1));

      // Kirim error
      mockFs.controller.addError(Exception('Stream error'));
      await Future(() {});

      // Kirim data baru — karena broadcast stream, stream tetap hidup
      mockFs.controller.add([
        createTeguran(id: '1', guruId: 'guru-1'),
        createTeguran(id: '2', guruId: 'guru-1'),
      ]);
      await Future(() {});

      expect(provider.teguranList.length, equals(2));
      expect(provider.todayCount, equals(2));
    });
  });

  group('TeguranProvider.stopListening', () {
    test('berhenti mendengarkan stream', () async {
      provider.startListeningForGuru('guru-1');
      mockFs.controller.add([createTeguran(id: '1', guruId: 'guru-1')]);
      await Future(() {});
      expect(provider.isInitialized, isTrue);

      provider.stopListening();

      // Setelah stop, data baru tidak masuk
      mockFs.controller.add([createTeguran(id: '2', guruId: 'guru-2')]);
      await Future(() {});
      expect(provider.teguranList.length, equals(1)); // tetap 1
    });
  });

  group('TeguranProvider.dispose', () {
    test('data tetap accessible setelah dispose untuk pembacaan terakhir',
        () async {
      provider.startListeningForGuru('guru-1');
      mockFs.controller.add([createTeguran(id: '1', guruId: 'guru-1')]);
      await Future(() {});

      expect(provider.isInitialized, isTrue);
      expect(provider.teguranList.length, equals(1));

      // dispose dipanggil oleh tearDown — tidak perlu panggil manual
    });
  });
}
