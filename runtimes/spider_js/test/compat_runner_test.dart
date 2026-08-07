import 'package:spider_js/src/drpy/compat_runner.dart';
import 'package:test/test.dart';

/// 兼容性测试集运行器。
///
/// 加载 `test/compat/*.json` 下的用例，逐条执行 `pdfh`/`pdfa`/`pd`/`pdfl`，
/// 断言全部通过。新增真实源写法时，往 JSON 里补一条用例即可。
void main() {
  final cases = CompatCase.loadFromFile('test/compat/basic_cases.json');

  group('兼容性测试集', () {
    test('全部用例通过 (${cases.length} 条)', () {
      final (loaded, passed, failed, failures) = runCompatTests(cases);
      expect(loaded.length, passed, reason: failures.join('\n'));
      expect(failed, 0, reason: failures.join('\n'));
    });
  });
}
