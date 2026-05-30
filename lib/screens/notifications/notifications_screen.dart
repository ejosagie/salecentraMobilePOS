import 'package:flutter/material.dart';
import '../../models/notification.dart';
import '../../services/auth_service.dart';
import '../../services/remote_database_service.dart';
import '../../utils/theme.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _dbService = RemoteDatabaseService();
  final _authService = AuthService();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        setState(() {
          _isLoading = false;
          _error = 'Not logged in';
        });
        return;
      }
      final notifications = await _dbService.getNotifications(user.id);
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error: $e';
        });
      }
    }
  }

  Future<void> _markRead(AppNotification notification, int index) async {
    if (notification.isRead) return;
    try {
      await _dbService.markNotificationRead(notification.id);
      setState(() {
        _notifications[index] = AppNotification(
          id: notification.id,
          userId: notification.userId,
          title: notification.title,
          body: notification.body,
          type: notification.type,
          isRead: true,
          createdAt: notification.createdAt,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as read: $e')),
        );
      }
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'sale':
        return Icons.point_of_sale_outlined;
      case 'customer':
        return Icons.person_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'sale':
        return AppTheme.success;
      case 'customer':
        return AppTheme.primaryColor;
      default:
        return AppTheme.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: AppTheme.error.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: AppTheme.error)),
                    ],
                  ),
                )
              : _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none_outlined,
                            size: 80,
                            color: AppTheme.textMuted.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications yet',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final n = _notifications[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: n.isRead ? null : AppTheme.primaryColor.withOpacity(0.03),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _colorForType(n.type).withOpacity(0.1),
                                child: Icon(
                                  _iconForType(n.type),
                                  color: _colorForType(n.type),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                n.title,
                                style: TextStyle(
                                  fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (n.body != null && n.body!.isNotEmpty)
                                    Text(n.body!, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MMM d, h:mm a').format(n.createdAt),
                                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                              isThreeLine: n.body != null && n.body!.isNotEmpty,
                              trailing: n.isRead
                                  ? null
                                  : Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                              onTap: () => _markRead(n, index),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
