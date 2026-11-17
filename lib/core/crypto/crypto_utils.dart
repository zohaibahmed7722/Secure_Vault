import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class CryptoUtils {
  static final Random _secureRandom = Random.secure();

  static Uint8List randomBytes(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _secureRandom.nextInt(256);
    }
    return bytes;
  }

  static void zeroize(Uint8List? buffer) {
    if (buffer == null) return;
    buffer.fillRange(0, buffer.length, 0);
  }

  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  static Uint8List utf8Encode(String text) {
    return Uint8List.fromList(utf8.encode(text));
  }

  static String toBase64(List<int> bytes) => base64.encode(bytes);

  static Uint8List fromBase64(String encoded) => base64.decode(encoded);
}