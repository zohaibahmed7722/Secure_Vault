import 'dart:math';

class PasswordGenerator {
  static const String uppercaseChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const String lowercaseChars = 'abcdefghijkmnopqrstuvwxyz';
  static const String digitChars = '23456789';
  static const String symbolChars = r'!@#$%^&*()-_=+[]{}|;:,.<>?';

  static final Random _secureRandom = Random.secure();

  static String generate({
    int length = 20,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeDigits = true,
    bool includeSymbols = true,
  }) {
    if (length < 8) {
      throw ArgumentError('Password length must be at least 8 characters.');
    }

    final pool = StringBuffer();
    final guaranteed = <String>[];

    if (includeUppercase) {
      pool.write(uppercaseChars);
      guaranteed.add(uppercaseChars[_secureRandom.nextInt(uppercaseChars.length)]);
    }
    if (includeLowercase) {
      pool.write(lowercaseChars);
      guaranteed.add(lowercaseChars[_secureRandom.nextInt(lowercaseChars.length)]);
    }
    if (includeDigits) {
      pool.write(digitChars);
      guaranteed.add(digitChars[_secureRandom.nextInt(digitChars.length)]);
    }
    if (includeSymbols) {
      pool.write(symbolChars);
      guaranteed.add(symbolChars[_secureRandom.nextInt(symbolChars.length)]);
    }

    final allChars = pool.toString();
    if (allChars.isEmpty) {
      throw ArgumentError('At least one character set must be selected.');
    }

    final passwordList = <String>[...guaranteed];
    for (int i = guaranteed.length; i < length; i++) {
      passwordList.add(allChars[_secureRandom.nextInt(allChars.length)]);
    }

    for (int i = passwordList.length - 1; i > 0; i--) {
      int j = _secureRandom.nextInt(i + 1);
      final temp = passwordList[i];
      passwordList[i] = passwordList[j];
      passwordList[j] = temp;
    }

    return passwordList.join('');
  }

  static double calculateEntropy(String password) {
    if (password.isEmpty) return 0.0;
    int poolSize = 0;
    if (password.contains(RegExp(r'[A-Z]'))) poolSize += 26;
    if (password.contains(RegExp(r'[a-z]'))) poolSize += 26;
    if (password.contains(RegExp(r'[0-9]'))) poolSize += 10;
    if (password.contains(RegExp(r'[^A-Za-z0-9]'))) poolSize += 32;

    if (poolSize == 0) return 0.0;
    return password.length * (log(poolSize) / ln2);
  }
}