/// 定位「dispose 期间 QuickJS 断言 abort」的最小复现。
///
/// 现象：`tool/probe_real_drpy.dart` 跑真实 drpy2 时，约 50% 的进程会在
/// `child.run()` 返回**之后**（即 `dispose()` 里）被
/// `Assertion failed: i != 0, file quickjs.c, line 3394` 打 abort。
///
/// 进程 abort 会丢掉缓冲的 stdout，所以进度必须同步落盘。
///
/// 用法（`runtimes/spider_js` 目录下）：
///   dart run tool/repro_dispose.dart <mode> [次数] [脚本路径]
///
/// mode：
///   empty   只求值一个无关紧要的表达式
///   script  求值整份真实 drpy2 源码（不装宿主函数）
///   bridge  装一个桥函数（NativeCallable）后再求值
///   await   走 `_wrap` + 微任务泵的 async IIFE
///   esm     用 `generateModuleLoader` 求值一份 ESM 依赖
///   full    复刻探针的 create：桥 + 4 个依赖 + drpy2 + async init
library;

import 'dart:convert';
import 'dart:io';

import 'package:spider_js/spider_js.dart';
import 'package:spider_js/src/child/module_loader.dart';

final File _trace = File(
  '${Directory.systemTemp.path}${Platform.pathSeparator}repro_dispose.trace',
);

void tr(String s) {
  _trace.writeAsStringSync('$s\n', mode: FileMode.append, flush: true);
}

const String _dir = r'C:\Users\Administrator\AppData\Local\Temp\real_drpy\';
const String _defaultScript = '${_dir}drpy2.min.js';

/// drpy2 的 4 个依赖（本地已下载的同名文件）。
const Map<String, String> _deps = <String, String>{
  'https://x/cheerio.min.js': 'cheerio.min.js',
  'https://x/crypto-js.js': 'crypto-js.js',
  'https://x/模板.js': 'muban.js',
  'https://x/gbk.js': 'gbk.js',
};

