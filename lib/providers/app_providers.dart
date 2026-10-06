import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/app_settings.dart';
import '../models/chat_message.dart';
import '../models/device_model.dart';
import '../services/ble_service.dart';
import '../services/crypto_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

// ── Core services ───────────────────────────────────────────
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('Override in main');
});

final cryptoServiceProvider = Provider<CryptoService>((ref) => CryptoService());

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final bleServiceProvider = Provider<BleService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final crypto = ref.watch(cryptoServiceProvider);
  final settings = ref.watch(settingsProvider);
  return BleService(
    crypto: crypto,
    localDeviceId: storage.localDeviceId,
    deviceName: settings.deviceName,
  );
});

// ── Settings ────────────────────────────────────────────────
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SettingsNotifier(storage);
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final StorageService _storage;

  SettingsNotifier(this._storage) : super(_storage.loadSettings());

  Future<void> update(AppSettings next) async {
    state = next;
    await _storage.saveSettings(next);
  }

  Future<void> setDeviceName(String name) async {
    await update(state.copyWith(
        deviceName: name.trim().isEmpty ? 'BlueBud' : name.trim()));
  }

  Future<void> setBackgroundScan(bool v) async {
    await update(state.copyWith(backgroundScanEnabled: v));
  }

  Future<void> setNotifyConnection(bool v) async {
    await update(state.copyWith(notifyConnectionRequests: v));
  }

  Future<void> setNotifySaved(bool v) async {
    await update(state.copyWith(notifySavedNearby: v));
  }

  Future<void> setAutoAcceptImages(bool v) async {
    await update(state.copyWith(autoAcceptImagesFromSaved: v));
  }

  Future<void> setRequireImagePermission(bool v) async {
    await update(state.copyWith(requireImagePermission: v));
  }
}

// ── Devices (saved + blocked) ───────────────────────────────
final savedDevicesProvider =
    StateNotifierProvider<SavedDevicesNotifier, List<SavedDevice>>((ref) {
  return SavedDevicesNotifier(ref.watch(storageServiceProvider));
});

class SavedDevicesNotifier extends StateNotifier<List<SavedDevice>> {
  final StorageService _storage;

  SavedDevicesNotifier(this._storage) : super(_storage.getSavedDevices());

  Future<void> save(NearbyPeer peer, {String? nickname}) async {
    final existing = _storage.getSaved(peer.id);
    final device = SavedDevice(
      id: peer.id,
      name: peer.name,
      firstSeen: existing?.firstSeen ?? DateTime.now(),
      lastSeen: DateTime.now(),
      autoAcceptImages: true,
      nickname: nickname ?? existing?.nickname,
    );
    await _storage.saveDevice(device);
    state = _storage.getSavedDevices();
  }

  Future<void> remove(String id) async {
    await _storage.removeSaved(id);
    state = _storage.getSavedDevices();
  }

  Future<void> updateNickname(String id, String nickname) async {
    final d = _storage.getSaved(id);
    if (d == null) return;
    d.nickname = nickname;
    await d.save();
    state = _storage.getSavedDevices();
  }
}

final blockedDevicesProvider =
    StateNotifierProvider<BlockedDevicesNotifier, List<BlockedDevice>>((ref) {
  return BlockedDevicesNotifier(ref.watch(storageServiceProvider));
});

class BlockedDevicesNotifier extends StateNotifier<List<BlockedDevice>> {
  final StorageService _storage;

  BlockedDevicesNotifier(this._storage) : super(_storage.getBlockedDevices());

  Future<void> block(NearbyPeer peer) async {
    await _storage.blockDevice(BlockedDevice(
      id: peer.id,
      name: peer.name,
      blockedAt: DateTime.now(),
    ));
    state = _storage.getBlockedDevices();
  }

  Future<void> unblock(String id) async {
    await _storage.unblock(id);
    state = _storage.getBlockedDevices();
  }
}

// ── Nearby peers (live from BLE) ────────────────────────────
final nearbyPeersProvider = StreamProvider<List<NearbyPeer>>((ref) {
  final ble = ref.watch(bleServiceProvider);
  return ble.peersStream;
});

// ── Active chat session ─────────────────────────────────────
final activeChatProvider =
    StateNotifierProvider<ActiveChatNotifier, ChatSession?>((ref) {
  return ActiveChatNotifier(ref);
});

class ActiveChatNotifier extends StateNotifier<ChatSession?> {
  final Ref _ref;

  ActiveChatNotifier(this._ref) : super(null);

  void startSession({
    required String peerId,
    required String peerName,
    required bool isSaved,
  }) {
    state = ChatSession(
      peerId: peerId,
      peerName: peerName,
      isSavedPeer: isSaved,
    );
  }

  void addMessage(ChatMessage msg) {
    if (state == null) return;
    state = state!.copyWith(messages: [...state!.messages, msg]);
  }

  void updateMessageStatus(String id, MessageStatus status) {
    if (state == null) return;
    final updated = state!.messages.map((m) {
      if (m.id == id) return m.copyWith(status: status);
      return m;
    }).toList();
    state = state!.copyWith(messages: updated);
  }

  void endSession() {
    // Clear messages as requested – ephemeral
    state = null;
  }

  Future<void> sendText(String text) async {
    if (state == null || text.trim().isEmpty) return;
    final ble = _ref.read(bleServiceProvider);
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final msg = ChatMessage(
      id: id,
      senderId: 'me',
      content: text.trim(),
      type: MessageType.text,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      isMine: true,
    );
    addMessage(msg);
    try {
      await ble.sendText(state!.peerId, text.trim());
      updateMessageStatus(id, MessageStatus.sent);
    } catch (_) {
      updateMessageStatus(id, MessageStatus.failed);
    }
  }
}
