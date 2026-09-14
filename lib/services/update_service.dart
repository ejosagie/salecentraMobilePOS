import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import '../utils/theme.dart';

class UpdateService {
  static const _appId = 'salecentra_pos';

  static Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final platform = Platform.isIOS ? 'ios' : 'android';
      final response = await ApiService.get('/app-update/check', params: {
        'app_id': _appId,
        'platform': platform,
        'version': info.version,
        'build_number': info.buildNumber,
      });
      if (response['success'] == true && response['update_available'] == true) {
        return response;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> showUpdateDialogIfNeeded(BuildContext context) async {
    final updateInfo = await checkForUpdate();
    if (updateInfo == null || !context.mounted) return true;

    final forceUpdate = updateInfo['force_update'] == true;
    final message = updateInfo['update_message'] ?? 'A new version is available.';
    final storeUrl = updateInfo['store_url'] as String? ?? '';
    final latestVersion = updateInfo['latest_version'] ?? '';

    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.system_update, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text('Update Available'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (latestVersion.isNotEmpty)
              Text('Version $latestVersion is available.',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message),
            if (forceUpdate) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: AppTheme.error, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This update is required to continue using the app.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              if (storeUrl.isNotEmpty) {
                await launchUrl(Uri.parse(storeUrl));
              } else {
                await launchUrl(Uri.parse('https://mysalecentra.com/downloads/salecentra-pos.apk'));
              }
              if (!forceUpdate && context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );

    return !forceUpdate;
  }
}
