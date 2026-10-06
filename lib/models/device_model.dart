import 'package:hive/hive.dart';

part 'device_model.g.dart';

@HiveType(typeId: 0)
class SavedDevice extends HiveObject {
  @HiveField(0)
  final String id; // persistent opaque UUID we assign / receive

  @HiveField(1)
  String name; // last known broadcast name or user nickname

  @HiveField(2)
  final DateTime firstSeen;

  @HiveField(3)
  DateTime lastSeen;

  @HiveField(4)
  bool autoAcceptImages;

  @HiveField(5)
  String? nickname; // user-set friendly name

  SavedDevice({
    required this.id,
    required this.name,
    required this.firstSeen,
    required this.lastSeen,
    this.autoAcceptImages = true,
    this.nickname,
  });

  String get displayName => nickname?.isNotEmpty == true ? nickname! : name;
}

@HiveType(typeId: 1)
class BlockedDevice extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final DateTime blockedAt;

  BlockedDevice({
    required this.id,
    required this.name,
    required this.blockedAt,
  });
}

/// Runtime-only peer discovered via BLE (not persisted unless saved)
class NearbyPeer {
  final String id;
  final String name;
  final int rssi;
  final DateTime lastSeen;
  final bool isSaved;
  final bool isBlocked;

  NearbyPeer({
    required this.id,
    required this.name,
    required this.rssi,
    required this.lastSeen,
    this.isSaved = false,
    this.isBlocked = false,
  });

  NearbyPeer copyWith({
    String? name,
    int? rssi,
    DateTime? lastSeen,
    bool? isSaved,
    bool? isBlocked,
  }) {
    return NearbyPeer(
      id: id,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      lastSeen: lastSeen ?? this.lastSeen,
      isSaved: isSaved ?? this.isSaved,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }

  /// Rough distance estimate from RSSI (very approximate)
  String get distanceLabel {
    if (rssi >= -50) return 'Very close';
    if (rssi >= -65) return 'Close';
    if (rssi >= -80) return 'Nearby';
    return 'Far';
  }
}
