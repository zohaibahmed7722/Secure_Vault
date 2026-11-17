import 'dart:typed_data';
import '../models/credential_entry.dart';
import '../../core/crypto/cipher_service.dart';
import '../../core/crypto/crypto_utils.dart';
import '../../core/crypto/key_hierarchy.dart';
import '../../core/crypto/recovery_manager.dart';
import '../../core/storage/encrypted_vault_store.dart';

class VaultRepository {
  final EncryptedVaultStore _store;
  final KeyHierarchy _keyHierarchy;
  final RecoveryManager _recoveryManager = RecoveryManager();

  Uint8List? _activeVaultKey;
  Uint8List? _activeMasterSalt;
  EncryptedEnvelope? _recoveryEnvelope;
  String? _activeRecoveryKey;
  String _passwordHint = '';
  List<CredentialEntry> _cache = [];
  String _vaultUsername = '';
  String _lastVaultUsername = '';
  String? _activeMasterPassword;
  Uint8List? _profileImage;
  bool _isUnlocked = false;

  VaultRepository({
    required EncryptedVaultStore store,
    KeyHierarchy? keyHierarchy,
  })  : _store = store,
        _keyHierarchy = keyHierarchy ?? KeyHierarchy();

  bool get isUnlocked => _isUnlocked;
  List<CredentialEntry> get entries => List.unmodifiable(_cache);
  String get vaultUsername => _vaultUsername;
  String get lastVaultUsername =>
      _lastVaultUsername.isNotEmpty ? _lastVaultUsername : _vaultUsername;
  String? get activeMasterPassword => _activeMasterPassword;
  Uint8List? get profileImage => _profileImage;
  String? get activeRecoveryKey => _activeRecoveryKey;
  String get passwordHint => _passwordHint;

  Future<void> resetVault() async {
    await _store.deleteVaultFile();
    _activeVaultKey = null;
    _activeMasterSalt = null;
    _recoveryEnvelope = null;
    _activeRecoveryKey = null;
    _passwordHint = '';
    _cache = [];
    _vaultUsername = '';
    _lastVaultUsername = '';
    _activeMasterPassword = null;
    _profileImage = null;
    _isUnlocked = false;
  }

  Future<String> initializeVault({
    required String username,
    required String masterPassphrase,
    String? passwordHint,
  }) async {
    if (await _store.vaultExists()) {
      throw StateError('A vault already exists. It will not be overwritten.');
    }
    if (username.trim().isEmpty) {
      throw ArgumentError.value(username, 'username', 'Username is required.');
    }

    final salt = CryptoUtils.randomBytes(16);
    final masterKey = await _keyHierarchy.deriveMasterKey(
      passphrase: masterPassphrase,
      salt: salt,
    );
    Uint8List? vaultKey;
    Uint8List? rawRecoveryKey;
    try {
      vaultKey = await _keyHierarchy.deriveVaultKey(masterKey);
      rawRecoveryKey = _recoveryManager.generateRecoveryKey();
      final recoveryEnvelope = await _recoveryManager.wrapMasterKey(
        masterKey: masterKey,
        recoveryKey: rawRecoveryKey,
      );
      final formattedRecoveryKey =
          _recoveryManager.formatRecoveryKey(rawRecoveryKey);

      _activeMasterSalt = salt;
      _activeVaultKey = vaultKey;
      _recoveryEnvelope = recoveryEnvelope;
      _activeRecoveryKey = formattedRecoveryKey;
      _passwordHint = passwordHint?.trim().isNotEmpty == true
          ? passwordHint!.trim()
          : 'Vault master password';
      _cache = [];
      _vaultUsername = username.trim();
      _lastVaultUsername = _vaultUsername;
      _activeMasterPassword = masterPassphrase;
      _profileImage = null;
      _isUnlocked = true;

      await _store.saveVault(
        entries: _cache,
        vaultUsername: _vaultUsername,
        passwordHint: _passwordHint,
        recoveryKey: _activeRecoveryKey,
        vaultKey: vaultKey,
        masterSalt: _activeMasterSalt!,
        recoveryEnvelope: _recoveryEnvelope!,
      );
      return formattedRecoveryKey;
    } catch (_) {
      lock();
      rethrow;
    } finally {
      CryptoUtils.zeroize(masterKey);
      CryptoUtils.zeroize(rawRecoveryKey);
    }
  }

