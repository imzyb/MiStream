/// 路径穿越 guard：插件只能访问沙箱目录内的文件。
library;

/// 检查 [requested] 是否试图逃逸出 [sandboxRoot]。
bool isPathTraversal(String sandboxRoot, String requested) {
  final root = _normalize(sandboxRoot);
  final target = _normalize(requested);
  // 绝对路径且不在 root 下即为逃逸
  if (target.startsWith('/') && !target.startsWith(root)) return true;
  // 相对路径中含 .. 且解析后跳出 root
  final resolved = _resolve(root, target);
  return !resolved.startsWith(root);
}

String _normalize(String p) =>
    p.replaceAll(r'\', '/').replaceAll(RegExp(r'/+'), '/').trim();
String _resolve(String root, String target) {
  if (target.startsWith('/')) return _normalize(target);
  final parts = [...root.split('/'), ...target.split('/')];
  final stack = <String>[];
  for (final part in parts) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (stack.isNotEmpty) stack.removeLast();
    } else {
      stack.add(part);
    }
  }
  return '/${stack.join('/')}';
}
