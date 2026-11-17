import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../crypto/cipher_service.dart';
import '../crypto/crypto_utils.dart';
import '../../domain/models/credential_entry.dart';

class EncryptedVaultStore {
  final File vaultFile;
  final File tempFile;
  final CipherService _cipherService = CipherService();

  EncryptedVaultStore({required String storageDirectoryPath})
      : vaultFile = File('$storageDirectoryPath/vault.enc'),
        tempFile = File('$storageDirectoryPath/vault.tmp');

  Future<void> deleteVaultFile() async {
    if (await vaultFile.exists()) {
      await vaultFile.delete();
    }
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  }

  Future<void> saveVault({
    required List<CredentialEntry> entries,
    String vaultUsername = '',
    String passwordHint = '',
    String? recoveryKey,
    Uint8List? profileImage,
    required Uint8List vaultKey,
    required Uint8List masterSalt,
    required EncryptedEnvelope recoveryEnvelope,
  }) async {
    final vaultData = json.encode({
      'username': vaultUsername,
      'passwordHint': passwordHint,
      if (recoveryKey != null) 'recoveryKey': recoveryKey,
      'profileImage': profileImage == null ? null : base64Encode(profileImage),
      'entries': entries.map((entry) => entry.toJson()).toList(),
    });
    final plaintextBytes = CryptoUtils.utf8Encode(vaultData);
    final aad = CryptoUtils.utf8Encode('vault-file-v1');

    late final EncryptedEnvelope payloadEnvelope;
    try {
      payloadEnvelope = await _cipherService.encrypt(
        plaintext: plaintextBytes,
        secretKeyBytes: vaultKey,
        additionalAuthenticatedData: aad,
      );
    } finally {
      CryptoUtils.zeroize(plaintextBytes);
    }

    final fileContent = {
      'version': 1,
      'salt': CryptoUtils.toBase64(masterSalt),
      'recovery': recoveryEnvelope.toJson(),
      'vault': payloadEnvelope.toJson(),
    };

    final serialized = json.encode(fileContent);

    await tempFile.writeAsString(serialized, flush: true);
    if (await vaultFile.exists()) {
      await vaultFile.delete();
    }
    await tempFile.rename(vaultFile.path);
  }

  Future<VaultLoadResult?> loadVault({required Uint8List vaultKey}) async {
    if (!await vaultFile.exists()) return null;

    final content = await vaultFile.readAsString();
    final jsonMap = json.decode(content) as Map<String, dynamic>;

    final masterSalt = CryptoUtils.fromBase64(jsonMap['salt'] as String);
    final recoveryEnvelope = EncryptedEnvelope.fromJson(
      jsonMap['recovery'] as Map<String, dynamic>,
    );
    final vaultEnvelope = EncryptedEnvelope.fromJson(
      jsonMap['vault'] as Map<String, dynamic>,
    );

    final decryptedBytes = await _cipherService.decrypt(
      envelope: vaultEnvelope,
      secretKeyBytes: vaultKey,
    );

    try {
      final decryptedString = utf8.decode(decryptedBytes);
      final decoded = json.decode(decryptedString);
      final String username;
      final String passwordHint;
      final String? recoveryKey;
      final Uint8List? profileImage;
      final List<dynamic> rawList;
      if (decoded is List<dynamic>) {
        username = '';
        passwordHint = '';
        recoveryKey = null;
        profileImage = null;
        rawList = decoded;
      } else if (decoded is Map<String, dynamic>) {
        username = decoded['username'] as String? ?? '';
        passwordHint = decoded['passwordHint'] as String? ?? '';
        recoveryKey = decoded['recoveryKey'] as String?;
        final encodedImage = decoded['profileImage'] as String?;
        profileImage = encodedImage == null ? null : base64Decode(encodedImage);
        rawList = decoded['entries'] as List<dynamic>;
      } else {
        throw const FormatException('Invalid encrypted vault data.');
      }
      final entries = rawList
          .map((item) => CredentialEntry.fromJson(item as Map<String, dynamic>))
          .toList();

      return VaultLoadResult(
        username: username,
        passwordHint: passwordHint,
        recoveryKey: recoveryKey,
        profileImage: profileImage,
        entries: entries,
        masterSalt: masterSalt,
        recoveryEnvelope: recoveryEnvelope,
      );
    } finally {
      CryptoUtils.zeroize(decryptedBytes);
    }
  }

  Future<VaultHintsResult?> loadVaultHints({required Uint8List vaultKey}) async {
    if (!await vaultFile.exists()) return null;

    final content = await vaultFile.readAsString();
    final jsonMap = json.decode(content) as Map<String, dynamic>;
    final vaultEnvelope = EncryptedEnvelope.fromJson(
      jsonMap['vault'] as Map<String, dynamic>,
    );
    final decryptedBytes = await _cipherService.decrypt(
      envelope: vaultEnvelope,
      secretKeyBytes: vaultKey,
    );

    try {
      final decoded = json.decode(utf8.decode(decryptedBytes));
      if (decoded is! Map<String, dynamic>) return null;
      return VaultHintsResult(
        username: decoded['username'] as String? ?? '',
        passwordHint: decoded['passwordHint'] as String? ?? '',
      );
    } finally {
      CryptoUtils.zeroize(decryptedBytes);
    }
  }

  Future<String?> loadVaultUsername({required Uint8List vaultKey}) async {
    if (!await vaultFile.exists()) return null;

    final content = await vaultFile.readAsString();
    final jsonMap = json.decode(content) as Map<String, dynamic>;
    final vaultEnvelope = EncryptedEnvelope.fromJson(
      jsonMap['vault'] as Map<String, dynamic>,
    );
    final decryptedBytes = await _cipherService.decrypt(
      envelope: vaultEnvelope,
      secretKeyBytes: vaultKey,
    );

    try {
      final decoded = json.decode(utf8.decode(decryptedBytes));
      if (decoded is! Map<String, dynamic>) return null;
      return decoded['username'] as String? ?? '';
    } finally {
      CryptoUtils.zeroize(decryptedBytes);
    }
  }

  Future<bool> vaultExists() async {
    return await vaultFile.exists();
  }

  bool get vaultExistsSync {
    try {
      return vaultFile.existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<VaultPublicHeader?> readPublicHeader() async {
    if (!await vaultFile.exists()) return null;
    final content = await vaultFile.readAsString();
    final jsonMap = json.decode(content) as Map<String, dynamic>;
    return VaultPublicHeader(
      salt: CryptoUtils.fromBase64(jsonMap['salt'] as String),
      recoveryEnvelope: EncryptedEnvelope.fromJson(
        jsonMap['recovery'] as Map<String, dynamic>,
      ),
    );
  }
}

class VaultHintsResult {
  final String username;
  final String passwordHint;

  VaultHintsResult({
    required this.username,
    required this.passwordHint,
  });
}

class VaultLoadResult {
  final String username;
  final String passwordHint;
  final String? recoveryKey;
  final Uint8List? profileImage;
  final List<CredentialEntry> entries;
  final Uint8List masterSalt;
  final EncryptedEnvelope recoveryEnvelope;

  VaultLoadResult({
    this.username = '',
    this.passwordHint = '',
    this.recoveryKey,
    this.profileImage,
    required this.entries,
    required this.masterSalt,
    required this.recoveryEnvelope,
  });
}

class VaultPublicHeader {
  final Uint8List salt;
  final EncryptedEnvelope recoveryEnvelope;

  VaultPublicHeader({required this.salt, required this.recoveryEnvelope});
}
