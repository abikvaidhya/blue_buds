import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:convert/convert.dart';

/// Per-session X25519 + AES-GCM encryption.
/// New key pair every connection. Forward secrecy for the session.
class CryptoService {
  final _x25519 = X25519();
  final _aesGcm = AesGcm.with256bits();

  SimpleKeyPair? _myKeyPair;
  SecretKey? _sharedSecret;

  Future<void> generateKeyPair() async {
    _myKeyPair = await _x25519.newKeyPair();
    _sharedSecret = null;
  }

  Future<Uint8List> getPublicKeyBytes() async {
    if (_myKeyPair == null) await generateKeyPair();
    final pub = await _myKeyPair!.extractPublicKey();
    return Uint8List.fromList(pub.bytes);
  }

  /// After receiving peer's public key, derive the shared secret.
  Future<void> deriveSharedSecret(Uint8List peerPublicKeyBytes) async {
    if (_myKeyPair == null) await generateKeyPair();
    final peerPublic = SimplePublicKey(peerPublicKeyBytes, type: KeyPairType.x25519);
    _sharedSecret = await _x25519.sharedSecretKey(
      keyPair: _myKeyPair!,
      remotePublicKey: peerPublic,
    );
  }

  bool get hasSharedSecret => _sharedSecret != null;

  Future<Uint8List> encrypt(Uint8List plain) async {
    if (_sharedSecret == null) {
      throw StateError('No shared secret – call deriveSharedSecret first');
    }
    final secretBox = await _aesGcm.encrypt(plain, secretKey: _sharedSecret!);
    // nonce (12) + ciphertext + mac (16)
    final out = BytesBuilder();
    out.add(secretBox.nonce);
    out.add(secretBox.cipherText);
    out.add(secretBox.mac.bytes);
    return out.toBytes();
  }

  Future<Uint8List> decrypt(Uint8List sealed) async {
    if (_sharedSecret == null) {
      throw StateError('No shared secret');
    }
    if (sealed.length < 28) {
      throw ArgumentError('Ciphertext too short');
    }
    final nonce = sealed.sublist(0, 12);
    final mac = Mac(sealed.sublist(sealed.length - 16));
    final cipherText = sealed.sublist(12, sealed.length - 16);
    final box = SecretBox(cipherText, nonce: nonce, mac: mac);
    final clear = await _aesGcm.decrypt(box, secretKey: _sharedSecret!);
    return Uint8List.fromList(clear);
  }

  Future<String> encryptText(String text) async {
    final sealed = await encrypt(Uint8List.fromList(utf8.encode(text)));
    return base64Encode(sealed);
  }

  Future<String> decryptText(String b64) async {
    final sealed = base64Decode(b64);
    final clear = await decrypt(Uint8List.fromList(sealed));
    return utf8.decode(clear);
  }

  void clear() {
    _myKeyPair = null;
    _sharedSecret = null;
  }

  // Helpers for debugging
  static String toHex(Uint8List bytes) => hex.encode(bytes);
}
