import 'dart:convert';

import 'package:spider_js/src/drpy/crypto.dart';
import 'package:test/test.dart';

void main() {
  group('drpy 编码', () {
    test('base64 编码解码往返', () {
      const text = 'hello世界';
      final encoded = base64EncodeDrpy(utf8.encode(text));
      expect(encoded, 'aGVsbG/kuJbnlYw=');
      expect(utf8.decode(base64DecodeDrpy(encoded)), text);
    });

    test('urlencode', () {
      expect(urlencode('a b&c'), 'a%20b%26c');
      expect(urldecode('a%20b%26c'), 'a b&c');
    });

    test('md5 已知向量', () {
      expect(md5('abc'), '900150983cd24fb0d6963f7d28e17f72');
    });

    test('sha1 已知向量', () {
      expect(sha1('abc'), 'a9993e364706816aba3e25717850c26c9cd0d89d');
    });

    test('sha256 已知向量', () {
      expect(
        sha256Drpy('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });
  });

  group('drpy 加密', () {
    test('AES-CBC 加密→解密往返', () {
      const key = '0123456789abcdef';
      const iv = 'abcdef0123456789';
      final encrypted = aes(
        mode: 'AES/CBC/PKCS5Padding',
        encrypt: true,
        input: 'MiStream',
        inBase64: false,
        key: key,
        iv: iv,
        outBase64: true,
      );
      expect(encrypted, isNotEmpty);
      final decrypted = aes(
        mode: 'AES/CBC/PKCS5Padding',
        encrypt: false,
        input: encrypted,
        inBase64: true,
        key: key,
        iv: iv,
        outBase64: false,
      );
      expect(decrypted, 'MiStream');
    });

    test('AES-ECB 加密→解密往返', () {
      const key = '0123456789abcdef';
      final encrypted = aes(
        mode: 'AES/ECB/PKCS5Padding',
        encrypt: true,
        input: 'test data',
        inBase64: false,
        key: key,
        iv: '',
        outBase64: true,
      );
      final decrypted = aes(
        mode: 'AES/ECB/PKCS5Padding',
        encrypt: false,
        input: encrypted,
        inBase64: true,
        key: key,
        iv: '',
        outBase64: false,
      );
      expect(decrypted, 'test data');
    });

    test('hmac-sha256 已知向量', () {
      // RFC 4231 测试向量 1
      expect(
        hmac256('Hi There', '\x0b' * 20),
        'b0344c61d8db38535ca8afceaf0bf12b'
        '881dc200c9833da726e9376c2e32cff7',
      );
    });
  });

  group('drpy 工具', () {
    test('joinUrl 相对路径', () {
      expect(
        joinUrl('https://example.com/api.php', 'detail.php?id=1'),
        'https://example.com/detail.php?id=1',
      );
      expect(
        joinUrl('https://example.com/api.php', '/other.php'),
        'https://example.com/other.php',
      );
      expect(
        joinUrl('https://example.com/api.php', 'https://other.com/x'),
        'https://other.com/x',
      );
    });

    // 期望值来自参考实现 `utils/utils.js` 的 `urljoin` 实测（Node 跑
    // `new URL(to, new URL(from, 'resolve://'))`）。核心是那个 `resolve://`
    // 占位 base：空 base 时**不是**「原样返回」，而是补成根相对路径。
    test('joinUrl 对齐参考实现（含空 base 与协议相对）', () {
      const cases = <(String, String, String)>[
        ('', 'a.jpg', '/a.jpg'),
        ('', '/abs.jpg', '/abs.jpg'),
        ('', 'http://x.com/c.jpg', 'http://x.com/c.jpg'),
        ('', '3', '/3'),
        ('', '', ''),
        ('http://a.com/x/', 'b.jpg', 'http://a.com/x/b.jpg'),
        ('http://a.com/x/page.html', 'b.jpg', 'http://a.com/x/b.jpg'),
        ('http://a.com/x/', '//cdn.com/b.jpg', 'http://cdn.com/b.jpg'),
        ('http://a.com/x/', 'b.jpg?q=1#f', 'http://a.com/x/b.jpg?q=1#f'),
        ('https://a.com/x/y', '../z', 'https://a.com/z'),
        ('a/b/', 'c.jpg', '/a/b/c.jpg'),
      ];
      for (final (base, path, want) in cases) {
        expect(joinUrl(base, path), want, reason: 'joinUrl($base, $path)');
      }
    });
  });
}
