import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_model.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedDevicesProvider);
    final blocked = ref.watch(blockedDevicesProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Devices'),
          bottom: const TabBar(
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: [
              Tab(text: 'Saved'),
              Tab(text: 'Blocked'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SavedList(saved: saved),
            _BlockedList(blocked: blocked),
          ],
        ),
      ),
    );
  }
}

class _SavedList extends ConsumerWidget {
  final List<SavedDevice> saved;
  const _SavedList({required this.saved});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (saved.isEmpty) {
      return const _EmptyState(
        icon: Icons.bookmark_border_rounded,
        message:
            'No saved devices yet.\nSave someone from a chat to find them easily later.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: saved.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) {
        final d = saved[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.success.withOpacity(0.2),
            child: Text(
              d.displayName[0].toUpperCase(),
              style: const TextStyle(
                  color: AppTheme.success, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(d.displayName),
          subtitle: Text(
            'Last seen ${_relative(d.lastSeen)}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppTheme.danger),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Remove saved device?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Remove',
                          style: TextStyle(color: AppTheme.danger)),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                ref.read(savedDevicesProvider.notifier).remove(d.id);
              }
            },
          ),
          onTap: () => _editNickname(context, ref, d),
        );
      },
    );
  }

  void _editNickname(BuildContext context, WidgetRef ref, SavedDevice d) {
    final ctrl = TextEditingController(text: d.nickname ?? d.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nickname'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Friendly name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref
                  .read(savedDevicesProvider.notifier)
                  .updateNickname(d.id, ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _BlockedList extends ConsumerWidget {
  final List<BlockedDevice> blocked;
  const _BlockedList({required this.blocked});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (blocked.isEmpty) {
      return const _EmptyState(
        icon: Icons.block_rounded,
        message: 'No blocked devices.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: blocked.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) {
        final d = blocked[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.danger.withOpacity(0.2),
            child: Text(
              d.name.isNotEmpty ? d.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: AppTheme.danger, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(d.name),
          subtitle: Text(
            'Blocked ${_relative(d.blockedAt)}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          trailing: TextButton(
            onPressed: () =>
                ref.read(blockedDevicesProvider.notifier).unblock(d.id),
            child: const Text('Unblock'),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppTheme.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

String _relative(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${t.day}/${t.month}/${t.year}';
}
