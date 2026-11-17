import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'crypto_utils.dart';

class KeyHierarchy {
  final Argon2id _argon2id;

  final Hkdf _hkdf = Hkdf(
    hmac: Hmac.sha256(),
    outputLength: 32,
  );

  /// Default parameters are balanced for mobile Dart runtime (16MB memory, 2 iterations, 1 lane)
  /// to prevent UI jank/ANRs while maintaining high offline resistance.
  KeyHierarchy({
    int memory = 16 * 1024, // 16 MB
    int iterations = 2,
    int parallelism = 1,
  }) : _argon2id = Argon2id(
          memory: memory,
          iterations: iterations,
          parallelism: parallelism,
          hashLength: 32,
        );

  Future<Uint8List> deriveMasterKey({
    required String passphrase,
    required Uint8List salt,
  }) async {
    final passphraseBytes = CryptoUtils.utf8Encode(passphrase);
    try {
      final secretKey = SecretKey(passphraseBytes);
      final derivedKey = await _argon2id.deriveKey(
        secretKey: secretKey,
        nonce: salt,
      );
      final keyBytes = await derivedKey.extractBytes();
      return Uint8List.fromList(keyBytes);
    } finally {
      CryptoUtils.zeroize(passphraseBytes);
    }
  }

  Future<Uint8List> deriveVaultKey(Uint8List masterKey) async {
    final secretKey = SecretKey(masterKey);
    final derived = await _hkdf.deriveKey(
      secretKey: secretKey,
      info: CryptoUtils.utf8Encode('vault-encryption-key-v1'),
    );
    final extracted = await derived.extractBytes();
    return Uint8List.fromList(extracted);
  }

  Future<Uint8List> deriveServerAuthKey(Uint8List masterKey) async {
    final secretKey = SecretKey(masterKey);
    final derived = await _hkdf.deriveKey(
      secretKey: secretKey,
      info: CryptoUtils.utf8Encode('server-authentication-hash-v1'),
    );
    final extracted = await derived.extractBytes();
    return Uint8List.fromList(extracted);
  }
}