  Future<bool> unlockWithCredentials({
    required String username,
    required String passphrase,
  }) async {
    final header = await _store.readPublicHeader();
    if (header == null) return false;

    final passphrasesToTry = <String>[
      passphrase,
      if (passphrase.trim() != passphrase) passphrase.trim(),
    ];

    for (final candidatePassphrase in passphrasesToTry) {
      final masterKey = await _keyHierarchy.deriveMasterKey(
        passphrase: candidatePassphrase,
        salt: header.salt,
      );
      final vaultKey = await _keyHierarchy.deriveVaultKey(masterKey);
      CryptoUtils.zeroize(masterKey);

      try {
        final result = await _store.loadVault(vaultKey: vaultKey);
        if (result == null) {
          CryptoUtils.zeroize(vaultKey);
          continue;
        }
        final normalizedUsername = username.trim().toLowerCase();
        if (normalizedUsername.isEmpty ||
            (result.username.isNotEmpty &&
                result.username.trim().toLowerCase() != normalizedUsername)) {
          CryptoUtils.zeroize(vaultKey);
          return false;
        }

        _activeVaultKey = vaultKey;
        _activeMasterPassword = candidatePassphrase;
        _activeMasterSalt = result.masterSalt;
        _recoveryEnvelope = result.recoveryEnvelope;
        _activeRecoveryKey = result.recoveryKey;
        _passwordHint = result.passwordHint;
        _cache = result.entries;
        _vaultUsername =
            result.username.isEmpty ? username.trim() : result.username;
        _lastVaultUsername = _vaultUsername;
        _profileImage = result.profileImage;
        _isUnlocked = true;
        if (result.username.isEmpty) {
          try {
            await _persist();
          } catch (_) {
            lock();
            rethrow;
          }
        }
        return true;
      } on DecryptionException {
        CryptoUtils.zeroize(vaultKey);
        // continue trying next passphrase candidate
      } catch (_) {
        CryptoUtils.zeroize(vaultKey);
        rethrow;
      }
    }
    return false;
  }

  Future<bool> recoverWithKey(String formattedRecoveryKey) async {
    final header = await _store.readPublicHeader();
    if (header == null) return false;

    Uint8List rawRecoveryKey;
    var unlocked = false;
    try {
      rawRecoveryKey = _recoveryManager.parseRecoveryKey(formattedRecoveryKey);
    } catch (_) {
      return false;
    }

    Uint8List? vaultKey;
    Uint8List? unwrappedMasterKey;
    try {
      unwrappedMasterKey = await _recoveryManager.unwrapMasterKey(
        wrappedEnvelope: header.recoveryEnvelope,
        recoveryKey: rawRecoveryKey,
      );
      vaultKey = await _keyHierarchy.deriveVaultKey(unwrappedMasterKey);
      CryptoUtils.zeroize(unwrappedMasterKey);
      unwrappedMasterKey = null;

      final result = await _store.loadVault(vaultKey: vaultKey);
      if (result == null) {
        CryptoUtils.zeroize(vaultKey);
        return false;
      }

      _activeVaultKey = vaultKey;
      _activeMasterSalt = result.masterSalt;
      _recoveryEnvelope = result.recoveryEnvelope;
      _activeRecoveryKey = result.recoveryKey ?? formattedRecoveryKey;
      _passwordHint = result.passwordHint;
      _cache = result.entries;
      _vaultUsername = result.username;
      _profileImage = result.profileImage;
      _isUnlocked = true;
      unlocked = true;
      return true;
    } on DecryptionException {
      CryptoUtils.zeroize(vaultKey);
      return false;
    } finally {
      if (!unlocked) CryptoUtils.zeroize(vaultKey);
      CryptoUtils.zeroize(unwrappedMasterKey);
      CryptoUtils.zeroize(rawRecoveryKey);
    }
  }

  Future<String?> getUsernameHintWithRecoveryKey(
    String formattedRecoveryKey,
  ) async {
    final header = await _store.readPublicHeader();
    if (header == null) return null;

    Uint8List rawRecoveryKey;
    try {
      rawRecoveryKey = _recoveryManager.parseRecoveryKey(formattedRecoveryKey);
    } on FormatException {
      return null;
    }

    Uint8List? masterKey;
    Uint8List? vaultKey;
    try {
      masterKey = await _recoveryManager.unwrapMasterKey(
        wrappedEnvelope: header.recoveryEnvelope,
        recoveryKey: rawRecoveryKey,
      );
      vaultKey = await _keyHierarchy.deriveVaultKey(masterKey);
      final username = await _store.loadVaultUsername(vaultKey: vaultKey);
      if (username == null || username.trim().isEmpty) return null;
      return _maskUsername(username.trim());
    } on DecryptionException {
      return null;
    } finally {
      CryptoUtils.zeroize(masterKey);
      CryptoUtils.zeroize(vaultKey);
      CryptoUtils.zeroize(rawRecoveryKey);
    }
  }

