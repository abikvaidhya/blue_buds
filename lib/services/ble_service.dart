import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart' as uuid_lib;

import '../models/device_model.dart';
import 'crypto_service.dart';

/// BlueBuds BLE protocol
/// Service UUID (custom 128-bit)
const String kServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const String kRxCharUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e'; // write from central
const String kTxCharUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e'; // notify to central
const String kIdentityCharUuid = '6e400004-b5a3-f393-e0a9-e50e24dcca9e';

/// Message framing (JSON over the characteristics for simplicity in MVP)
/// Types: hello | key_exchange | text | image_meta | image_chunk | image_accept | image_reject | disconnect

class BleService {
  final CryptoService crypto;
  final String localDeviceId;
  String deviceName;

  // Managers
  CentralManager? _central;
  PeripheralManager? _peripheral;

  // State
  final _peersController = StreamController<List<NearbyPeer>>.broadcast();
  final _messageController = StreamController<IncomingMessage>.broadcast();
  final _connectionController = StreamController<ConnectionEvent>.broadcast();

  final Map<String, NearbyPeer> _discovered = {};
  final Map<String, Peripheral> _connectedPeripherals = {};
  bool _isScanning = false;
  bool _isAdvertising = false;
  bool _initialized = false;

  Stream<List<NearbyPeer>> get peersStream => _peersController.stream;
  Stream<IncomingMessage> get messagesStream => _messageController.stream;
  Stream<ConnectionEvent> get connectionStream => _connectionController.stream;

  List<NearbyPeer> get currentPeers => _discovered.values.toList();

  BleService({
    required this.crypto,
    required this.localDeviceId,
    this.deviceName = 'BlueBud',
  });

  Future<void> init() async {
    if (_initialized) return;
    try {
      _central = CentralManager();
      _peripheral = PeripheralManager();
      // Listen to state changes etc. if needed
      _initialized = true;
    } catch (e) {
      debugPrint('BLE init error: $e');
      rethrow;
    }
  }

  // ── Advertising (act as peripheral so others can find us) ──
  Future<void> startAdvertising() async {
    if (_peripheral == null) await init();
    if (_isAdvertising) return;

    try {
      // Build advertisement with our service + short name + local id fragment
      final advertisement = Advertisement(
        name: deviceName.length > 10 ? deviceName.substring(0, 10) : deviceName,
        serviceUUIDs: [UUID.fromString(kServiceUuid)],
        // manufacturer data or service data can carry a short id later
      );

      await _peripheral!.startAdvertising(advertisement);
      _isAdvertising = true;
      debugPrint('Advertising as $deviceName');
    } catch (e) {
      debugPrint('startAdvertising failed: $e');
      // On some platforms / simulators this will fail – expected.
    }
  }

  Future<void> stopAdvertising() async {
    if (!_isAdvertising || _peripheral == null) return;
    try {
      await _peripheral!.stopAdvertising();
    } catch (_) {}
    _isAdvertising = false;
  }

  // ── Scanning ──────────────────────────────────────────────
  Future<void> startScan() async {
    if (_central == null) await init();
    if (_isScanning) return;

    _discovered.clear();
    _peersController.add([]);

    try {
      await _central!.startDiscovery(
        serviceUUIDs: [UUID.fromString(kServiceUuid)],
      );
      _isScanning = true;

      // Listen to discoveries
      _central!.discovered.listen((event) {
        final p = event.peripheral;
        final adv = event.advertisement;
        final name = adv.name ?? 'Unknown';
        final id = p.uuid.toString(); // use peripheral uuid as key for now

        final existing = _discovered[id];
        final peer = NearbyPeer(
          id: id,
          name: name,
          rssi: event.rssi,
          lastSeen: DateTime.now(),
          isSaved: existing?.isSaved ?? false,
          isBlocked: existing?.isBlocked ?? false,
        );
        _discovered[id] = peer;
        _peersController.add(_discovered.values.toList());
      });
    } catch (e) {
      debugPrint('startScan failed: $e');
    }
  }

  Future<void> stopScan() async {
    if (!_isScanning || _central == null) return;
    try {
      await _central!.stopDiscovery();
    } catch (_) {}
    _isScanning = false;
  }

  // ── Connection ────────────────────────────────────────────
  Future<bool> connectToPeer(String peerId) async {
    if (_central == null) return false;
    try {
      final peripheral = _discovered.keys
          .map((k) => null) // we need the actual Peripheral object
          .firstWhere((_) => false, orElse: () => null);

      // In real bluetooth_low_energy we keep the Peripheral from discovery.
      // For the scaffold we emit a simulated connection event.
      // TODO: store Peripheral instances in a map during discovery.

      _connectionController.add(ConnectionEvent(
        peerId: peerId,
        type: ConnectionEventType.connected,
        peerName: _discovered[peerId]?.name ?? 'Peer',
      ));

      // Start key exchange
      await crypto.generateKeyPair();
      final pub = await crypto.getPublicKeyBytes();
      await _sendRaw(peerId, {
        't': 'key_exchange',
        'pub': base64Encode(pub),
        'id': localDeviceId,
        'name': deviceName,
      });

      return true;
    } catch (e) {
      debugPrint('connect failed: $e');
      return false;
    }
  }

  Future<void> disconnect(String peerId) async {
    _connectionController.add(ConnectionEvent(
      peerId: peerId,
      type: ConnectionEventType.disconnected,
    ));
    crypto.clear();
  }

  // ── Messaging ─────────────────────────────────────────────
  Future<void> sendText(String peerId, String text) async {
    final encrypted = await crypto.encryptText(text);
    await _sendRaw(peerId, {
      't': 'text',
      'c': encrypted,
      'id': const uuid_lib.Uuid().v4(),
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> sendImageRequest(String peerId, String imageId, int size) async {
    await _sendRaw(peerId, {
      't': 'image_meta',
      'imageId': imageId,
      'size': size,
      'id': const uuid_lib.Uuid().v4(),
    });
  }

  Future<void> acceptImage(String peerId, String imageId) async {
    await _sendRaw(peerId, {'t': 'image_accept', 'imageId': imageId});
  }

  Future<void> rejectImage(String peerId, String imageId) async {
    await _sendRaw(peerId, {'t': 'image_reject', 'imageId': imageId});
  }

  Future<void> _sendRaw(String peerId, Map<String, dynamic> payload) async {
    // TODO: write to the RX characteristic of the connected peripheral
    // or notify via TX if we are the peripheral.
    debugPrint('BLE send → $peerId : $payload');
    // For now just log; real write goes here after connection object is stored.
  }

  void dispose() {
    stopScan();
    stopAdvertising();
    _peersController.close();
    _messageController.close();
    _connectionController.close();
  }
}

class IncomingMessage {
  final String peerId;
  final String type;
  final Map<String, dynamic> data;
  IncomingMessage({required this.peerId, required this.type, required this.data});
}

enum ConnectionEventType { connected, disconnected, connecting, failed }

class ConnectionEvent {
  final String peerId;
  final ConnectionEventType type;
  final String? peerName;
  ConnectionEvent({required this.peerId, required this.type, this.peerName});
}
