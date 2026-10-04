/// drpy2 模块加载器：解析 import 语句、预取依赖、注入全局变量。
///
/// drpy2.min.js 使用 ES module 语法（`import x from "assets://..."`)，而
/// QuickJS 的全局 eval 不支持 import。策略：
/// 1. 用正则提取所有顶层 import
/// 2. 对每个依赖：解析 URL → host.fetch → 用 Function 包装捕获 exports → 注入全局
/// 3. 从脚本中删除 import 语句
/// 4. 主脚本用全局 eval 执行，所有依赖已在 globalThis 上
library;

/// 从 import 语句中提取的依赖信息。
class ModuleDep {
  /// 构造。
  const ModuleDep({
    required this.specifier,
    required this.varName,
    required this.isDefault,
    required this.isBare,
    required this.namedImports,
  });

  /// 模块标识符（`assets://...` 或相对路径）。
  final String specifier;

  /// 注入到全局的变量名（default import 的名称，或模块文件名）。
  final String varName;

  /// 是否为 default import。
  final bool isDefault;

  /// 是否为 bare import（无绑定，仅副作用）。
  final bool isBare;

  /// 命名 import 的 `[localName, alias]` 对。
  final List<(String, String)> namedImports;
}

/// 从脚本中提取所有 import 语句并返回依赖列表。
///
/// 同时返回删除了 import 语句后的脚本。
(List<ModuleDep> deps, String cleanedScript) parseImports(String script) {
  final deps = <ModuleDep>[];

  // 匹配所有 import 语句。
  // \S+ 匹配任意标识符（含中文如 `模板`，\w 不支持 Unicode）。
  // \s* 处理 minified 代码中 import/from 后无空格的情况。
  final importRe = RegExp(
    r'''\bimport\s*'''
    r'''(?:(\S+)\s+from\s*)?'''
    r'''(?:\{([^}]*)\}\s*from\s*)?'''
    '''["']([^"']+)["']''',
  );

  final cleaned = StringBuffer();
  var pos = 0;

  for (final match in importRe.allMatches(script)) {
    // 跳过 re-export（export ... from "..."）
    final prefix = script.substring(pos, match.start).trimRight();
    if (prefix.endsWith('export') || prefix.endsWith('from')) {
      continue;
    }

    final defaultName = match.group(1);
    final namedGroup = match.group(2);
    final specifier = match.group(3)!;

    // 写入 import 之前的非 import 代码
    cleaned.write(script.substring(pos, match.start));

    final namedImports = <(String, String)>[];
    if (namedGroup != null && namedGroup.isNotEmpty) {
      for (final part in namedGroup.split(',')) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final asParts = trimmed.split(RegExp(r'\s+as\s+'));
        final local = asParts[0].trim();
        final alias = (asParts.length > 1 ? asParts[1] : asParts[0]).trim();
        namedImports.add((local, alias));
      }
    }

    final isDefault = defaultName != null;
    final isBare = !isDefault && namedImports.isEmpty;

    // 生成变量名
    String varName;
    if (isDefault) {
      varName = defaultName;
    } else if (isBare) {
      final parts = specifier.split('/');
      final file = parts.last.replaceAll(RegExp(r'\.\w+$'), '');
      varName = '_bare_$file';
    } else if (namedImports.isNotEmpty) {
      varName = namedImports.first.$2;
    } else {
      varName = '_mod_${deps.length}';
    }

    deps.add(
      ModuleDep(
        specifier: specifier,
        varName: varName,
        isDefault: isDefault,
        isBare: isBare,
        namedImports: namedImports,
      ),
    );

    pos = match.end;
  }

  // 写入最后一个 import 之后的所有代码
  cleaned.write(script.substring(pos));

  return (deps, cleaned.toString());
}

/// 去除 ES module export 语句（全局 eval 不支持 export）。
///
/// drpy2 脚本在末尾有 `export default {...}`，全局模式下不需要。
/// 函数定义（home, category 等）已在 globalThis 上，export 仅是模块系统的约定。
String stripExports(String code) {
  // export default{...} 或 export default expr → var __drpy_default__ = ...
  // 注意 minified 代码中 default 后可能没有空格
  return code
      .replaceAllMapped(
        RegExp(r'''\bexport\s+default\s*'''),
        (m) => 'var __drpy_default__ = ',
      )
      .replaceAllMapped(
        RegExp(r'''\bexport\s*\{[^}]*\};?'''),
        (m) => '',
      )
      .replaceAllMapped(
        RegExp(r'''\bexport\s+(const|let|var|function|class)\s+'''),
        (m) => '${m.group(1)} ',
      );
}

