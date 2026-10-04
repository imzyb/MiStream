/// 拿**真实 drpy2 源**跑一遍子进程链路。
///
/// 为什么要这个探针：仓库里此前所有「端到端」用的都是自造的 `type0Script`，
/// 真实 drpy2 从没被跑过。而 drpy2 有几个自造脚本永远不会碰到的硬骨头：
/// 4 条**远程 URL** import（含中文标识符 `模板`、副作用导入、命名导入）、
/// 末尾 `export default {...}`、依赖全局 `rule` / `HOST`、以及
/// `req` + `pdfh/pdfa` + `local.*` 一整套宿主 API。
///
/// 本沙箱里 `jihulab.com` 可达，所以能拿一份真源来验收。
///
/// 驱动方式是**进程内**（真 `RuntimeChild` + 真 QuickJS + 真宿主函数），只在
/// 分帧层拦一个点：子进程的所有网络都必须过 `host.fetch`（ADR-001），拦它
/// 一处等于接管全部 HTTP。
///
/// 预取是必须的：子进程协议是**同步**的，宿主回话必须发生在 `write` 回调里，
/// 没法 await。所以先把会用到的 URL 拉下来放内存，再同步喂回去。
///
/// 用法（`runtimes/spider_js` 目录下）：
///   dart run tool/probe_real_drpy.dart
///   dart run tool/probe_real_drpy.dart create-only     # 只发 create
///   dart run tool/probe_real_drpy.dart cycles=5        # 连续试 6 个源，量 RSS
library;

import 'dart:convert';
import 'dart:io';

import 'package:spider_js/src/child/runtime_child.dart';
import 'package:spider_js/src/child/sync_frame_io.dart';
import 'package:spider_js/src/engine/js_runtime.dart';

const String _lib = 'https://jihulab.com/yydfys/yydf/-/raw/main/yydf/lib';

/// 这条源的三个关键 URL（取自 `xiaosa/api.json` 的第一条 type=3 站点）。
const String drpy2Url = '$_lib/drpy2.min.js';
const String doubanUrl = '$_lib/douban.js';
const String configSourceUrl =
    'https://raw.githubusercontent.com/qist/tvbox/refs/heads/master/xiaosa/api.json';

/// drpy2 自己 import 的 4 个依赖，必须能取到，否则模块预取会明确报错。
const List<String> _drpy2Deps = <String>[
  '$_lib/cheerio.min.js',
  '$_lib/crypto-js.js',
  '$_lib/%E6%A8%A1%E6%9D%BF.js', // 模板.js
  '$_lib/gbk.js',
];

int _checks = 0;
int _failures = 0;

/// 落盘追踪。
///
/// 进程被 QuickJS 的 `assert` 打 abort 时，**管道里缓冲的 stdout 全丢**，只剩
/// 一行断言文本。所以关键步骤要同步落盘（flush），否则查不出崩在哪一步。
final File _traceFile = File(
  '${Directory.systemTemp.path}${Platform.pathSeparator}probe_real_drpy.trace',
);

void _trace(String line) {
  try {
    _traceFile.writeAsStringSync(
      '${DateTime.now().toIso8601String()}  $line\n',
      mode: FileMode.append,
      flush: true,
    );
  } on Object {
    // 追踪失败不能影响主流程
  }
}

void check({required bool cond, required String what}) {
  _checks++;
  if (cond) {
    stdout.writeln('  ok    $what');
  } else {
    _failures++;
    stdout.writeln('  FAIL  $what');
  }
}

/// 真网络 GET，跟随重定向，返回 UTF-8 正文；失败返回 null。
Future<String?> _get(String url) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)';
  try {
    final req = await client.getUrl(Uri.parse(url));
    req.followRedirects = true;
    final resp = await req.close().timeout(const Duration(seconds: 30));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      await resp.drain<void>();
      return null;
    }
    return await resp.transform(utf8.decoder).join();
  } on Object catch (e) {
    stderr.writeln('  取 $url 失败: $e');
    return null;
  } finally {
    client.close(force: true);
  }
}

