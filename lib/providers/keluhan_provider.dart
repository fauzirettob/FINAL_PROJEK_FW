import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/keluhan.dart';
import '../services/firestore_service.dart';

class KeluhanProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  StreamSubscription<List<Keluhan>>? _subscription;
  List<Keluhan> _keluhanList = [];
  int _pendingCount = 0;
  bool _isInitialized = false;

  KeluhanProvider({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  int get pendingCount => _pendingCount;
  List<Keluhan> get keluhanList => _keluhanList;
  bool get isInitialized => _isInitialized;

  /// Mulai mendengarkan semua keluhan dari stream
  void startListening() {
    if (_isInitialized) return;
    _subscription?.cancel();
    _subscription = _firestoreService.getKeluhanStream().listen(
      (list) {
        _keluhanList = list;
        _pendingCount = list.where((k) => k.status == 'pending').length;
        _isInitialized = true;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('KeluhanProvider stream error: $error');
      },
    );
  }

  /// Hentikan langganan stream
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
