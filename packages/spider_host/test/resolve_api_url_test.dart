import 'package:spider_host/spider_host.dart';
import 'package:test/test.dart';

void main() {
  group('SpiderRuntimeFactory.resolveApiUrl', () {
    test('resolves relative path against sourceUrl', () {
      final result = SpiderRuntimeFactory.resolveApiUrl(
        './lib/drpy2.min.js',
        'https://raw.githubusercontent.com/user/repo/main/dianshi.json',
      );
      expect(
        result,
        'https://raw.githubusercontent.com/user/repo/main/lib/drpy2.min.js',
      );
    });

    test('resolves ../ relative path', () {
      final result = SpiderRuntimeFactory.resolveApiUrl(
        '../other/drpy2.min.js',
        'https://example.com/configs/my/dianshi.json',
      );
      expect(
        result,
        'https://example.com/configs/other/drpy2.min.js',
      );
    });

    test('passes through absolute http URL', () {
      final result = SpiderRuntimeFactory.resolveApiUrl(
        'https://cdn.example.com/drpy2.min.js',
        'https://example.com/dianshi.json',
      );
      expect(result, 'https://cdn.example.com/drpy2.min.js');
    });

    test('passes through absolute https URL', () {
      final result = SpiderRuntimeFactory.resolveApiUrl(
        'http://cdn.example.com/drpy2.min.js',
        null,
      );
      expect(result, 'http://cdn.example.com/drpy2.min.js');
    });

    test('returns api as-is when no sourceUrl', () {
      expect(
        SpiderRuntimeFactory.resolveApiUrl('./lib/drpy2.min.js', null),
        './lib/drpy2.min.js',
      );
    });

    test('returns api as-is when sourceUrl is empty', () {
      expect(
        SpiderRuntimeFactory.resolveApiUrl('./lib/drpy2.min.js', ''),
        './lib/drpy2.min.js',
      );
    });

    test('resolves bare filename against sourceUrl directory', () {
      final result = SpiderRuntimeFactory.resolveApiUrl(
        'drpy2.min.js',
        'https://example.com/configs/dianshi.json',
      );
      expect(result, 'https://example.com/configs/drpy2.min.js');
    });
  });

  group('SpiderRuntimeFactory.resolveExtUrl', () {
    test('resolves relative config path against sourceUrl', () {
      final result = SpiderRuntimeFactory.resolveExtUrl(
        './js/360影视.js',
        'https://example.com/configs/dianshi.json',
      );
      expect(result, 'https://example.com/configs/js/360%E5%BD%B1%E8%A7%86.js');
    });

    test('passes through absolute http URL', () {
      expect(
        SpiderRuntimeFactory.resolveExtUrl(
          'https://cdn.example.com/mod.js',
          'https://example.com/dianshi.json',
        ),
        'https://cdn.example.com/mod.js',
      );
    });

    test('keeps inline JS config untouched', () {
      const inline = 'var rule = {host: "https://x.com"};';
      expect(
        SpiderRuntimeFactory.resolveExtUrl(
          inline,
          'https://example.com/dianshi.json',
        ),
        inline,
      );
    });

    test('returns null for null ext', () {
      expect(
        SpiderRuntimeFactory.resolveExtUrl(
          null,
          'https://example.com/dianshi.json',
        ),
        isNull,
      );
    });

    test('returns ext as-is when no sourceUrl', () {
      expect(
        SpiderRuntimeFactory.resolveExtUrl('./js/360影视.js', null),
        './js/360影视.js',
      );
    });
  });
}
