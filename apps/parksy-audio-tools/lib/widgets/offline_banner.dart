import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

/// Offline status banner widget
/// Shows warning when network is unavailable
class OfflineBanner extends StatelessWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService.instance.onConnectivityChanged,
      initialData: ConnectivityService.instance.isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;

        return Column(
          children: [
            if (!isOnline)
              MaterialBanner(
                backgroundColor: Colors.orange.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                content: const Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '오프라인 상태입니다. MIDI 변환이 불가능합니다.',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                actions: const [SizedBox.shrink()],
              ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

/// Mixin for screens that need MIDI conversion
/// Provides offline-aware UI helpers
mixin OfflineAwareMixin<T extends StatefulWidget> on State<T> {
  bool get isOnline => ConnectivityService.instance.isOnline;

  /// Show message if offline, return false
  /// Return true if online and can proceed
  bool checkOnlineStatus() {
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('인터넷 연결이 필요합니다'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    return true;
  }
}