/// 进程内回环：接管子进程的 `host.fetch` 等出站请求。
///
/// `write` 是子进程唯一的出口，每次调用都尝试从累积缓冲里切出完整帧；切到
/// 请求帧就当场生成响应、追加进入站队列。这正是真 `SpiderHost` 做的事，只是
/// 那个在另一个进程里、可以 await。
class _Loopback {
  _Loopback(this.served, List<Map<String, Object?>> inbound) {
    inbound.forEach(_push);
  }

  /// 预取好的 URL → 正文。没命中的 URL 记进 [missed] 并回 404。
  final Map<String, String> served;

  final List<int> _in = <int>[];
  int _cursor = 0;

  final List<int> _outBuf = <int>[];
  int _parsed = 0;

  /// 子进程发出的所有帧（请求），按顺序。
  final List<Map<String, Object?>> outbound = <Map<String, Object?>>[];

  /// 宿主回给子进程的帧，按顺序。
  final List<Map<String, Object?>> responses = <Map<String, Object?>>[];

  /// 子进程回给宿主的帧（`spider.create` / `spider.home` 的结果）。
  final List<Map<String, Object?>> childReplies = <Map<String, Object?>>[];

  /// 子进程请求过、但没被预取的 URL。
  final List<String> missed = <String>[];

  SyncFrameCodec get codec =>
      SyncFrameCodec(readByte: _readByte, write: _write);

  int _readByte() => _cursor < _in.length ? _in[_cursor++] : -1;

  void _write(List<int> bytes) {
    _outBuf.addAll(bytes);
    _pump();
  }

  void _pump() {
    for (;;) {
      final headerEnd = _findHeaderEnd();
      if (headerEnd < 0) return;
      final header = utf8.decode(_outBuf.sublist(_parsed, headerEnd));
      final length = _contentLength(header);
      if (length == null) {
        _parsed = headerEnd + 4;
        continue;
      }
      final bodyStart = headerEnd + 4;
      if (_outBuf.length < bodyStart + length) return;
      final body = utf8.decode(_outBuf.sublist(bodyStart, bodyStart + length));
      _parsed = bodyStart + length;

      final msg = jsonDecode(body) as Map<String, Object?>;
      outbound.add(msg);
      if (msg['method'] is String) {
        _trace('recv ${msg['method']} id=${msg['id']}');
        _respond(msg);
      } else if (msg.containsKey('result') || msg.containsKey('error')) {
        childReplies.add(msg); // 子进程对宿主请求的回话
        _trace(
          'child-reply id=${msg['id']} '
          '${msg.containsKey('error') ? 'ERROR' : 'ok'}',
        );
      }
    }
  }

