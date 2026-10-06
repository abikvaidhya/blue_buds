import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/app_settings.dart';
import '../models/device_model.dart';

class StorageService {
  static const _savedBox = 'saved_devices';
  static const _blockedBox = 'blocked_devices';
  static const _prefsKey = 'app_settings';
  static const _localIdKey = 'local_device_id';

  late Box<SavedDevice> _saved;
  late Box<BlockedDevice> _blocked;
  late SharedPreferences _prefs;

  String? _localId;

  Future<void> init() async {
    await Hive.initFlutter();
    // Register adapters after running build_runner
    // For now we use typeId manually; generate with:
    // flutter pub run build_runner build
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SavedDeviceAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(BlockedDeviceAdapter());
    }

    _saved = await Hive.openBox<SavedDevice>(_savedBox);
    _blocked = await Hive.openBox<BlockedDevice>(_blockedBox);
    _prefs = await SharedPreferences.getInstance();

    _localId = _prefs.getString(_localIdKey);
    if (_localId == null) {
      _localId = const Uuid().v4();
      await _prefs.setString(_localIdKey, _localId!);
    }
  }

  String get localDeviceId => _localId!;

  // ── Settings ──────────────────────────────────────────────
  AppSettings loadSettings() {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null) return const AppSettings();
    try {
      // simple json-like via shared_preferences map
      final map = <String, dynamic>{};
      // We store as individual keys for simplicity
      return AppSettings(
        deviceName: _prefs.getString('deviceName') ?? 'BlueBud',
        backgroundScanEnabled: _prefs.getBool('backgroundScanEnabled') ?? false,
        notifyConnectionRequests:
            _prefs.getBool('notifyConnectionRequests') ?? true,
        notifySavedNearby: _prefs.getBool('notifySavedNearby') ?? true,
        autoAcceptImagesFromSaved:
            _prefs.getBool('autoAcceptImagesFromSaved') ?? true,
        requireImagePermission:
            _prefs.getBool('requireImagePermission') ?? true,
      );
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings s) async {
    await _prefs.setString('deviceName', s.deviceName);
    await _prefs.setBool('backgroundScanEnabled', s.backgroundScanEnabled);
    await _prefs.setBool('notifyConnectionRequests', s.notifyConnectionRequests);
    await _prefs.setBool('notifySavedNearby', s.notifySavedNearby);
    await _prefs.setBool(
        'autoAcceptImagesFromSaved', s.autoAcceptImagesFromSaved);
    await _prefs.setBool('requireImagePermission', s.requireImagePermission);
  }

  // ── Saved devices ─────────────────────────────────────────
  List<SavedDevice> getSavedDevices() => _saved.values.toList()
    ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

  Future<void> saveDevice(SavedDevice device) async {
    await _saved.put(device.id, device);
  }

  Future<void> removeSaved(String id) async {
    await _saved.delete(id);
  }

  SavedDevice? getSaved(String id) => _saved.get(id);

  bool isSaved(String id) => _saved.containsKey(id);

  // ── Blocked ───────────────────────────────────────────────
  List<BlockedDevice> getBlockedDevices() => _blocked.values.toList()
    ..sort((a, b) => b.blockedAt.compareTo(a.blockedAt));

  Future<void> blockDevice(BlockedDevice device) async {
    await _blocked.put(device.id, device);
    // also remove from saved if present
    await _saved.delete(device.id);
  }

  Future<void> unblock(String id) async {
    await _blocked.delete(id);
  }

  bool isBlocked(String id) => _blocked.containsKey(id);
}

// Temporary manual adapters until build_runner is run.
// After `dart run build_runner build` these can be removed and the .g.dart used.

class SavedDeviceAdapter extends TypeAdapter<SavedDevice> {
  @override
  final int typeId = 0;

  @override
  SavedDevice read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedDevice(
      id: fields[0] as String,
      name: fields[1] as String,
      firstSeen: fields[2] as DateTime,
      lastSeen: fields[3] as DateTime,
      autoAcceptImages: fields[4] as bool? ?? true,
      nickname: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SavedDevice obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.firstSeen)
      ..writeByte(3)
      ..write(obj.lastSeen)
      ..writeByte(4)
      ..write(obj.autoAcceptImages)
      ..writeByte(5)
      ..write(obj.nickname);
  }
}

class BlockedDeviceAdapter extends TypeAdapter<BlockedDevice> {
  @override
  final int typeId = 1;

  @override
  BlockedDevice read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BlockedDevice(
      id: fields[0] as String,
      name: fields[1] as String,
      blockedAt: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, BlockedDevice obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.blockedAt);
  }
}
