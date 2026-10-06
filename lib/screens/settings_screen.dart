import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameCtrl;
  String version = '1.0.0';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: ref.read(settingsProvider).deviceName,
    );
    getVersion();
  }

  Future<void> getVersion() async {
    PackageInfo info = await PackageInfo.fromPlatform();
    version = '${info.version}+${info.buildNumber}';
    setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader('Identity'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Broadcast name',
                helperText:
                    'Visible to nearby devices (max ~12 chars recommended)',
              ),
              maxLength: 12,
              onChanged: (v) => notifier.setDeviceName(v),
            ),
          ),
          const Divider(height: 32),
          _SectionHeader('Scanning'),
          SwitchListTile(
            title: const Text('Background search'),
            subtitle: const Text(
              'Look for devices while app is in background, uses more battery (not recommended)',
            ),
            value: settings.backgroundScanEnabled,
            onChanged: notifier.setBackgroundScan,
          ),
          const Divider(height: 32),
          _SectionHeader('Notifications'),
          SwitchListTile(
            title: const Text('Connection requests'),
            subtitle: const Text('Notify when someone wants to chat'),
            value: settings.notifyConnectionRequests,
            onChanged: notifier.setNotifyConnection,
          ),
          SwitchListTile(
            title: const Text('Saved devices nearby'),
            subtitle: const Text('Notify when a saved device comes into range'),
            value: settings.notifySavedNearby,
            onChanged: notifier.setNotifySaved,
          ),
          const Divider(height: 32),
          _SectionHeader('Images'),
          SwitchListTile(
            title: const Text('Ask permission to receive images'),
            subtitle: const Text(
              'The app prompts for permission to receive images before it is shown (recommended)',
            ),
            value: settings.requireImagePermission,
            onChanged: notifier.setRequireImagePermission,
          ),
          SwitchListTile(
            title: const Text('Auto-accept from saved devices'),
            subtitle: const Text(
              'Saved devices can send images without asking each time',
            ),
            value: settings.autoAcceptImagesFromSaved,
            onChanged: notifier.setAutoAcceptImages,
          ),
          const Divider(height: 32),
          _SectionHeader('About'),
          ListTile(
            title: Text('Version'),
            trailing:
                Text(version, style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ListTile(
            title: const Text('Privacy'),
            subtitle: const Text(
              'No accounts • No servers • Messages never leave your device unencrypted',
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Privacy first'),
                  content: const Text(
                    'BlueBuds works completely offline over Bluetooth Low Energy.\n\n'
                    '• No sign-up or phone number\n'
                    '• No cloud, no analytics\n'
                    '• End-to-end encrypted sessions\n'
                    '• Chat history is wiped when the connection drops\n'
                    '• Screenshot protection is applied on Android (best-effort on iOS)',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
