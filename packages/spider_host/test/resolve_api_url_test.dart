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
}