  Future<String?> getPasswordHintWithRecoveryKey(
    String formattedRecoveryKey,
  ) async {
    final header = await _store.readPublicHeader();
    if (header == null) return null;

    Uint8List rawRecoveryKey;
    try {
      rawRecoveryKey = _recoveryManager.parseRecoveryKey(formattedRecoveryKey);
    } on FormatException {
      return null;
    }

    Uint8List? masterKey;
    Uint8List? vaultKey;
    try {
      masterKey = await _recoveryManager.unwrapMasterKey(
        wrappedEnvelope: header.recoveryEnvelope,
        recoveryKey: rawRecoveryKey,
      );
      vaultKey = await _keyHierarchy.deriveVaultKey(masterKey);
      final hints = await _store.loadVaultHints(vaultKey: vaultKey);
      if (hints != null && hints.passwordHint.trim().isNotEmpty) {
        return hints.passwordHint.trim();
      }
      return 'Vault master passphrase (at least 6 characters)';
    } on DecryptionException {
      return null;
    } finally {
      CryptoUtils.zeroize(masterKey);
      CryptoUtils.zeroize(vaultKey);
      CryptoUtils.zeroize(rawRecoveryKey);
    }
  }

  String _maskUsername(String username) {
    final characters =
        username.runes.map((rune) => String.fromCharCode(rune)).toList();
    if (characters.length == 1) return characters.first;
    if (characters.length == 2) return '${characters.first}•';
    return '${characters.first}${'•' * (characters.length - 2)}${characters.last}';
  }

  Future<void> saveCredential(CredentialEntry entry) async {
    _assertUnlocked();
    final index = _cache.indexWhere((e) => e.id == entry.id);
    final previousEntry = index >= 0 ? _cache[index] : null;
    if (index >= 0) {
      _cache[index] = entry;
    } else {
      _cache.add(entry);
    }
    try {
      await _persist();
    } catch (_) {
      if (index >= 0) {
        _cache[index] = previousEntry!;
      } else {
        _cache.removeWhere((cachedEntry) => cachedEntry.id == entry.id);
      }
      rethrow;
    }
  }

  Future<void> saveProfileImage(Uint8List? image) async {
    _assertUnlocked();
    final previousImage = _profileImage;
    _profileImage = image == null ? null : Uint8List.fromList(image);
    try {
      await _persist();
    } catch (_) {
      _profileImage = previousImage;
      rethrow;
    }
  }

  Future<void> updateVaultUsername(String username) async {
    _assertUnlocked();
    final updatedUsername = username.trim();
    if (updatedUsername.isEmpty) {
      throw ArgumentError.value(username, 'username', 'Username is required.');
    }
    final previousUsername = _vaultUsername;
    _vaultUsername = updatedUsername;
    _lastVaultUsername = updatedUsername;
    try {
      await _persist();
    } catch (_) {
      _vaultUsername = previousUsername;
      _lastVaultUsername = previousUsername;
      rethrow;
    }
  }

  Future<String> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _assertUnlocked();
    if (newPassword.trim().isEmpty) {
      throw ArgumentError('New password cannot be empty.');
    }
    if (newPassword.length < 6) {
      throw ArgumentError('New password must be at least 6 characters long.');
    }

    // 1. Verify current password
    final currentMasterKey = await _keyHierarchy.deriveMasterKey(
      passphrase: currentPassword,
      salt: _activeMasterSalt!,
    );
    final derivedVaultKey = await _keyHierarchy.deriveVaultKey(currentMasterKey);
    CryptoUtils.zeroize(currentMasterKey);

    final isValid = CryptoUtils.constantTimeEquals(
      derivedVaultKey,
      _activeVaultKey!,
    );
    CryptoUtils.zeroize(derivedVaultKey);

    if (!isValid) {
      throw ArgumentError('Current password is incorrect.');
    }

    // 2. Generate new salt and derive new master key
    final newSalt = CryptoUtils.randomBytes(16);
    final newMasterKey = await _keyHierarchy.deriveMasterKey(
      passphrase: newPassword,
      salt: newSalt,
    );