void main(List<String> args) {
  final mode = args.isNotEmpty ? args[0] : 'empty';
  final times = args.length > 1 ? int.parse(args[1]) : 5;
  final scriptPath = args.length > 2 ? args[2] : _defaultScript;
  final skipCaps = args.contains('nocaps');
  final skipBase = args.contains('nobase');
  final skipInit = args.contains('noinit');
  final skipHome = args.contains('nohome');
  // 对照实验：限值装的是「中断器 + 内存上限 + 栈上限」，逐个摘掉看谁与断言相关。
  final lim = args.firstWhere(
    (a) => a.startsWith('lim='),
    orElse: () => 'lim=default',
  );
  final limits = switch (lim) {
    'lim=none' => const JsRuntimeLimits.unlimited(),
    'lim=nomem' => const JsRuntimeLimits(memoryBytes: 0),
    'lim=notimeout' => const JsRuntimeLimits(evalTimeout: Duration.zero),
    'lim=nostack' => const JsRuntimeLimits(stackBytes: 0),
    // 只开一项，用来判断哪一项**单独**就足以触发。
    'lim=onlymem' => const JsRuntimeLimits(
      evalTimeout: Duration.zero,
      stackBytes: 0,
    ),
    'lim=onlytime' => const JsRuntimeLimits(memoryBytes: 0, stackBytes: 0),
    'lim=onlystack' => const JsRuntimeLimits(
      evalTimeout: Duration.zero,
      memoryBytes: 0,
    ),
    // 加大内存上限：GC 频率随之下降，用来验证「内存上限→GC 频率」这条线索。
    'lim=bigmem' => const JsRuntimeLimits(memoryBytes: 512 * 1024 * 1024),
    'lim=mem128' => const JsRuntimeLimits(memoryBytes: 128 * 1024 * 1024),
    'lim=mem256' => const JsRuntimeLimits(memoryBytes: 256 * 1024 * 1024),
    'lim=mem32' => const JsRuntimeLimits(memoryBytes: 32 * 1024 * 1024),
    _ => const JsRuntimeLimits(),
  };

  final drpy2 = mode == 'empty' ? '' : File(scriptPath).readAsStringSync();
  tr('=== mode=$mode times=$times script=${drpy2.length} 字节 ===');
  tr('isQuickJSAvailable=$isQuickJSAvailable supportsJobPump=$supportsJobPump');

  for (var i = 0; i < times; i++) {
    tr('iter $i: new');
    final rt = JsRuntime(limits: limits);
    if (!rt.init()) {
      tr('iter $i: init 失败 ${rt.lastError}');
      return;
    }
    tr('iter $i: init ok, bridge=${rt.isHostBridgeAvailable}');

    switch (mode) {
      case 'empty':
        rt.eval('var a = 1; function f() { return 2; }');
      case 'script':
        rt.eval(drpy2);
      case 'bridge':
        rt.bridge.register('noop', (a) => 'ok');
        rt.eval(drpy2);
      case 'await':
        rt.eval('(async function () { return 1; })()');
      case 'esm':
        final code = File('${_dir}muban.js').readAsStringSync();
        rt.eval(
          generateModuleLoader(
            code,
            '模板',
            isDefault: true,
            namedImports: const <(String, String)>[],
          ),
        );
      case 'deps':
        // 只装 4 个依赖模块，不跑 drpy2。
        for (final entry in _deps.entries) {
          final code = File('${_dir}${entry.value}').readAsStringSync();
          rt.eval(
            generateModuleLoader(
              code,
              entry.key.endsWith('模板.js') ? '模板' : 'x',
              isDefault: true,
              namedImports: const <(String, String)>[],
            ),
          );
          tr('iter $i: dep ${entry.value} failure=${rt.lastFailure}');
        }
      case 'full':
        // 与 RuntimeChild._create 对齐：4 个桥函数 + setBaseUrl + 能力位探测。
        rt.bridge.register(
          'req',
          (a) => <String, Object?>{
            'content': '<html><body><div class="list"></div></body></html>',
            'headers': const <String, Object?>{},
            'code': 200,
            'url': 'https://frodo.douban.com/',
          },
        );
        rt.bridge.register('local.get', (a) => null);
        rt.bridge.register('local.set', (a) => null);
        rt.bridge.register('local.delete', (a) => null);
        if (!skipBase) {
          rt.setBaseUrl(
            'https://jihulab.com/yydfys/yydf/-/raw/main/yydf/lib/drpy2.min.js',
          );
        }
        for (final entry in _deps.entries) {
          final code = File('${_dir}${entry.value}').readAsStringSync();
          final dep = parseImports(
            'import ${entry.key.endsWith('模板.js') ? '模板' : 'x'} '
            'from "${entry.key}"',
          ).$1.single;
          rt.eval(
            generateModuleLoader(
              code,
              dep.varName,
              isDefault: dep.isDefault,
              namedImports: dep.namedImports,
            ),
          );
          tr('iter $i: dep ${entry.value} loaded, failure=${rt.lastFailure}');
        }
        final (deps, cleaned) = parseImports(drpy2);
        tr('iter $i: drpy2 imports=${deps.map((d) => d.varName).toList()}');
        rt.eval(stripExports(cleaned));
        // RuntimeChild._capabilitiesOf 的那条探测表达式。
        if (!skipCaps)
          rt.eval(
            '[typeof home === "function" ? "home" : "",'
            'typeof category === "function" ? "category" : "",'
            'typeof detail === "function" ? "detail" : "",'
            'typeof search === "function" ? "search" : "",'
            'typeof play === "function" ? "play" : ""].filter(Boolean).join(",")',
          );
        tr('iter $i: caps done, failure=${rt.lastFailure}');
        if (skipInit) break;
        // 规则文件按**正文**传：drpy2 的 init 见到非 http 字符串会直接 eval 它。
        final ruleSrc = File('${_dir}douban.js').readAsStringSync();
        rt.eval(
          '(async function () { '
          'if (typeof init !== "function") return null; '
          'await init(${jsonEncode(ruleSrc)}); '
          'return null; })()',
        );
        tr('iter $i: init done, failure=${rt.lastFailure}');
        if (skipHome) break;
        rt.eval(
          '(async function () { '
          'if (typeof home !== "function") return null; '
          'var __o = {}; '
          'var __h = await home(); '
          'if (__h) __o = Object.assign(__o, '
          '  typeof __h === "string" ? JSON.parse(__h) : __h); '
          'if (typeof homeVod === "function") { '
          'var __v = await homeVod(); '
          'if (__v) __o = Object.assign(__o, '
          '  typeof __v === "string" ? JSON.parse(__v) : __v); '
          '} '
          'return JSON.stringify(__o); })()',
        );
        tr('iter $i: home done, failure=${rt.lastFailure}');
      default:
        tr('未知 mode: $mode');
        return;
    }
    tr('iter $i: eval done, failure=${rt.lastFailure}');

    rt.dispose();
    tr('iter $i: disposed');
  }
  tr('ALL DONE');
}
