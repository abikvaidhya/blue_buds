import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_model.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/radar_painter.dart';
import 'chat_screen.dart';
import 'devices_screen.dart';
import 'settings_screen.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  bool _scanning = false;
  bool _advertising = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startBle());
  }

  Future<void> _startBle() async {
    final ble = ref.read(bleServiceProvider);
    try {
      await ble.init();
      await ble.startAdvertising();
      await ble.startScan();
      setState(() {
        _scanning = true;
        _advertising = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bluetooth error: $e')),
        );
      }
    }
  }

  Future<void> _toggleScan() async {
    final ble = ref.read(bleServiceProvider);
    if (_scanning) {
      await ble.stopScan();
      setState(() => _scanning = false);
    } else {
      await ble.startScan();
      setState(() => _scanning = true);
    }
  }

  void _openChat(NearbyPeer peer) {
    final isSaved = ref.read(storageServiceProvider).isSaved(peer.id);
    ref.read(activeChatProvider.notifier).startSession(
          peerId: peer.id,
          peerName: peer.name,
          isSaved: isSaved,
        );
    // Also try connect
    ref.read(bleServiceProvider).connectToPeer(peer.id);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(peer: peer)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final peersAsync = ref.watch(nearbyPeersProvider);
    final settings = ref.watch(settingsProvider);
    final saved = ref.watch(savedDevicesProvider);

    final List<NearbyPeer> peers = peersAsync.whenOrNull() ?? <NearbyPeer>[];
    final List<NearbyPeer> enriched = peers
        .map((p) {
          final isSaved = saved.any((s) => s.id == p.id);
          final isBlocked = ref.read(storageServiceProvider).isBlocked(p.id);
          return p.copyWith(isSaved: isSaved, isBlocked: isBlocked);
        })
        .where((p) => !p.isBlocked)
        .toList();

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Full-screen radar
            Positioned.fill(
              child: AnimatedRadar(
                peers: enriched,
                isScanning: _scanning,
              ),
            ),

            // Top bar
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    color: AppTheme.textPrimary,
                    onPressed: () => _showMenu(context),
                  ),
                  const Spacer(),
                  Column(
                    children: [
                      Text(
                        'BlueBuds',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.primary,
                              letterSpacing: 1.2,
                            ),
                      ),
                      Text(
                        settings.deviceName,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _scanning ? Icons.radar : Icons.radar_outlined,
                      color:
                          _scanning ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                    onPressed: _toggleScan,
                  ),
                ],
              ),
            ),

            // Bottom peer list sheet
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _PeerSheet(
                peers: enriched,
                onTap: _openChat,
                scanning: _scanning,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.devices_rounded),
                title: const Text('Saved & Blocked'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DevicesScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _PeerSheet extends StatelessWidget {
  final List<NearbyPeer> peers;
  final void Function(NearbyPeer) onTap;
  final bool scanning;

  const _PeerSheet({
    required this.peers,
    required this.onTap,
    required this.scanning,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.38,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  scanning ? 'Searching nearby…' : 'Scan paused',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  '${peers.length} found',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (peers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.bluetooth_searching_rounded,
                    size: 48,
                    color: AppTheme.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No BlueBuds nearby yet.\nKeep the app open to find them.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: peers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final p = peers[i];
                  return _PeerTile(peer: p, onTap: () => onTap(p))
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.1, end: 0);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PeerTile extends StatelessWidget {
  final NearbyPeer peer;
  final VoidCallback onTap;

  const _PeerTile({required this.peer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceLight,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: peer.isSaved
                        ? [AppTheme.success, AppTheme.primary]
                        : [AppTheme.primary, AppTheme.secondary],
                  ),
                ),
                child: Center(
                  child: Text(
                    peer.name.isNotEmpty ? peer.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            peer.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (peer.isSaved) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.bookmark_rounded,
                              size: 16, color: AppTheme.success),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${peer.distanceLabel}  •  ${peer.rssi} dBm',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chat_bubble_outline_rounded,
                  color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
