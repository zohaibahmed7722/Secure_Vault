@Timeout(Duration(seconds: 30))
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_vault/core/crypto/cipher_service.dart';
import 'package:secure_vault/core/crypto/crypto_utils.dart';
import 'package:secure_vault/core/crypto/key_hierarchy.dart';
import 'package:secure_vault/core/crypto/recovery_manager.dart';
import 'package:secure_vault/core/storage/encrypted_vault_store.dart';
import 'package:secure_vault/domain/models/credential_entry.dart';
import 'package:secure_vault/domain/models/password_config.dart';
import 'package:secure_vault/domain/repositories/vault_repository.dart';

void main() {
  group('Cryptographic Core Tests', () {
    late CipherService cipherService;
    late KeyHierarchy keyHierarchy;
    late RecoveryManager recoveryManager;

    setUp(() {
      cipherService = CipherService();
      // Fast KDF parameters for testing
      keyHierarchy = KeyHierarchy(memory: 1024, iterations: 1, parallelism: 1);
      recoveryManager = RecoveryManager();
    });

    test('AES-256-GCM Roundtrip Encryption and Decryption', () async {
      final key = CryptoUtils.randomBytes(32);
      final plaintext = utf8.encode('SensitivePassword123!@#');
      final aad = utf8.encode('user-aad-context');

      final envelope = await cipherService.encrypt(
        plaintext: Uint8List.fromList(plaintext),
        secretKeyBytes: key,
        additionalAuthenticatedData: aad,
      );

      expect(envelope.cipherText, isNot(equals(plaintext)));
      expect(envelope.nonce.length, equals(12));
      expect(envelope.macTag.length, equals(16));

      final decrypted = await cipherService.decrypt(
        envelope: envelope,
        secretKeyBytes: key,
      );

      expect(utf8.decode(decrypted), equals('SensitivePassword123!@#'));
    });

    test('Ciphertext Tampering Fails Decryption with Integrity Exception',
        () async {
      final key = CryptoUtils.randomBytes(32);
      final plaintext = utf8.encode('DataIntegrityPayload');

      final envelope = await cipherService.encrypt(
        plaintext: Uint8List.fromList(plaintext),
        secretKeyBytes: key,
      );

      envelope.cipherText[0] ^= 0xFF; // Bit-flip

      expect(
        () async => await cipherService.decrypt(
          envelope: envelope,
          secretKeyBytes: key,
        ),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('Key Hierarchy Separates Vault Key and Server Auth Key', () async {
      final salt = CryptoUtils.randomBytes(16);
      final masterKey = await keyHierarchy.deriveMasterKey(
        passphrase: 'CorrectHorseBatteryStaple',
        salt: salt,
      );

      final vaultKey = await keyHierarchy.deriveVaultKey(masterKey);
      final serverAuthKey = await keyHierarchy.deriveServerAuthKey(masterKey);

      expect(vaultKey.length, equals(32));
      expect(serverAuthKey.length, equals(32));
      expect(vaultKey, isNot(equals(serverAuthKey)));
    });

    test('Recovery Key Wrap & Unwrap Cycle Restores Valid Master Key',
        () async {
      final originalMasterKey = CryptoUtils.randomBytes(32);
      final recoveryKey = recoveryManager.generateRecoveryKey();

      final wrappedEnvelope = await recoveryManager.wrapMasterKey(
        masterKey: originalMasterKey,
        recoveryKey: recoveryKey,
      );

      final unwrappedMasterKey = await recoveryManager.unwrapMasterKey(
        wrappedEnvelope: wrappedEnvelope,
        recoveryKey: recoveryKey,
      );

      expect(unwrappedMasterKey, equals(originalMasterKey));
    });

    test('Password Generator Satisfies Charset and High Entropy Constraints',
        () {
      final password = PasswordGenerator.generate(
        length: 24,
        includeUppercase: true,
        includeLowercase: true,
        includeDigits: true,
        includeSymbols: true,
      );

      expect(password.length, equals(24));
      expect(password.contains(RegExp(r'[A-Z]')), isTrue);
      expect(password.contains(RegExp(r'[a-z]')), isTrue);
      expect(password.contains(RegExp(r'[0-9]')), isTrue);
      expect(password.contains(RegExp(r'[^A-Za-z0-9]')), isTrue);

      final entropy = PasswordGenerator.calculateEntropy(password);
      expect(entropy, greaterThan(120.0));
    });
  });

  group('Atomic Persistence Tests', () {
    late Directory tempDir;
    late EncryptedVaultStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('vault_test_');
      store = EncryptedVaultStore(storageDirectoryPath: tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Atomic Store Saves and Loads Valid Vault Records', () async {
      final vaultKey = CryptoUtils.randomBytes(32);
      final masterSalt = CryptoUtils.randomBytes(16);
      final recoveryEnvelope = EncryptedEnvelope(
        cipherText: Uint8List(16),
        nonce: Uint8List(12),
        macTag: Uint8List(16),
        aad: Uint8List(0),
      );

      final entry = CredentialEntry(
        title: 'ProtonMail',
        username: 'user@proton.me',
        password: 'SuperSecretPassword!',
        isFavorite: true,
        attachments: [
          CredentialAttachment(
            name: 'recovery-code.txt',
            bytes: Uint8List.fromList([1, 2, 3, 4]),
          ),
        ],
      );

      await store.saveVault(
        entries: [entry],
        vaultKey: vaultKey,
        masterSalt: masterSalt,
        recoveryEnvelope: recoveryEnvelope,
      );

      expect(await store.vaultExists(), isTrue);

      final loaded = await store.loadVault(vaultKey: vaultKey);
      expect(loaded, isNotNull);
      expect(loaded!.entries.length, equals(1));
      expect(loaded.entries.first.title, equals('ProtonMail'));
      expect(loaded.entries.first.isFavorite, isTrue);
      expect(loaded.entries.first.attachments, hasLength(1));
      expect(loaded.entries.first.attachments.single.name, 'recovery-code.txt');
      expect(
        loaded.entries.first.attachments.single.bytes,
        orderedEquals([1, 2, 3, 4]),
      );
    });

    test('Store still loads vaults saved in the older entries-only format',
        () async {
      final vaultKey = CryptoUtils.randomBytes(32);
      final masterSalt = CryptoUtils.randomBytes(16);
      final recoveryEnvelope = EncryptedEnvelope(
        cipherText: Uint8List(16),
        nonce: Uint8List(12),
        macTag: Uint8List(16),
        aad: Uint8List(0),
      );
      final entry = CredentialEntry(
        title: 'Legacy email',
        username: 'legacy@example.com',
        password: 'LegacyPassword123!',
      );
      final plaintext = CryptoUtils.utf8Encode(
        json.encode([entry.toJson()]),
      );
      final envelope = await CipherService().encrypt(
        plaintext: plaintext,
        secretKeyBytes: vaultKey,
        additionalAuthenticatedData: CryptoUtils.utf8Encode('vault-file-v1'),
      );
      CryptoUtils.zeroize(plaintext);
      await store.vaultFile.writeAsString(
        json.encode({
          'version': 1,
          'salt': CryptoUtils.toBase64(masterSalt),
          'recovery': recoveryEnvelope.toJson(),
          'vault': envelope.toJson(),
        }),
      );

      final loaded = await store.loadVault(vaultKey: vaultKey);

      expect(loaded, isNotNull);
      expect(loaded!.username, isEmpty);
      expect(loaded.entries.single.username, 'legacy@example.com');
    });
  });

  group('Vault Repository Persistence Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'vault_repository_test_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Credentials remain available after reopening the vault', () async {
      final keyHierarchy = KeyHierarchy(
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );
      final store = EncryptedVaultStore(storageDirectoryPath: tempDir.path);
      final repository = VaultRepository(
        store: store,
        keyHierarchy: keyHierarchy,
      );
      const passphrase = 'CorrectHorseBatteryStaple';
      final recoveryKey = await repository.initializeVault(
        username: 'testuser',
        masterPassphrase: passphrase,
      );
      await repository.saveProfileImage(Uint8List.fromList([7, 8, 9, 10]));

      final credential = CredentialEntry(
        title: 'Email',
        username: 'user@example.com',
        password: 'ExamplePassword123!',
      );
      await repository.saveCredential(credential);

      final reopenedRepository = VaultRepository(
        store: store,
        keyHierarchy: keyHierarchy,
      );
      expect(
        await reopenedRepository.unlockWithCredentials(
          username: 'wronguser',
          passphrase: passphrase,
        ),
        isFalse,
      );
      expect(
        await reopenedRepository.unlockWithCredentials(
          username: 'testuser',
          passphrase: passphrase,
        ),
        isTrue,
      );
      expect(reopenedRepository.vaultUsername, 'testuser');
      expect(reopenedRepository.profileImage, orderedEquals([7, 8, 9, 10]));
      expect(reopenedRepository.entries, hasLength(1));
      expect(reopenedRepository.entries.single.title, 'Email');
      expect(reopenedRepository.entries.single.username, 'user@example.com');
      expect(
        reopenedRepository.entries.single.password,
        'ExamplePassword123!',
      );
      await reopenedRepository.updateVaultUsername('TestUser');
      expect(reopenedRepository.vaultUsername, 'TestUser');
      reopenedRepository.lock();
      expect(reopenedRepository.isUnlocked, isFalse);
      expect(
        await reopenedRepository.unlockWithCredentials(
          username: 'TestUser',
          passphrase: 'incorrect-password',
        ),
        isFalse,
      );
      expect(
        await reopenedRepository.unlockWithCredentials(
          username: 'testuser',
          passphrase: passphrase,
        ),
        isTrue,
      );

      final recoveryRepository = VaultRepository(
        store: store,
        keyHierarchy: keyHierarchy,
      );
      expect(
        await recoveryRepository.getUsernameHintWithRecoveryKey(recoveryKey),
        'T••••••r',
      );
      expect(recoveryRepository.isUnlocked, isFalse);
      expect(
        await recoveryRepository.getUsernameHintWithRecoveryKey('invalid'),
        isNull,
      );
      expect(await recoveryRepository.recoverWithKey(recoveryKey), isTrue);
      expect(recoveryRepository.vaultUsername, 'TestUser');
      expect(recoveryRepository.entries.single.title, 'Email');
    });

    test('An existing vault cannot be overwritten by setup', () async {
      final keyHierarchy = KeyHierarchy(
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );
      final store = EncryptedVaultStore(storageDirectoryPath: tempDir.path);
      final repository = VaultRepository(
        store: store,
        keyHierarchy: keyHierarchy,
      );
      const originalPassphrase = 'CorrectHorseBatteryStaple';
      await repository.initializeVault(
        username: 'original',
        masterPassphrase: originalPassphrase,
      );

      await expectLater(
        repository.initializeVault(
          username: 'replacement',
          masterPassphrase: 'DifferentPassphrase123!',
        ),
        throwsA(isA<StateError>()),
      );
      repository.lock();

      final reopened =
          VaultRepository(store: store, keyHierarchy: keyHierarchy);
      expect(
        await reopened.unlockWithCredentials(
          username: 'original',
          passphrase: originalPassphrase,
        ),
        isTrue,
      );
    });

    test('Resetting vault deletes store file and allows re-initializing a new vault', () async {
      final keyHierarchy = KeyHierarchy();
      final store = EncryptedVaultStore(storageDirectoryPath: tempDir.path);
      final repository = VaultRepository(
        store: store,
        keyHierarchy: keyHierarchy,
      );
      await repository.initializeVault(
        username: 'old_user',
        masterPassphrase: 'OldPassphrase123!',
      );
      expect(await store.vaultExists(), isTrue);

      await repository.resetVault();
      expect(await store.vaultExists(), isFalse);
      expect(repository.isUnlocked, isFalse);

      final newKey = await repository.initializeVault(
        username: 'new_user',
        masterPassphrase: 'NewPassphrase123!',
      );
      expect(newKey, isNotEmpty);
      expect(repository.vaultUsername, 'new_user');
    });
  });
}
