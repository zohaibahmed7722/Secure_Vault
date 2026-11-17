import 'dart:typed_data';
import 'cipher_service.dart';
import 'crypto_utils.dart';

class RecoveryManager {
  final CipherService _cipherService = CipherService();

  Uint8List generateRecoveryKey() {
    return CryptoUtils.randomBytes(32);
  }

  String formatRecoveryKey(Uint8List key) {
    final hexString = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
    final chunks = <String>[];
    for (int i = 0; i < hexString.length; i += 8) {
      chunks.add(hexString.substring(i, i + 8));
    }
    return chunks.join('-');
  }

  Uint8List parseRecoveryKey(String formatted) {
    final cleaned = formatted.replaceAll('-', '').replaceAll(' ', '').trim().toLowerCase();
    if (cleaned.length != 64) {
      throw const FormatException('Invalid key length. Must be 64 hexadecimal characters.');
    }
    final bytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      final byteHex = cleaned.substring(i * 2, i * 2 + 2);
      bytes[i] = int.parse(byteHex, radix: 16);
    }
    return bytes;
  }

  Future<EncryptedEnvelope> wrapMasterKey({
    required Uint8List masterKey,
    required Uint8List recoveryKey,
  }) async {
    return await _cipherService.encrypt(
      plaintext: masterKey,
      secretKeyBytes: recoveryKey,
      additionalAuthenticatedData: CryptoUtils.utf8Encode('recovery-key-wrap-v1'),
    );
  }

  Future<Uint8List> unwrapMasterKey({
    required EncryptedEnvelope wrappedEnvelope,
    required Uint8List recoveryKey,
  }) async {
    return await _cipherService.decrypt(
      envelope: wrappedEnvelope,
      secretKeyBytes: recoveryKey,
    );
  }
}