    // 3. Generate new vault key and recovery key envelope
    Uint8List? newVaultKey;
    Uint8List? rawRecoveryKey;
    try {
      newVaultKey = await _keyHierarchy.deriveVaultKey(newMasterKey);
      rawRecoveryKey = _recoveryManager.generateRecoveryKey();
      final newRecoveryEnvelope = await _recoveryManager.wrapMasterKey(
        masterKey: newMasterKey,
        recoveryKey: rawRecoveryKey,
      );
      final formattedRecoveryKey =
          _recoveryManager.formatRecoveryKey(rawRecoveryKey);

      final oldSalt = _activeMasterSalt;
      final oldVaultKey = _activeVaultKey;
      final oldRecoveryEnvelope = _recoveryEnvelope;

      _activeMasterSalt = newSalt;
      _activeVaultKey = newVaultKey;
      _recoveryEnvelope = newRecoveryEnvelope;
      _activeRecoveryKey = formattedRecoveryKey;

      try {
        await _persist();
        _activeMasterPassword = newPassword;
        CryptoUtils.zeroize(oldVaultKey);
        return formattedRecoveryKey;
      } catch (_) {
        _activeMasterSalt = oldSalt;
        _activeVaultKey = oldVaultKey;
        _recoveryEnvelope = oldRecoveryEnvelope;
        CryptoUtils.zeroize(newVaultKey);
        rethrow;
      }
    } finally {
      CryptoUtils.zeroize(newMasterKey);
      CryptoUtils.zeroize(rawRecoveryKey);
    }
  }

  Future<void> updatePasswordHint(String hint) async {
    _assertUnlocked();
    _passwordHint = hint.trim();
    await _persist();
  }

  Future<String> regenerateRecoveryKey(String currentPassword) async {
    _assertUnlocked();
    final currentMasterKey = await _keyHierarchy.deriveMasterKey(
      passphrase: currentPassword,
      salt: _activeMasterSalt!,
    );
    final derivedVaultKey = await _keyHierarchy.deriveVaultKey(currentMasterKey);

    final isValid = CryptoUtils.constantTimeEquals(
      derivedVaultKey,
      _activeVaultKey!,
    );
    CryptoUtils.zeroize(derivedVaultKey);

    if (!isValid) {
      CryptoUtils.zeroize(currentMasterKey);
      throw ArgumentError('Current password is incorrect.');
    }

    Uint8List? rawRecoveryKey;
    try {
      rawRecoveryKey = _recoveryManager.generateRecoveryKey();
      final newRecoveryEnvelope = await _recoveryManager.wrapMasterKey(
        masterKey: currentMasterKey,
        recoveryKey: rawRecoveryKey,
      );
      final formatted = _recoveryManager.formatRecoveryKey(rawRecoveryKey);
      _recoveryEnvelope = newRecoveryEnvelope;
      _activeRecoveryKey = formatted;
      await _persist();
      return formatted;
    } finally {
      CryptoUtils.zeroize(currentMasterKey);
      CryptoUtils.zeroize(rawRecoveryKey);
    }
  }

  Future<void> deleteCredential(String id) async {
    _assertUnlocked();
    final index = _cache.indexWhere((entry) => entry.id == id);
    if (index < 0) return;
    final removedEntry = _cache[index];
    _cache.removeWhere((e) => e.id == id);
    try {
      await _persist();
    } catch (_) {
      _cache.insert(index, removedEntry);
      rethrow;
    }
  }

  void lock() {
    CryptoUtils.zeroize(_activeVaultKey);
    _activeVaultKey = null;
    _cache = [];
    _vaultUsername = '';
    _activeRecoveryKey = null;
    _passwordHint = '';
    _activeMasterPassword = null;
    CryptoUtils.zeroize(_profileImage);
    _profileImage = null;
    _isUnlocked = false;
  }

  Future<void> _persist() async {
    await _store.saveVault(
      entries: _cache,
      vaultUsername: _vaultUsername,
      passwordHint: _passwordHint,
      recoveryKey: _activeRecoveryKey,
      profileImage: _profileImage,
      vaultKey: _activeVaultKey!,
      masterSalt: _activeMasterSalt!,
      recoveryEnvelope: _recoveryEnvelope!,
    );
  }

  void _assertUnlocked() {
    if (!_isUnlocked || _activeVaultKey == null) {
      throw StateError('Vault is locked. No active key in memory.');
    }
  }
}
