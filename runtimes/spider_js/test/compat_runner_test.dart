import 'package:spider_js/src/drpy/compat_runner.dart';
import 'package:test/test.dart';

/// 兼容性测试集运行器。
///
/// 加载 `test/compat/*.json` 下的全部用例，逐条执行 `pdfh`/`pdfa`/`pd`/`pdfl`，
/// 断言全部通过。新增真实源写法时，往对应主题的 JSON 里补一条即可。
///
/// ROADMAP M4 出口标准：「兼容性测试集不少于 100 条用例，全绿」。下面的条数
/// 下限断言就是这条标准的执行体——用例被误删或文件加载不到时会直接红。
void main() {
  final cases = CompatCase.loadFromDirectory('test/compat');

  group('兼容性测试集', () {
    test('用例数满足 M4 出口标准（≥100 条）', () {
      expect(cases.length, greaterThanOrEqualTo(100));
    });

    test('全部用例通过 (${cases.length} 条)', () {
      final (loaded, passed, failed, failures) = runCompatTests(cases);
      expect(loaded.length, passed, reason: failures.join('\n'));
      expect(failed, 0, reason: failures.join('\n'));
    });

    test('用例名不重复', () {
      final names = cases.map((c) => c.name).toList();
      expect(names.toSet().length, names.length);
    });
  });
}
