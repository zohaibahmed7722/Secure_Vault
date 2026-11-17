import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'crypto_utils.dart';

class DecryptionException implements Exception {
  final String message;
  DecryptionException(this.message);
  @override
  String toString() => 'DecryptionException: $message';
}

class EncryptedEnvelope {
  final Uint8List cipherText;
  final Uint8List nonce;
  final Uint8List macTag;
  final Uint8List aad;

  const EncryptedEnvelope({
    required this.cipherText,
    required this.nonce,
    required this.macTag,
    required this.aad,
  });

  Map<String, dynamic> toJson() => {
    'cipherText': CryptoUtils.toBase64(cipherText),
    'nonce': CryptoUtils.toBase64(nonce),
    'macTag': CryptoUtils.toBase64(macTag),
    'aad': CryptoUtils.toBase64(aad),
  };

  factory EncryptedEnvelope.fromJson(Map<String, dynamic> json) {
    return EncryptedEnvelope(
      cipherText: CryptoUtils.fromBase64(json['cipherText'] as String),
      nonce: CryptoUtils.fromBase64(json['nonce'] as String),
      macTag: CryptoUtils.fromBase64(json['macTag'] as String),
      aad: CryptoUtils.fromBase64(json['aad'] as String? ?? ''),
    );
  }
}

class CipherService {
  final AesGcm _aesGcm = AesGcm.with256bits();

  Future<EncryptedEnvelope> encrypt({
    required Uint8List plaintext,
    required List<int> secretKeyBytes,
    List<int>? additionalAuthenticatedData,
  }) async {
    if (secretKeyBytes.length != 32) {
      throw ArgumentError('SecretKey must be exactly 32 bytes (256 bits)');
    }

    final secretKey = SecretKey(secretKeyBytes);
    final nonce = CryptoUtils.randomBytes(12);
    final aad = additionalAuthenticatedData ?? const <int>[];

    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
      aad: aad,
    );

    return EncryptedEnvelope(
      cipherText: Uint8List.fromList(secretBox.cipherText),
      nonce: Uint8List.fromList(secretBox.nonce),
      macTag: Uint8List.fromList(secretBox.mac.bytes),
      aad: Uint8List.fromList(aad),
    );
  }

  Future<Uint8List> decrypt({
    required EncryptedEnvelope envelope,
    required List<int> secretKeyBytes,
  }) async {
    if (secretKeyBytes.length != 32) {
      throw ArgumentError('SecretKey must be exactly 32 bytes (256 bits)');
    }

    final secretKey = SecretKey(secretKeyBytes);
    final secretBox = SecretBox(
      envelope.cipherText,
      nonce: envelope.nonce,
      mac: Mac(envelope.macTag),
    );

    try {
      final decrypted = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
        aad: envelope.aad,
      );
      return Uint8List.fromList(decrypted);
    } catch (e) {
      throw DecryptionException(
        'Decryption failed: integrity verification rejected the ciphertext.',
      );
    }
  }
}