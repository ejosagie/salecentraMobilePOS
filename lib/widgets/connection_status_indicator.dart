import 'package:flutter/material.dart';
import '../services/offline_service.dart';

class ConnectionStatusIndicator extends StatefulWidget {
  final bool isOnline;
  final int offlineDaysRemaining;

  const ConnectionStatusIndicator({
    super.key,
    required this.isOnline,
    this.offlineDaysRemaining = 0,
  });

  @override
  State<ConnectionStatusIndicator> createState() => _ConnectionStatusIndicatorState();
}

class _ConnectionStatusIndicatorState extends State<ConnectionStatusIndicator> {
  @override
  Widget build(BuildContext context) {
    final color = widget.isOnline ? Colors.green : Colors.red;
    final label = widget.isOnline
        ? 'Online'
        : 'Offline — ${widget.offlineDaysRemaining} days left';

    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isOnline
                ? 'Connected to internet'
                : 'Offline — ${widget.offlineDaysRemaining} days remaining. Sales will sync when back online.'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConnectionStatusBanner extends StatefulWidget {
  @override
  State<ConnectionStatusBanner> createState() => _ConnectionStatusBannerState();
}

class _ConnectionStatusBannerState extends State<ConnectionStatusBanner> {
  bool _isOnline = true;
  int _offlineDays = 3;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    ConnectivityService.onConnectivityChanged.listen((online) {
      if (mounted) {
        setState(() => _isOnline = online);
        if (online) {
          setState(() => _offlineDays = 3);
        } else {
          OfflineAuthService.getOfflineDaysRemaining().then((days) {
            if (mounted) setState(() => _offlineDays = days);
          });
        }
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final online = await ConnectivityService.isOnline;
    if (mounted) {
      setState(() => _isOnline = online);
      if (!online) {
        final days = await OfflineAuthService.getOfflineDaysRemaining();
        if (mounted) setState(() => _offlineDays = days);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Text(
            'Offline — $_offlineDays days remaining. Sales will sync when back online.',
            style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
