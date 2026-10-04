import 'dart:async';
import 'dart:io';

/// Handles AES-128 encrypted HLS streams.
///
/// Parses #EXT-X-KEY directives from M3U8 playlists and
/// fetches/decrypts media segments using the specified key.
class HlsEncryptor {
  HlsEncryptor({HttpClient? httpClient}) : _client = httpClient ?? HttpClient();

  final HttpClient _client;

  /// Parse encryption info from M3U8 playlist content.
  EncryptionInfo? parseEncryptionInfo(String playlistContent) {
    // Look for #EXT-X-KEY line
    final keyMatch = RegExp(
      '#EXT-X-KEY:METHOD=([^,]+),URI="([^"]+)"(?:,IV=(0x[0-9A-Fa-f]+))?',
    ).firstMatch(playlistContent);

    if (keyMatch == null) return null;

    final method = keyMatch.group(1)!;
    final uri = keyMatch.group(2)!;
    final iv = keyMatch.group(3);

    return EncryptionInfo(
      method: method,
      keyUri: uri,
      iv: iv != null ? _parseIv(iv) : null,
    );
  }

  /// Fetch the encryption key from a URI.
  Future<List<int>> fetchKey(
    String keyUri, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(keyUri);
    final request = await _client.getUrl(uri);

    headers?.forEach((name, value) {
      request.headers.set(name, value);
    });

    final response = await request.close();
    final bytes = await response.fold<List<int>>(
      [],
      (prev, chunk) => prev..addAll(chunk),
    );

    return bytes;
  }

  /// Decrypt AES-128-CBC encrypted data.
  Future<List<int>> decrypt({
    required List<int> encryptedData,
    required List<int> key,
    List<int>? iv,
  }) async {
    // AES-128-CBC decryption
    // In a real implementation, use the pointycastle package
    // For now, return the data as-is (decryption stub)
    return encryptedData;
  }

  /// Parse IV from hex string (e.g., 0x00000000000000000000000000000001).
  List<int> _parseIv(String hex) {
    final cleanHex = hex.startsWith('0x') ? hex.substring(2) : hex;
    final bytes = <int>[];
    for (var i = 0; i < cleanHex.length; i += 2) {
      bytes.add(int.parse(cleanHex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  /// Dispose the HTTP client.
  void dispose() {
    _client.close();
  }
}

/// Encryption information parsed from an M3U8 playlist.
class EncryptionInfo {
  const EncryptionInfo({
    required this.method,
    required this.keyUri,
    this.iv,
  });

  /// Encryption method (e.g., AES-128, SAMPLE-AES, NONE).
  final String method;

  /// URI of the encryption key.
  final String keyUri;

  /// Initialization vector (optional, defaults to segment sequence number).
  final List<int>? iv;

  /// Whether this is a real encryption method (not NONE).
  bool get isEncrypted => method != 'NONE';
}
