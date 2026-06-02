import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Network connectivity service
/// Provides real-time network status monitoring
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  static ConnectivityService get instance => _instance;
  ConnectivityService._();

  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  Stream<bool> get onConnectivityChanged => _controller.stream;
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  /// Initialize and start monitoring
  Future<void> init() async {
    // Check initial status
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);

    // Listen for changes
    _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.isNotEmpty && 
                !results.contains(ConnectivityResult.none);
    
    if (wasOnline != _isOnline) {
      _controller.add(_isOnline);
    }
  }

  /// Check if MIDI conversion is available
  bool get canConvertMidi => _isOnline;

  void dispose() {
    _controller.close();
  }
}
