import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _authService = AuthService();
  String? _userId;
  List<dynamic> _conversations = [];
  bool _isLoading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = await _authService.getCurrentUser();
    if (user == null) return;
    _userId = user.id;

    try {
      final result = await ChatService.getConversations(user.id);
      if (mounted) {
        setState(() {
          _conversations = result['conversations'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load conversations: $e')),
        );
      }
    }
  }

  Future<void> _refresh() async {
    if (_userId == null) return;
    try {
      final result = await ChatService.getConversations(_userId!);
      if (mounted) {
        setState(() => _conversations = result['conversations'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _deleteConversation(String conversationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text('Are you sure you want to delete this conversation? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || _userId == null) return;

    await ChatService.deleteConversation(_userId!, conversationId);
    _refresh();
  }

  String _formatTime(String isoStr) {
    try {
      final dt = DateTime.parse(isoStr + 'Z');
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text('No conversations yet', style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      const Text(
                        'Customers can start a chat from your online shop',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final conv = _conversations[index];
                      final unread = conv['unread_count'] ?? 0;
                      final lastMsg = conv['last_message'] ?? '';
                      final lastType = conv['last_message_type'] ?? 'text';

                      return Dismissible(
                        key: Key(conv['conversation_id']),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          await _deleteConversation(conv['conversation_id']);
                          return true;
                        },
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: unread > 0
                                ? AppTheme.primaryColor
                                : Colors.grey.shade300,
                            child: Text(
                              (conv['customer_name'] ?? '?')[0].toUpperCase(),
                              style: TextStyle(
                                color: unread > 0 ? Colors.white : Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  conv['customer_name'] ?? 'Unknown',
                                  style: TextStyle(
                                    fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              Text(
                                _formatTime(conv['last_message_time'] ?? ''),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Row(
                            children: [
                              if (lastType == 'image')
                                const Icon(Icons.image, size: 14, color: AppTheme.textSecondary),
                              if (lastType == 'image') const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  lastType == 'image' ? 'Image' : lastMsg,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: unread > 0 ? AppTheme.textPrimary : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              if (unread > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$unread',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatDetailScreen(
                                  conversationId: conv['conversation_id'],
                                  customerName: conv['customer_name'] ?? 'Customer',
                                  customerPhone: conv['customer_phone'] ?? '',
                                ),
                              ),
                            ).then((_) => _refresh());
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