  int _findHeaderEnd() {
    for (var i = _parsed; i + 3 < _outBuf.length; i++) {
      if (_outBuf[i] == 13 &&
          _outBuf[i + 1] == 10 &&
          _outBuf[i + 2] == 13 &&
          _outBuf[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  static int? _contentLength(String header) {
    for (final line in header.split('\r\n')) {
      final t = line.trim();
      if (t.toLowerCase().startsWith('content-length:')) {
        return int.tryParse(t.substring(t.indexOf(':') + 1).trim());
      }
    }
    return null;
  }

  /// 给子进程的请求帧生成响应。
  void _respond(Map<String, Object?> msg) {
    final method = msg['method'];
    if (method is! String) return; // 子进程对我们的回话，忽略
    final id = msg['id'];
    final params = msg['params'] is Map<String, Object?>
        ? msg['params']! as Map<String, Object?>
        : const <String, Object?>{};

    Object? result;
    Object? error;

    switch (method) {
      case 'host.fetch':
        final url = '${params['url'] ?? ''}';
        final body = served[url] ?? served[_decoded(url)];
        if (body != null) {
          result = <String, Object?>{
            'status': 200,
            'headers': const <String, Object?>{'content-type': 'text/html'},
            'body': body,
            'finalUrl': url,
            'elapsedMs': 0,
          };
        } else {
          missed.add(url);
          result = <String, Object?>{
            'status': 404,
            'headers': const <String, Object?>{},
            'body': '',
            'finalUrl': url,
            'elapsedMs': 0,
          };
        }
      case 'host.env':
        result = <String, Object?>{
          'appVersion': 'dev',
          'platform': 'windows',
          'defaultUA': 'Mozilla/5.0',
          'locale': 'zh-CN',
        };
      case 'host.storage.get':
        result = <String, Object?>{'value': null};
      case 'host.storage.set':
      case 'host.storage.delete':
        result = <String, Object?>{};
      default:
        error = <String, Object?>{'code': -32601, 'message': '未知方法: $method'};
    }

    final frame = <String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      if (error != null) 'error': error else 'result': result,
    };
    responses.add(frame);
    _trace('respond $method → ${error != null ? 'ERROR' : 'ok'}');
    _push(frame);
  }

  void _push(Map<String, Object?> msg) {
    final body = utf8.encode(jsonEncode(msg));
    _in
      ..addAll(utf8.encode('Content-Length: ${body.length}\r\n\r\n'))
      ..addAll(body);
  }
}

/// 百分号解码，失败就原样返回（URL 里混着非法转义时不能炸）。
String _decoded(String url) {
  try {
    return Uri.decodeFull(url);
  } on Object {
    return url;
  }
}

Map<String, Object?> _req(int id, String method, [Map<String, Object?>? p]) =>
    <String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': p ?? const <String, Object?>{},
    };

Future<void> main(List<String> args) async {
  stdout.writeln('=' * 72);
  stdout.writeln('预取真实资源（真网络）');

  final served = <String, String>{};
  for (final url in <String>[drpy2Url, doubanUrl, ..._drpy2Deps]) {
    final body = await _get(url);
    if (body == null) continue;
    // 键归一：drpy2 的 import 里中文是**原样**写的（`.../模板.js`），而我们
    // 手里的常量是百分号编码的。两者指同一个资源，用解码后的形态当键，
    // 免得「明明预取过却 404」。
    served[Uri.decodeFull(url)] = body;
    stdout.writeln(
      '  ok   ${body.length} 字节  ${Uri.decodeFull(url).split('/').last}',
    );
  }
  check(
    cond: served.containsKey(Uri.decodeFull(drpy2Url)),
    what: 'drpy2.min.js 可取到',
  );
  check(
    cond: served.containsKey(Uri.decodeFull(doubanUrl)),
    what: 'douban.js 规则文件可取到',
  );
  for (final dep in _drpy2Deps) {
    check(
      cond: served.containsKey(Uri.decodeFull(dep)),
      what: '依赖可取到：${dep.split('/').last}',
    );
  }
  if (!served.containsKey(Uri.decodeFull(drpy2Url))) {
    stdout.writeln('drpy2 都取不到，后面没意义，退出。');
    stdout.writeln('=== $_checks 项检查，$_failures 项失败 ===');
    exitCode = 1;
    return;
  }

  final drpy2 = served[Uri.decodeFull(drpy2Url)]!;

  stdout.writeln();
  stdout.writeln('=' * 72);
  stdout.writeln('跑真实 drpy2：create → home → destroy → 再 create → home');

  // 二分用开关：`dart run tool/probe_real_drpy.dart create-only`
  // 只发 spider.create，不发 spider.home。
  final createOnly = args.contains('create-only');

  // `cycles=N`：连续试 N+1 个源（每个源 create → home → destroy），用来量「弃用
  // runtime 壳」的代价。默认 1，也就是最上面那条两段序列。
  final cyclesArg = args.firstWhere(
    (a) => a.startsWith('cycles='),
    orElse: () => 'cycles=1',
  );
  final cycles = int.tryParse(cyclesArg.split('=').last) ?? 1;

  Map<String, Object?> createParams(String instanceId) => <String, Object?>{
    'instanceId': instanceId,
    'script': drpy2,
    'config': doubanUrl,
    'baseUrl': drpy2Url,
    'configBaseUrl': configSourceUrl,
  };

  // 第二段起是**「连续试源」**的验收：宿主 `_trySites` 每试一个源就是
  // create → 调用 → destroy 这个节奏，而旧实现每次 destroy 都会
  // `JS_FreeRuntime` / `JS_RunGC`，直接 abort 掉整个共享子进程。
  // 复用 runtime 已被实测否决（见 `_recycle` 注释），这里要验的是「每个源一个
  // 全新 runtime，且旧的那个能安全收掉」。
  var created = 0;
  final inbound = <Map<String, Object?>>[
    _req(1, 'spider.create', createParams('real:1')),
  ];
  var nextId = 2;
  if (!createOnly) {
    for (var k = 1; k <= cycles; k++) {
      inbound
        ..add(
          _req(nextId++, 'spider.home', <String, Object?>{
            'instanceId': 'real:$k',
          }),
        )
        // 与宿主 `_trySites` 一致：一个源试完就销毁，再试下一个。
        ..add(
          _req(nextId++, 'spider.destroy', <String, Object?>{
            'instanceId': 'real:$k',
          }),
        )
        ..add(_req(nextId++, 'spider.create', createParams('real:${k + 1}')));
    }
    inbound.add(
      _req(nextId++, 'spider.home', <String, Object?>{
        'instanceId': 'real:${cycles + 1}',
      }),
    );
    // 宿主换新子进程时发的就是这条通知（见 `SpiderHost._recycleProcess`）。
    // 它是「跑完真实 drpy2 之后进程能干净退出」的验收点：走这条路径退出时
    // 不能出现 QuickJS 的断言 abort。
    inbound.add(<String, Object?>{
      'jsonrpc': '2.0',
      'method': 'runtime.shutdown',
      'params': <String, Object?>{'graceMs': 1000},
    });
  }

  final loop = _Loopback(served, inbound);

  _trace('--- run start ---');
  final rssBefore = ProcessInfo.currentRss;
  final child = RuntimeChild(
    codec: loop.codec,
    createRuntime: (limits) {
      created++;
      return JsRuntime(limits: limits);
    },
  );
  child.run();
  _trace('--- run end ---');
  // 必须显式释放：实例的 HostBridge 持着 NativeCallable，不关掉进程挂着不退。
  child.dispose();
  _trace('--- disposed ---');
  final rssAfter = ProcessInfo.currentRss;

  stdout.writeln();
  stdout.writeln('--- 子进程发出的帧 ---');
  for (final msg in loop.outbound) {
    final method = msg['method'] ?? '(response)';
    final params = msg['params'];
    var brief = '';
    if (params is Map) {
      if (params['url'] != null) {
        brief = ' url=${params['url']}';
      } else if (params['instanceId'] != null) {
        brief = ' instanceId=${params['instanceId']}';
      }
    }
    stdout.writeln('  → $method$brief');
  }

  stdout.writeln();
  stdout.writeln('--- 未被预取、回了 404 的 URL ---');
  for (final url in loop.missed.toSet()) {
    stdout.writeln('  $url');
  }

  stdout.writeln();
  stdout.writeln('--- 宿主给子进程的回话 ---');
  for (final msg in loop.responses) {
    final error = msg['error'];
    if (error != null) {
      stdout.writeln('  ✗ $error');
      continue;
    }
    final result = msg['result'];
    if (result is! Map) {
      stdout.writeln('  · $result');
      continue;
    }
    final status = result['status'];
    if (status != null) {
      stdout.writeln(
        '  fetch → ${result['status']} '
        '${'${result['body'] ?? ''}'.length} 字节  ${result['finalUrl']}',
      );
      continue;
    }
    stdout.writeln('  · $result');
  }

  stdout.writeln();
  stdout.writeln('--- 子进程的回话（我们真正要看的） ---');
  var createOk = false;
  for (final msg in loop.childReplies) {
    final error = msg['error'];
    if (error != null) {
      stdout.writeln('  ✗ ${jsonEncode(error)}');
      continue;
    }
    final result = msg['result'];
    if (result is Map && result['capabilities'] != null) {
      stdout.writeln('  create → capabilities=${result['capabilities']}');
      createOk = true;
      continue;
    }
    if (result is Map && result['class'] is List) {
      // 这一条能把整屏刷满（真实规则带一整套 filters），只报规模。
      final cls = result['class']! as List;
      final flt = result['filters'];
      stdout.writeln(
        '  home → class=${cls.length} 个， '
        'filters=${flt is Map ? '${flt.length} 组' : '无'}，'
        'list=${(result['list'] as List?)?.length ?? 0} 条',
      );
      continue;
    }
    final raw = jsonEncode(result);
    stdout.writeln('  ${raw.length > 300 ? '${raw.substring(0, 300)}…' : raw}');
  }

  check(cond: createOk, what: 'spider.create 成功并报出能力位');
  check(
    cond: loop.childReplies.every((m) => m['error'] == null),
    what: '没有任何一次调用报错',
  );
  final caps = <Object?>{};
  for (final m in loop.childReplies) {
    final r = m['result'];
    if (r is Map && r['capabilities'] is List) {
      caps.addAll(r['capabilities']! as List);
    }
  }
  check(
    cond: caps.containsAll(<String>[
      'home',
      'category',
      'detail',
      'search',
      'play',
    ]),
    what: 'drpy2 的宿主派发入口全部被识别到：$caps',
  );

  // home() 不依赖远端站点——分类来自规则里的 class_name/class_url。所以哪怕
  // 豆瓣 API 挂掉，这一项也应当通过；它证明的是「规则真的被 init 吃进去了」。
  final homeResults = <Map<Object?, Object?>>[];
  for (final m in loop.childReplies) {
    final r = m['result'];
    if (r is Map && r['class'] is List) {
      homeResults.add(r as Map<Object?, Object?>);
    }
  }
  final homeResult = homeResults.isEmpty ? null : homeResults.last;
  final classes = (homeResult?['class'] as List?) ?? const <Object?>[];
  check(
    cond: classes.isNotEmpty,
    what: 'home() 从规则读出了分类：${classes.length} 个',
  );
  if (classes.isNotEmpty) {
    final names = classes
        .take(4)
        .map((c) => c is Map ? '${c['type_name']}(${c['type_id']})' : '$c')
        .join(' / ');
    stdout.writeln('  分类前 4 个：$names …');
  }
  final listLen = (homeResult?['list'] as List?)?.length ?? 0;
  stdout.writeln(
    '  home() 列表条数：$listLen'
    '${listLen == 0 ? '（豆瓣 API 在本机 403，属站点侧限制）' : ''}',
  );

  if (!createOnly) {
    stdout.writeln();
    stdout.writeln('--- 连续试源验收（destroy 后起下一个实例）---');
    final expected = cycles + 1;
    check(
      cond: homeResults.length == expected,
      what: '$expected 个实例都跑出了 home 结果：${homeResults.length} 次',
    );
    if (homeResults.length > 1) {
      final first = (homeResults.first['class']! as List).length;
      final same = homeResults.every(
        (r) => (r['class']! as List).length == first,
      );
      check(cond: same && first > 0, what: '每个源的分类数都一致：$first');
    }
    check(
      cond: created == expected,
      what: '$expected 个源各建一个 runtime（不复用旧壳，实测复用会撞 shape 断言）：建了 $created 个',
    );
    final perCycleKiB = cycles > 0
        ? ((rssAfter - rssBefore) / cycles / 1024).round()
        : 0;
    stdout.writeln(
      '  RSS ${rssBefore ~/ 1024} KiB → ${rssAfter ~/ 1024} KiB '
      '（$cycles 轮 destroy，约 $perCycleKiB KiB/轮）',
    );
  }

  stdout.writeln();
  stdout.writeln('=== $_checks 项检查，$_failures 项失败 ===');
  if (_failures > 0) exitCode = 1;
}
