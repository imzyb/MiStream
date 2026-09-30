/// WCAG 对比度校验。
library;

import 'dart:math';

/// 计算相对亮度与对比度，校验 WCAG AA。
class ContrastChecker {
  /// 相对亮度 0..1（sRGB）。
  ///
  /// ⚠️ **只看 RGB，忽略 alpha。** 这是 WCAG 的定义（相对亮度没有透明度这个
  /// 维度），但也意味着 `ratio()` 的结论**只在两个颜色都不透明时才等于渲染
  /// 结果**。全透明的黑底与不透明的黑底算出来一样，实际一个什么都看不见、
  /// 一个是实心黑。
  ///
  /// 所以「不达标就回退主题包」这道防线必须配合一道不透明性检查
  /// （见 `findTranslucentTokens`）才有意义 —— 2026-09-30 之前缺的正是它，
  /// 于是全透明配色能拿满分通过。
  static double luminance(int argb) {
    double linear(int c) {
      final s = c / 255.0;
      return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4) as double;
    }

    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b);
  }

  /// 对比度 1..21
  static double ratio(int fg, int bg) {
    final l1 = luminance(fg);
    final l2 = luminance(bg);
    final lighter = max(l1, l2);
    final darker = min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// 是否通过 WCAG AA（正常文本 4.5，大字 3.0）
  static bool passesAA(int fg, int bg, {bool largeText = false}) {
    return ratio(fg, bg) >= (largeText ? 3.0 : 4.5);
  }

  /// 校验一组前景/背景对，返回未通过的对。
  static List<String> checkPairs(
    List<(String name, int fg, int bg)> pairs, {
    bool largeText = false,
  }) {
    final fails = <String>[];
    for (final (name, fg, bg) in pairs) {
      if (!passesAA(fg, bg, largeText: largeText)) {
        fails.add('$name ${ratio(fg, bg).toStringAsFixed(2)}');
      }
    }
    return fails;
  }
}