/// 解析模块 URL：把 assets:// 和相对路径转成绝对 URL。
///
/// [baseUrl] 是脚本的完整 URL（如 `https://example.com/lib/drpy2.min.js`），
/// 用于解析相对路径（`./node-rsa.js` → `https://example.com/lib/node-rsa.js`）。
/// [configBaseUrl] 是配置源的基础 URL（如 `https://example.com/`），
/// 用于解析 `assets://` 协议（`assets://js/lib/cheerio.min.js` → `https://example.com/js/lib/cheerio.min.js`）。
/// 两者不同是因为 drpy2.min.js 通常放在 `lib/` 下，而 assets 是对应配置根目录的。
String resolveModuleUrl(
  String specifier,
  String? baseUrl, [
  String? configBaseUrl,
]) {
  if (specifier.startsWith('assets://')) {
    final path = specifier.substring('assets://'.length);
    final effectiveBase = configBaseUrl ?? baseUrl;
    if (effectiveBase != null && effectiveBase.isNotEmpty) {
      final lastSlash = effectiveBase.lastIndexOf('/');
      final base = lastSlash >= 0
          ? effectiveBase.substring(0, lastSlash)
          : effectiveBase;
      return '$base/$path';
    }
    return specifier;
  }
  if (specifier.startsWith('http://') || specifier.startsWith('https://')) {
    return specifier;
  }
  // 相对路径：用 Uri.resolve 正确处理 . 和 ..
  if (baseUrl != null && baseUrl.isNotEmpty) {
    try {
      return Uri.parse(baseUrl).resolve(specifier).toString();
    } on Object {
      // fallback：简单拼接
      final lastSlash = baseUrl.lastIndexOf('/');
      final base = lastSlash >= 0 ? baseUrl.substring(0, lastSlash + 1) : '';
      return '$base$specifier';
    }
  }
  return specifier;
}

/// 判定一段代码是否为 ES module（含 export 语句）。
///
/// 真 ES module 需要把 export 转成赋值并注入绑定；纯脚本/UMD 只需**全局求值**
/// ——脚本自己会把全局名（`CryptoJS`、`pako`…）挂到 globalThis 上。若把后者也
/// 包进函数作用域，顶层 `var`/`this` 全被关在闭包里，外部引用全局名会拿不到。
bool _looksLikeEsModule(String code) {
  return RegExp(
    r'\bexport\s*[({=]|\bexport\s+(?:default|const|let|var|function|class|async)\b',
  ).hasMatch(code);
}

/// 生成 JS 代码：获取模块的 exports 并设置全局变量。
///
/// [code] 是模块源码（已从网络获取）。
/// [varName] 是注入到 globalThis 的变量名。
/// [isDefault] 是否取 .default。
/// [namedImports] 命名导出列表 `[localName, alias]`。
String generateModuleLoader(
  String code,
  String varName, {
  required bool isDefault,
  required List<(String, String)> namedImports,
}) {
  // 纯脚本/UMD：不加包装，直接全局求值，让脚本把自己的全局名挂上 globalThis。
  if (!_looksLikeEsModule(code)) {
    return code;
  }

  final buf = StringBuffer();
  buf.writeln('(function() {');
  buf.writeln('  var __m__ = {};');
  buf.writeln('  var __exports__ = {};');

  // 转换 export 语句为 __m__ 赋值。正则全部允许无空白（minified 写法）：
  //   export default{...}  /  export{a as b,c as d}  /  export const a=1
  final transformed = code
      .replaceAllMapped(
        RegExp(r'export\s+default\s*'),
        (m) => '__m__.default = ',
      )
      .replaceAllMapped(
        RegExp(r'export\s*\{([^}]+)\}'),
        (m) {
          final names = m.group(1)!.split(',');
          return names
              .map((n) {
                final parts = n.trim().split(RegExp(r'\s+as\s+'));
                final local = parts[0].trim();
                final alias = (parts.length > 1 ? parts[1] : parts[0]).trim();
                return '__m__.$alias = $local;';
              })
              .join('\n');
        },
      )
      .replaceAllMapped(
        RegExp(r'export\s+function\s+([A-Za-z_$][\w$]*)'),
        (m) => '__m__.${m.group(1)} = function ',
      )
      .replaceAllMapped(
        RegExp(r'export\s+class\s+([A-Za-z_$][\w$]*)'),
        (m) => '__m__.${m.group(1)} = class ',
      )
      .replaceAllMapped(
        RegExp(r'export\s+(?:const|let|var)\s+'),
        (m) => '__m__.',
      );

  buf.writeln('  try {');
  buf.writeln('    (function(exports, module) {');
  buf.writeln('      $transformed');
  buf.writeln('    })(__exports__, { exports: __exports__ });');
  buf.writeln('  } catch(e) { console.error("模块加载失败: " + e.message); }');

  if (isDefault) {
    buf.writeln(
      '  globalThis.$varName = __m__.default !== undefined ? __m__.default : __exports__;',
    );
  } else {
    for (final (local, alias) in namedImports) {
      buf.writeln(
        '  globalThis.$alias = __m__.$local !== undefined ? __m__.$local : __exports__.$local;',
      );
    }
    if (namedImports.isEmpty) {
      buf.writeln('  globalThis.$varName = __m__;');
    }
  }

  buf.writeln('})();');
  return buf.toString();
}
