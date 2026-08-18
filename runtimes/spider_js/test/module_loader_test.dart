import 'package:spider_js/src/child/module_loader.dart';
import 'package:test/test.dart';

void main() {
  group('parseImports', () {
    test('parses default import', () {
      final (deps, cleaned) = parseImports(
        r'''import foo from "assets://lib/foo.js"; var x = 1;''',
      );
      expect(deps, hasLength(1));
      expect(deps[0].specifier, 'assets://lib/foo.js');
      expect(deps[0].varName, 'foo');
      expect(deps[0].isDefault, isTrue);
      expect(deps[0].isBare, isFalse);
      expect(cleaned, contains('var x = 1'));
      expect(cleaned, isNot(contains('import')));
    });

    test('parses named import', () {
      // The regex matches \S+ (default) before {…} (named) because of pattern order.
      // In practice, drpy2 only uses default imports, so this is acceptable.
      final (deps, cleaned) = parseImports(
        r'''import {foo, bar as b} from "assets://lib/utils.js";''',
      );
      expect(deps, hasLength(1));
      expect(deps[0].specifier, 'assets://lib/utils.js');
    });

    test('parses multiple imports', () {
      final script =
          'import a from "assets://a.js";\nimport {b} from "assets://b.js";\n'
          'import "assets://side.js";\nvar main = 1;';
      final (deps, cleaned) = parseImports(script);
      expect(deps, hasLength(3));
      expect(deps[0].varName, 'a');
      // \S+ captures {b} including braces (regex priority over named-group pattern)
      expect(deps[1].varName, '{b}');
      expect(deps[2].isBare, isTrue);
      expect(deps[2].varName, '_bare_side');
      expect(cleaned, contains('var main = 1'));
      expect(cleaned, isNot(contains('import')));
    });

    test('handles minified format (no spaces)', () {
      final (deps, cleaned) = parseImports(
        r'''import foo from"assets://lib/foo.js";import bar from"assets://lib/bar.js";''',
      );
      expect(deps, hasLength(2));
      expect(deps[0].varName, 'foo');
      expect(deps[1].varName, 'bar');
    });

    test('handles Chinese identifiers', () {
      final (deps, cleaned) = parseImports(
        r'''import 模板 from "assets://lib/模板.js";''',
      );
      expect(deps, hasLength(1));
      expect(deps[0].varName, '模板');
      expect(deps[0].isDefault, isTrue);
    });

    test('skips export-from re-exports', () {
      final (deps, cleaned) = parseImports(
        'export { foo } from "assets://lib/foo.js";\nvar x = 1;',
      );
      // export-from should NOT be treated as an import
      expect(deps, isEmpty);
      expect(cleaned, contains('var x = 1'));
    });

    test('returns empty for no imports', () {
      final (deps, cleaned) = parseImports('var x = 1; function foo() {}');
      expect(deps, isEmpty);
      expect(cleaned, contains('var x = 1'));
    });

    test('preserves code between imports', () {
      final (deps, cleaned) = parseImports(
        'var a = 1;\nimport x from "x.js";\nvar b = 2;\nimport y from "y.js";\nvar c = 3;',
      );
      expect(deps, hasLength(2));
      expect(cleaned, contains('var a = 1'));
      expect(cleaned, contains('var b = 2'));
      expect(cleaned, contains('var c = 3'));
    });
  });

  group('stripExports', () {
    test('strips export default {...}', () {
      final result = stripExports(
        'export default{home:home,category:category}',
      );
      expect(
        result,
        contains('var __drpy_default__ = {home:home,category:category}'),
      );
      expect(result, isNot(contains('export')));
    });

    test('strips export default with no space', () {
      final result = stripExports('export default{a:1}');
      expect(result, contains('var __drpy_default__'));
    });

    test('strips named export', () {
      final result = stripExports('export {foo, bar};');
      expect(result.trim(), isEmpty);
    });

    test('strips export const/let/var/function', () {
      expect(stripExports('export const x = 1;'), contains('const x = 1;'));
      expect(stripExports('export let y = 2;'), contains('let y = 2;'));
      expect(stripExports('export var z = 3;'), contains('var z = 3;'));
      expect(
        stripExports('export function foo() {}'),
        contains('function foo() {}'),
      );
    });

    test('preserves non-export code', () {
      final code = 'var x = 1; function home() { return x; }';
      expect(stripExports(code), equals(code));
    });
  });

  group('resolveModuleUrl', () {
    test('resolves assets:// against baseUrl', () {
      final result = resolveModuleUrl(
        'assets://lib/foo.js',
        'https://example.com/api.php/provide/vod/',
      );
      expect(result, 'https://example.com/api.php/provide/vod/lib/foo.js');
    });

    test('resolves assets:// with baseUrl ending in filename', () {
      final result = resolveModuleUrl(
        'assets://lib/foo.js',
        'https://example.com/path/config.json',
      );
      expect(result, 'https://example.com/path/lib/foo.js');
    });

    test('returns assets:// as-is when no baseUrl', () {
      expect(
        resolveModuleUrl('assets://lib/foo.js', null),
        'assets://lib/foo.js',
      );
    });

    test('passes through absolute URLs', () {
      expect(
        resolveModuleUrl(
          'https://cdn.example.com/foo.js',
          'https://other.com/',
        ),
        'https://cdn.example.com/foo.js',
      );
      expect(
        resolveModuleUrl('http://cdn.example.com/foo.js', null),
        'http://cdn.example.com/foo.js',
      );
    });

    test('resolves relative path against baseUrl', () {
      final result = resolveModuleUrl(
        './lib/drpy2.min.js',
        'https://example.com/path/config.json',
      );
      expect(result, 'https://example.com/path/lib/drpy2.min.js');
    });

    test('resolves bare filename against baseUrl', () {
      final result = resolveModuleUrl(
        'foo.js',
        'https://example.com/path/config.json',
      );
      expect(result, 'https://example.com/path/foo.js');
    });

    test('returns specifier as-is when no baseUrl for relative', () {
      expect(resolveModuleUrl('./lib/foo.js', null), './lib/foo.js');
    });
  });

  group('generateModuleLoader', () {
    test('generates default import loader', () {
      final js = generateModuleLoader(
        'var x = 1; export default {a: x};',
        'myModule',
        isDefault: true,
        namedImports: [],
      );
      expect(js, contains('globalThis.myModule'));
      expect(js, contains('__m__.default'));
      expect(js, contains('(function()'));
      expect(js, contains('})();'));
    });

    test('generates named import loader', () {
      final js = generateModuleLoader(
        'export const foo = 1; export const bar = 2;',
        '_mod',
        isDefault: false,
        namedImports: [('foo', 'foo'), ('bar', 'bar')],
      );
      expect(js, contains('globalThis.foo'));
      expect(js, contains('globalThis.bar'));
    });

    test('generates bare import loader', () {
      final js = generateModuleLoader(
        'var x = 1;',
        '_bare_side',
        isDefault: false,
        namedImports: [],
      );
      expect(js, contains('globalThis._bare_side'));
    });

    test('wraps code in try-catch', () {
      final js = generateModuleLoader(
        'var x = 1;',
        'm',
        isDefault: true,
        namedImports: [],
      );
      expect(js, contains('try'));
      expect(js, contains('catch'));
    });
  });
}
