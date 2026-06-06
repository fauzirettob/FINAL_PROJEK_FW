import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/teguran.dart';
import '../services/firestore_service.dart';

class TeguranProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  StreamSubscription<List<Teguran>>? _subscription;
  List<Teguran> _teguranList = [];
  int _todayCount = 0;
  bool _isInitialized = false;
  String? _guruId;

  TeguranProvider({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  int get todayCount => _todayCount;
  List<Teguran> get teguranList => _teguranList;
  bool get isInitialized => _isInitialized;

  /// Mulai mendengarkan stream teguran dari guru yang login
  void startListeningForGuru(String guruId) {
    if (_guruId == guruId && _isInitialized) return;
    _guruId = guruId;
    _subscription?.cancel();
    _subscription = _firestoreService.getTeguranByGuruId(guruId).listen(
      (list) {
        _teguranList = list;
        _todayCount = _hitungTeguranHariIni(list);
        _isInitialized = true;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('TeguranProvider stream error: $error');
      },
    );
  }

  /// Hentikan langganan stream
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Hitung jumlah teguran yang dibuat hari ini
  int _hitungTeguranHariIni(List<Teguran> list) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return list.where((t) {
      final tgl = DateTime(t.tanggal.year, t.tanggal.month, t.tanggal.day);
      return tgl == today;
    }).length;
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
