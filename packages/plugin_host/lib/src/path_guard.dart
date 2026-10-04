/// 路径穿越 guard：插件只能访问沙箱目录内的文件。
///
/// **这是字符串层的防线。** 它能拦住 `..`、绝对路径、盘符跳转、兄弟目录这些
/// 形态，但看不出符号链接 —— 沙箱里一个指向外部的 symlink 在字符串上完全合法。
/// 所以真实 IO 之前仍应做二次校验（`File.resolveSymbolicLinks` 后再比一次）。
///
/// 判断一律是**逐段比较**，不是字符串前缀比较。这一点是整个文件的核心：
/// `'/sandbox/plugin1'` 确实是 `'/sandbox/plugin10'` 的字符串前缀，但两者是
/// 无关目录 —— 前缀比较会把「去兄弟目录」判成「在沙箱内」。
library;

import 'dart:io';

/// 检查 [requested] 是否试图逃逸出 [sandboxRoot]。
///
/// - 相对路径按 [sandboxRoot] 解析；绝对路径（`/x` 或 `C:\x`）从根解析
/// - `..` 会被**真正消解**，所以「先进入再退出」的形态（`/sandbox/p1/../../etc`）
///   也拦得住
/// - `\` 与 `/` 同等对待（插件在 Windows 上两种都可能给）
/// - 无法解析的输入一律**拒绝**（返回 `true`）—— 判不准就挡，不放开
///
/// [caseSensitive] 默认按平台推断（Windows 不敏感）。显式传入主要用于测试
/// 两种平台语义。
bool isPathTraversal(
  String sandboxRoot,
  String requested, {
  bool? caseSensitive,
}) {
  final sensitive = caseSensitive ?? !Platform.isWindows;
  final root = _resolveSegments(sandboxRoot);
  if (root == null) return true;
  final target = _resolveSegments(requested, base: root);
  if (target == null) return true;

  // 目标比沙箱根还浅，必然在外面（例如 requested 是 '..'）。
  if (target.length < root.length) return true;
  for (var i = 0; i < root.length; i++) {
    if (!_sameSegment(root[i], target[i], sensitive)) return true;
  }
  return false;
}

/// 把路径解析成段列表。首元素是根标识（`/` 或 `C:`），其后是目录段。
///
/// [base] 非空时，相对路径从它开始解析；为空时相对路径无法定位，返回 `null`。
List<String>? _resolveSegments(String path, {List<String>? base}) {
  final normalized = path.replaceAll(r'\', '/');
  final segments = <String>[];
  var index = 0;

  if (RegExp(r'^[A-Za-z]:').hasMatch(normalized)) {
    segments.add(normalized.substring(0, 2));
    index = 2;
  } else if (normalized.startsWith('/')) {
    segments.add('/');
    index = 1;
  } else {
    if (base == null) return null;
    segments.addAll(base);
  }

  for (final part in normalized.substring(index).split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      // 弹到根就停：再往上没有意义，也不能把根标识弹掉（弹掉的话
      // `/../../etc` 会变成 `etc`，反而看不出它已经跑到根外了）。
      if (segments.length > 1) segments.removeLast();
      continue;
    }
    segments.add(part);
  }
  return segments;
}

bool _sameSegment(String a, String b, bool caseSensitive) =>
    caseSensitive ? a == b : a.toLowerCase() == b.toLowerCase();
