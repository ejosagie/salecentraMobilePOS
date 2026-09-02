import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';

class ChatDetailScreen extends StatefulWidget {
  final String conversationId;
  final String customerName;
  final String customerPhone;

  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    required this.customerName,
    required this.customerPhone,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _authService = AuthService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();

  String? _userId;
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final user = await _authService.getCurrentUser();
    if (user != null) {
      _userId = user.id;
      _loadMessages();
      _markRead();
      _startPolling();
    }
  }

  Future<void> _loadMessages() async {
    if (_userId == null) return;
    try {
      final result = await ChatService.getMessages(widget.conversationId, _userId);
      if (mounted) {
        setState(() {
          _messages = result['messages'] ?? [];
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markRead() async {
    if (_userId == null) return;
    await ChatService.markRead(_userId!, widget.conversationId);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadMessages();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty || _userId == null || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await ChatService.sendReply(
        userId: _userId!,
        conversationId: widget.conversationId,
        message: msg,
      );
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_userId == null || _isSending) return;
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;

      setState(() => _isSending = true);
      final imageUrl = await ChatService.uploadMedia(_userId!, widget.conversationId, File(picked.path));
      if (imageUrl != null) {
        await ChatService.sendReply(
          userId: _userId!,
          conversationId: widget.conversationId,
          message: '',
          messageType: 'image',
          imageUrl: imageUrl,
        );
        await _loadMessages();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _markUnread() async {
    if (_userId == null) return;
    await ChatService.markUnread(_userId!, widget.conversationId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as unread'), duration: Duration(seconds: 1)),
      );
    }
  }

  String _formatTime(String isoStr) {
    try {
      final dt = DateTime.parse(isoStr + 'Z');
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.customerPhone, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'unread') _markUnread();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'unread', child: Text('Mark as Unread')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('No messages yet', style: TextStyle(color: AppTheme.textSecondary)),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMerchant = msg['sender'] == 'merchant';
                          final isImage = msg['message_type'] == 'image';

                          return Align(
                            alignment: isMerchant ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: isMerchant ? AppTheme.primaryColor : Colors.grey.shade100,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isMerchant ? const Radius.circular(16) : const Radius.circular(4),
                                  bottomRight: isMerchant ? const Radius.circular(4) : const Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isImage && msg['image_url'] != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        msg['image_url'],
                                        width: 180,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, progress) {
                                          if (progress == null) return child;
                                          return const SizedBox(
                                            width: 180,
                                            height: 120,
                                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                          );
                                        },
                                      ),
                                    )
                                  else
                                    Text(
                                      msg['message'] ?? '',
                                      style: TextStyle(
                                        color: isMerchant ? Colors.white : AppTheme.textPrimary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(msg['created_at'] ?? ''),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMerchant ? Colors.white70 : AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // Input bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: AppTheme.textSecondary),
                  onPressed: _isSending ? null : _pickAndSendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
