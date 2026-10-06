import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/device_model.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final NearbyPeer peer;

  const ChatScreen({super.key, required this.peer});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _secureFlagSet = false;

  @override
  void initState() {
    super.initState();
    // Attempt screenshot prevention (Android FLAG_SECURE)
    _setSecureFlag(true);
  }

  @override
  void dispose() {
    _setSecureFlag(false);
    _controller.dispose();
    _scroll.dispose();
    // Clear session when leaving
    ref.read(activeChatProvider.notifier).endSession();
    ref.read(bleServiceProvider).disconnect(widget.peer.id);
    super.dispose();
  }

  Future<void> _setSecureFlag(bool enable) async {
    // Platform channel stub – implement native side later
    try {
      // MethodChannel('blue_buds/secure').invokeMethod('setSecure', enable);
      _secureFlagSet = enable;
    } catch (_) {}
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    ref.read(activeChatProvider.notifier).sendText(text);
    _controller.clear();
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 70,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final imageId = const Uuid().v4();
    final session = ref.read(activeChatProvider);
    if (session == null) return;

    // Add local preview message
    ref.read(activeChatProvider.notifier).addMessage(ChatMessage(
          id: imageId,
          senderId: 'me',
          content: 'Image (${(bytes.length / 1024).toStringAsFixed(0)} KB)',
          type: MessageType.image,
          timestamp: DateTime.now(),
          status: MessageStatus.sending,
          imageBytes: bytes,
          isMine: true,
        ));

    // Send request to peer (they must accept unless saved + auto)
    await ref.read(bleServiceProvider).sendImageRequest(
          widget.peer.id,
          imageId,
          bytes.length,
        );
    // Real chunked transfer would follow after accept
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _savePeer() async {
    await ref.read(savedDevicesProvider.notifier).save(widget.peer);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device saved for future chats')),
      );
    }
  }

  Future<void> _blockPeer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block this device?'),
        content: const Text(
          'You will no longer see or receive messages from this device.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(blockedDevicesProvider.notifier).block(widget.peer);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeChatProvider);
    final messages = session?.messages ?? [];
    final isSaved = ref.watch(savedDevicesProvider).any((s) => s.id == widget.peer.id);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.peer.name),
            Text(
              session?.connected == true ? 'Connected • Ephemeral' : 'Disconnected',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          if (!isSaved)
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined),
              tooltip: 'Save device',
              onPressed: _savePeer,
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'block') _blockPeer();
              if (v == 'save') _savePeer();
            },
            itemBuilder: (_) => [
              if (!isSaved)
                const PopupMenuItem(value: 'save', child: Text('Save device')),
              const PopupMenuItem(
                value: 'block',
                child: Text('Block', style: TextStyle(color: AppTheme.danger)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Security banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.surfaceLight,
            child: Row(
              children: [
                Icon(Icons.lock_rounded, size: 14, color: AppTheme.primary.withOpacity(0.8)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Messages are end-to-end encrypted & deleted when you leave',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 48, color: AppTheme.textSecondary.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        const Text(
                          'Say hi — this chat vanishes when you disconnect',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: messages.length,
                    itemBuilder: (context, i) => _Bubble(message: messages[i]),
                  ),
          ),
          _InputBar(
            controller: _controller,
            onSend: _send,
            onImage: _pickImage,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? AppTheme.primary.withOpacity(0.2) : AppTheme.surfaceLight,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          border: isMine
              ? Border.all(color: AppTheme.primary.withOpacity(0.3))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.type == MessageType.image && message.imageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  message.imageBytes!,
                  width: 200,
                  fit: BoxFit.cover,
                ),
              )
            else if (message.type == MessageType.image)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.image_rounded, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(message.content),
                ],
              )
            else
              Text(
                message.content,
                style: const TextStyle(fontSize: 15, height: 1.35),
              ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onImage;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onImage,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.image_outlined, color: AppTheme.primary),
              onPressed: onImage,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Message…',
                  isDense: true,
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onSend,
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.send_rounded, color: Colors.black, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
