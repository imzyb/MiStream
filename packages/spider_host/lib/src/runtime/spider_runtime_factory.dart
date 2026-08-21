/// Spider 运行时工厂：根据站点类型创建对应的运行时。
///
/// type=1 (JSON API) → HttpRuntime
/// type=3 (Spider/JS) → SpiderHost (子进程，JS 或 JVM)
///
/// type=3 再细分：
/// - `api` 以 `csp_` 开头 → TVBox csp_ 蜘蛛（jar 里的 Java 类）→ JVM 运行时
/// - 其余 → drpy/QuickJS 脚本 → JS 运行时
library;

import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:spider_host/src/host/host_api.dart';
import 'package:spider_host/src/host/spider_host.dart';
import 'package:spider_host/src/runtime/http_runtime.dart';

/// 运行时类型。
enum SpiderRuntimeType {
  /// HTTP 运行时 (type=1 JSON API)。
  http,

  /// JS 运行时 (type=3 Spider 脚本)。
  js,

  /// 不支持的类型。
  unsupported,
}

/// Spider 运行时接口。
abstract class SpiderRuntime {
  /// 首页内容。
  Future<Result<HttpResponseData, AppError>> home({int page = 1});

  /// 分类列表。
  Future<Result<HttpResponseData, AppError>> category();

  /// 分类详情。
  Future<Result<HttpResponseData, AppError>> categoryDetail({
    required String typeId,
    int page = 1,
  });

  /// 搜索。
  Future<Result<HttpResponseData, AppError>> search({
    required String keyword,
    int page = 1,
  });

  /// 详情。
  Future<Result<HttpResponseData, AppError>> detail({
    required String ids,
  });

  /// 播放地址。
  Future<Result<HttpResponseData, AppError>> play({
    required String flag,
    required String ids,
  });

  /// 释放资源。
  Future<void> dispose();
}

/// HTTP 运行时适配器。
class HttpRuntimeAdapter implements SpiderRuntime {
  /// 构造适配器。
  HttpRuntimeAdapter(this._runtime);

  final HttpRuntime _runtime;

  @override
  Future<Result<HttpResponseData, AppError>> home({int page = 1}) =>
      _runtime.home(page: page);

  @override
  Future<Result<HttpResponseData, AppError>> category() => _runtime.category();

  @override
  Future<Result<HttpResponseData, AppError>> categoryDetail({
    required String typeId,
    int page = 1,
  }) => _runtime.categoryDetail(typeId: typeId, page: page);

  @override
  Future<Result<HttpResponseData, AppError>> search({
    required String keyword,
    int page = 1,
  }) => _runtime.search(keyword: keyword, page: page);

  @override
  Future<Result<HttpResponseData, AppError>> detail({required String ids}) =>
      _runtime.detail(ids: ids);

  @override
  Future<Result<HttpResponseData, AppError>> play({
    required String flag,
    required String ids,
  }) => _runtime.play(flag: flag, ids: ids);

  @override
  Future<void> dispose() async {}
}

/// JS 运行时适配器。
///
/// 通过 SpiderHost 与 JS 运行时子进程通信。
class JsRuntimeAdapter implements SpiderRuntime {
  /// 构造适配器。
  JsRuntimeAdapter(this._host, this._instanceId);

  final SpiderHost _host;
  final String _instanceId;

  @override
  Future<Result<HttpResponseData, AppError>> home({int page = 1}) async {
    final result = await _host.call(
      'spider.home',
      params: {
        'instanceId': _instanceId,
        'args': [page],
      },
    );
    return _parseResult(result);
  }

  @override
  Future<Result<HttpResponseData, AppError>> category() async {
    final result = await _host.call(
      'spider.category',
      params: {'instanceId': _instanceId},
    );
    return _parseResult(result);
  }

  @override
  Future<Result<HttpResponseData, AppError>> categoryDetail({
    required String typeId,
    int page = 1,
  }) async {
    final result = await _host.call(
      'spider.detail',
      params: {
        'instanceId': _instanceId,
        'args': [typeId, page],
      },
    );
    return _parseResult(result);
  }

  @override
  Future<Result<HttpResponseData, AppError>> search({
    required String keyword,
    int page = 1,
  }) async {
    final result = await _host.call(
      'spider.search',
      params: {
        'instanceId': _instanceId,
        'args': [keyword, page],
      },
    );
    return _parseResult(result);
  }

  @override
  Future<Result<HttpResponseData, AppError>> detail({
    required String ids,
  }) async {
    final result = await _host.call(
      'spider.detail',
      params: {
        'instanceId': _instanceId,
        'args': [ids],
      },
    );
    return _parseResult(result);
  }

  @override
  Future<Result<HttpResponseData, AppError>> play({
    required String flag,
    required String ids,
  }) async {
    final result = await _host.call(
      'spider.play',
      params: {
        'instanceId': _instanceId,
        'args': [flag, ids],
      },
    );
    return _parseResult(result);
  }

  Result<HttpResponseData, AppError> _parseResult(
    Result<Object?, AppError> result,
  ) {
    return result.fold(
      (ok) {
        final body = ok is Map<String, Object?>
            ? _jsonEncodeMap(ok)
            : (ok is Map
                  ? _jsonEncodeMap(Map<String, Object?>.from(ok))
                  : ok?.toString() ?? '');
        return Ok(
          HttpResponseData(
            status: 200,
            headers: const {},
            body: body,
            finalUrl: '',
            elapsedMs: 0,
          ),
        );
      },
      (err) => Err(err),
    );
  }

  String _jsonEncodeMap(Map<String, Object?> map) {
    final entries = map.entries
        .map((e) {
          final value = e.value;
          if (value is String) return '"${e.key}": "$value"';
          if (value is num) return '"${e.key}": $value';
          if (value is bool) return '"${e.key}": $value';
          if (value is List) return '"${e.key}": ${_jsonEncodeList(value)}';
          if (value is Map)
            return '"${e.key}": ${_jsonEncodeMap(value.cast<String, Object?>())}';
          return '"${e.key}": null';
        })
        .join(', ');
    return '{$entries}';
  }

  String _jsonEncodeList(List<Object?> list) {
    final items = list
        .map((e) {
          if (e is String) return '"$e"';
          if (e is num) return '$e';
          if (e is bool) return '$e';
          if (e is List) return _jsonEncodeList(e);
          if (e is Map) return _jsonEncodeMap(e.cast<String, Object?>());
          return 'null';
        })
        .join(', ');
    return '[$items]';
  }

  @override
  Future<void> dispose() async {
    await _host.call(
      'spider.destroy',
      params: {'instanceId': _instanceId},
    );
  }
}

/// JVM 运行时适配器。
///
/// 与 [JsRuntimeAdapter] 的差别只在创建实例：JVM 侧 `spider.create` 收
/// `jarPath` / `className` / `extend`（jar 已由工厂下载落地），其余调用与
/// JS 运行时共用同一套 wire 协议（docs/08）。
class JvmRuntimeAdapter implements SpiderRuntime {
  /// 构造适配器。
  JvmRuntimeAdapter(this._host, this._instanceId);

  final SpiderHost _host;
  final String _instanceId;

  @override
  Future<Result<HttpResponseData, AppError>> home({int page = 1}) async {
    final result = await _host.call(
      'spider.home',
      params: {
        'instanceId': _instanceId,
        'args': [page != 1],
      },
    );
    return _parseResult(result);
  }

  @override
  Future<Result<HttpResponseData, AppError>> category() async {
    final result = await _host.call(
      'spider.category',
      params: {'instanceId': _instanceId},
    );
    return _parseResult(result);
  }

  @override
  Future<Result<HttpResponseData, AppError>> categoryDetail({
    required String typeId,
    int page = 1,
  }) async {
    // wire 协议约定：spider.detail 带 [tid, page] 路由到 category
    final result = await _host.call(
      'spider.detail',
      params: {
        'instanceId': _instanceId,
        'args': [typeId, page],
      },
    );
    return _parseResult(result);
  }

  @override
  Future<Result<HttpResponseData, AppError>> search({
    required String keyword,
    int page = 1,
  }) async {
    final result = await _host.call(
      'spider.search',
      params: {
        'instanceId': _instanceId,
        'args': [keyword, page != 1],
      },
    );
    return _parseResult(result);
  }

  @override
  Future<Result<HttpResponseData, AppError>> detail({
    required String ids,
  }) async {
    final result = await _host.call(
      'spider.detail',
      params: {
        'instanceId': _instanceId,
        'args': [ids],
      },
    );
    return _parseResult(result);
  }

  @override
  Future<Result<HttpResponseData, AppError>> play({
    required String flag,
    required String ids,
  }) async {
    final result = await _host.call(
      'spider.play',
      params: {
        'instanceId': _instanceId,
        'args': [flag, ids],
      },
    );
    return _parseResult(result);
  }

  Result<HttpResponseData, AppError> _parseResult(
    Result<Object?, AppError> result,
  ) {
    return result.fold(
      (ok) {
        final body = ok is Map<String, Object?>
            ? _jsonEncodeMap(ok)
            : (ok is Map
                  ? _jsonEncodeMap(Map<String, Object?>.from(ok))
                  : ok?.toString() ?? '');
        return Ok(
          HttpResponseData(
            status: 200,
            headers: const {},
            body: body,
            finalUrl: '',
            elapsedMs: 0,
          ),
        );
      },
      (err) => Err(err),
    );
  }

  String _jsonEncodeMap(Map<String, Object?> map) {
    final entries = map.entries
        .map((e) {
          final value = e.value;
          if (value is String) return '"${e.key}": "$value"';
          if (value is num) return '"${e.key}": $value';
          if (value is bool) return '"${e.key}": $value';
          if (value is List) return '"${e.key}": ${_jsonEncodeList(value)}';
          if (value is Map)
            return '"${e.key}": ${_jsonEncodeMap(value.cast<String, Object?>())}';
          return '"${e.key}": null';
        })
        .join(', ');
    return '{$entries}';
  }

  String _jsonEncodeList(List<Object?> list) {
    final items = list
        .map((e) {
          if (e is String) return '"$e"';
          if (e is num) return '$e';
          if (e is bool) return '$e';
          if (e is List) return _jsonEncodeList(e);
          if (e is Map) return _jsonEncodeMap(e.cast<String, Object?>());
          return 'null';
        })
        .join(', ');
    return '[$items]';
  }

  @override
  Future<void> dispose() async {
    await _host.call(
      'spider.destroy',
      params: {'instanceId': _instanceId},
    );
  }
}

/// JVM 运行时（spider_jvm）的启动配置。
///
/// `java -cp <runtimeJarPath>;<libsDirPath>/* io.mistream.jvm.Main` 拉起子进程，
/// 与 JS 运行时共用 SpiderHost（同一套 LSP 分帧 + JSON-RPC）。
class SpiderJvmConfig {
  /// 构造配置。
  SpiderJvmConfig({
    required this.javaPath,
    required this.runtimeJarPath,
    required this.libsDirPath,
    required this.jarCacheDir,
  });

  /// java 可执行文件路径。
  final String javaPath;

  /// spider_jvm_runtime.jar 路径。
  final String runtimeJarPath;

  /// 运行时第三方库目录（asm/gson/okhttp 等）。
  final String libsDirPath;

  /// 下载的 spider jar 缓存目录。
  final Directory jarCacheDir;

  /// 拼接后的子进程 `-cp` 参数。
  ///
  /// 类路径分隔符是 `;`（Windows）/ `:`（其它）；而目录与通配符 `*` 之间要用
  /// 路径分隔符 `Platform.pathSeparator`（Windows 下是 `\`）。两者必须分开用：
  /// 用 pathSeparator 当类路径分隔符会整段失效，缺目录分隔符则通配符只匹配
  /// 当前目录下名为 `*` 的文件（等于没匹配到任何 jar）。
  String get classpath {
    final cpSep = Platform.isWindows ? ';' : ':';
    return '$runtimeJarPath$cpSep$libsDirPath${Platform.pathSeparator}*';
  }
}

/// Spider 运行时工厂。
///
/// 根据站点类型创建对应的运行时实例。
class SpiderRuntimeFactory {
  /// 构造工厂。
  SpiderRuntimeFactory({
    required this.spiderJsPath,
    required this.hostApi,
    this.jvm,
    this.jvmLauncher,
  });

  /// JS 运行时可执行文件路径（编译后的 spider_js_runtime.exe）。
  final String spiderJsPath;

  /// 宿主 API 实现。
  final HostApi hostApi;

  /// JVM 运行时（spider_jvm）配置；`null` 时 csp_ 站点不可用。
  final SpiderJvmConfig? jvm;

  /// 测试注入：JVM 子进程启动器。默认 [defaultProcessLauncher]。
  final ProcessLauncher? jvmLauncher;

  SpiderHost? _jsHost;
  SpiderHost? _jvmHost;

  /// 获取或创建 JS 运行时宿主。
  Future<SpiderHost> _getJsHost() async {
    if (_jsHost != null && _jsHost!.isReady) return _jsHost!;

    // 优先用独立 exe（编译后），fallback 到 dart run（开发时）。
    // 注意：`.dart` 脚本文件「存在」但不能直接当可执行文件启动，必须走
    // `dart run`；只对编译产物（.exe 等）用直接启动。
    final isDartScript = spiderJsPath.endsWith('.dart');
    final bool useDirectExe =
        !isDartScript && await File(spiderJsPath).exists();

    _jsHost = SpiderHost(
      executable: useDirectExe ? spiderJsPath : Platform.resolvedExecutable,
      arguments: useDirectExe ? <String>[] : ['run', spiderJsPath],
      hostApi: hostApi,
    );

    final result = await _jsHost!.start();
    if (result.isErr) {
      throw StateError('JS 运行时启动失败: ${result.errorOrNull?.message}');
    }

    return _jsHost!;
  }

  /// 获取或创建 JVM 运行时宿主（`java -cp ... io.mistream.jvm.Main`）。
  Future<SpiderHost> _getJvmHost() async {
    final config = jvm;
    if (config == null) {
      throw StateError('JVM 运行时未配置（spider_jvm 未安装）');
    }
    if (_jvmHost != null && _jvmHost!.isReady) return _jvmHost!;

    _jvmHost = SpiderHost(
      executable: config.javaPath,
      arguments: ['-cp', config.classpath, 'io.mistream.jvm.Main'],
      hostApi: hostApi,
      launcher: jvmLauncher,
    );

    final result = await _jvmHost!.start();
    if (result.isErr) {
      throw StateError('JVM 运行时启动失败: ${result.errorOrNull?.message}');
    }

    return _jvmHost!;
  }

  /// 根据站点信息创建运行时。
  ///
  /// [typeCode] 站点类型 (0/1/3)
  /// [api] API 地址或脚本路径
  /// [ext] 扩展参数
  /// [sourceUrl] 配置源 URL（用于解析相对路径，如 `./lib/drpy2.min.js`）
  /// [spiderJarUrl] 配置源根级 `spider` 字段（csp_ 站点的 jar URL）
  /// [spiderJarMd5] jar 的 MD5（配置提供时校验）
  Future<SpiderRuntime> create({
    required int typeCode,
    required String api,
    String? ext,
    String? sourceUrl,
    String? spiderJarUrl,
    String? spiderJarMd5,
  }) async {
    switch (typeCode) {
      case 1:
        // JSON API → HttpRuntime
        return HttpRuntimeAdapter(HttpRuntime(api));

      case 3:
        // csp_ 前缀 → TVBox 蜘蛛 jar（JVM 运行时）
        if (api.startsWith('csp_')) {
          return _createJvmRuntime(
            api: api,
            ext: ext,
            spiderJarUrl: spiderJarUrl,
            spiderJarMd5: spiderJarMd5,
          );
        }
        // 其余 → Spider 脚本 → JS 运行时
        return _createJsRuntime(api: api, ext: ext, sourceUrl: sourceUrl);

      default:
        throw ArgumentError('不支持的站点类型: $typeCode');
    }
  }

  /// 创建 JS 运行时。
  Future<JsRuntimeAdapter> _createJsRuntime({
    required String api,
    String? ext,
    String? sourceUrl,
  }) async {
    final host = await _getJsHost();
    final instanceId = 'spider_${DateTime.now().millisecondsSinceEpoch}';

    // 解析脚本的完整 URL：相对路径相对于 sourceUrl
    final scriptUrl = resolveApiUrl(api, sourceUrl);

    // 读取脚本内容
    final script = await _loadScript(scriptUrl);

    // baseUrl：用于模块解析（assets:// 相对路径基于此）
    final baseUrl = scriptUrl;

    // 配置源根目录：`assets://js/lib/xx.js` 从配置根解析（drpy2.min.js 常放在
    // lib/ 下，而 assets 指向配置根，二者基准不同）。
    final configBaseUrl = resolveConfigBaseUrl(sourceUrl);

    // drpy2 的 config（ext）也可能是相对路径（如 `./js/360影视.js`）：
    // 脚本 init() 拿到 http 开头才会去 fetch，所以相对路径要在这里解析成
    // 完整 URL 再传下去。
    final configUrl = resolveExtUrl(ext, sourceUrl);

    // 创建实例
    final result = await host.call(
      'spider.create',
      params: {
        'instanceId': instanceId,
        'script': script,
        'config': configUrl,
        'baseUrl': baseUrl,
        'configBaseUrl': configBaseUrl,
      },
    );

    if (result.isErr) {
      throw StateError('JS 实例创建失败: ${result.errorOrNull?.message}');
    }

    return JsRuntimeAdapter(host, instanceId);
  }

  /// 创建 JVM 运行时（csp_ 蜘蛛）。
  Future<JvmRuntimeAdapter> _createJvmRuntime({
    required String api,
    required String? spiderJarUrl,
    String? ext,
    String? spiderJarMd5,
  }) async {
    final host = await _getJvmHost();
    final instanceId = 'jvm_${DateTime.now().millisecondsSinceEpoch}';

    final jarPath = await _ensureJar(spiderJarUrl, spiderJarMd5);
    final className = jvmClassName(api);

    // 创建实例。JVM 首次使用某 jar 时要跑完整转换管线（enjarify + dex2jar +
    // ASM 修复 + stub 合成），可能超过默认 15s 请求超时，这里放宽到 5 分钟；
    // 转换结果按 jar MD5 缓存，之后的 create 秒回。
    final result = await host.call(
      'spider.create',
      params: {
        'instanceId': instanceId,
        'jarPath': jarPath,
        'className': className,
        'extend': ?ext,
      },
      timeout: const Duration(minutes: 5),
    );

    if (result.isErr) {
      throw StateError('JVM 实例创建失败: ${result.errorOrNull?.message}');
    }

    return JvmRuntimeAdapter(host, instanceId);
  }

  /// 从 `csp_XXX` 推出 jar 里的类全名。
  ///
  /// `csp_Fan` → `com.github.catvod.spider.Fan`；若 csp_ 后缀本身就是完整
  /// 包名+类名（含点号）则原样使用。
  static String jvmClassName(String api) {
    final rest = api.startsWith('csp_') ? api.substring(4) : api;
    if (rest.contains('.') && !rest.startsWith('.')) return rest;
    return 'com.github.catvod.spider.$rest';
  }

  /// 下载并校验 spider jar 到缓存目录，返回本地路径。
  ///
  /// - 本地路径直接返回（开发/测试用）。
  /// - URL 按 md5（或 URL 哈希）命名缓存；已存在且（无 md5 或校验通过）则复用。
  /// - 提供 md5 时下载后校验，不匹配即删除并报错。
  Future<String> _ensureJar(String? url, String? expectedMd5) async {
    if (url == null || url.isEmpty) {
      throw StateError('csp_ 站点缺少 spider jar URL（配置源未提供 spider 字段）');
    }
    if (!(url.startsWith('http://') || url.startsWith('https://'))) {
      final file = File(url);
      if (file.existsSync()) return file.path;
      throw StateError('spider jar 不存在: $url');
    }
    final config = jvm!;
    final cacheDir = config.jarCacheDir;
    final name = (expectedMd5 != null && expectedMd5.isNotEmpty)
        ? 'spider_${expectedMd5.toLowerCase()}.jar'
        : 'spider_${_hashHex(url)}.jar';
    final target = File('${cacheDir.path}${Platform.pathSeparator}$name');
    if (target.existsSync()) return target.path;

    final client = HttpClient();
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(
            const Duration(seconds: 15),
          );
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        throw StateError('spider jar 下载失败: HTTP ${response.statusCode} ($url)');
      }
      final bytes = await response.fold<List<int>>(
        <int>[],
        (a, b) => a..addAll(b),
      );
      if (expectedMd5 != null && expectedMd5.isNotEmpty) {
        final actual = crypto.md5.convert(bytes).toString();
        if (actual != expectedMd5.toLowerCase()) {
          throw StateError(
            'spider jar MD5 不匹配: 期望 $expectedMd5 实际 $actual ($url)',
          );
        }
      }
      await cacheDir.create(recursive: true);
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } finally {
      client.close();
    }
  }

  static String _hashHex(String s) {
    return crypto.md5.convert(utf8.encode(s)).toString();
  }

  /// 解析 API URL：相对路径相对于 sourceUrl，绝对路径原样返回。
  ///
  /// 用于 type=3 站点的 `api` 字段（如 `./lib/drpy2.min.js`）解析为完整 URL。
  static String resolveApiUrl(String api, String? sourceUrl) {
    if (api.startsWith('http://') || api.startsWith('https://')) return api;
    if (sourceUrl == null || sourceUrl.isEmpty) return api;
    // 相对路径：以 sourceUrl 的目录为基准
    final baseUri = Uri.parse(sourceUrl);
    final resolved = baseUri.resolve(api);
    return resolved.toString();
  }

  /// 解析配置源的基础 URL。
  ///
  /// 返回 sourceUrl 用于 `assets://` 协议解析（资源脚本基于配置根目录）。
  /// sourceUrl 为空时返回空字符串，让下游原样回退。
  static String resolveConfigBaseUrl(String? sourceUrl) => sourceUrl ?? '';

  /// 解析 drpy2 的 config（ext）：相对路径解析为完整 URL，其余原样返回。
  ///
  /// 只有看起来像相对路径（`./`、`../`、`/` 开头或裸文件名）才解析；
  /// 绝对 URL 和 inline 脚本（`var rule = {...}` 之类）保持原样，避免把
  /// 代码当路径拼坏。
  static String? resolveExtUrl(String? ext, String? sourceUrl) {
    if (ext == null || ext.isEmpty) return ext;
    if (ext.startsWith('http://') || ext.startsWith('https://')) return ext;
    if (sourceUrl == null || sourceUrl.isEmpty) return ext;
    final looksRelative =
        ext.startsWith('./') ||
        ext.startsWith('../') ||
        ext.startsWith('/') ||
        (!ext.contains(' ') && !ext.contains('{') && !ext.contains('\n'));
    if (!looksRelative) return ext;
    final baseUri = Uri.parse(sourceUrl);
    return baseUri.resolve(ext).toString();
  }

  /// 加载脚本内容。
  Future<String> _loadScript(String api) async {
    // 如果是 URL，下载（带超时，避免不可达主机挂死）
    if (api.startsWith('http://') || api.startsWith('https://')) {
      final client = HttpClient();
      try {
        final request = await client
            .getUrl(Uri.parse(api))
            .timeout(const Duration(seconds: 10));
        final response = await request.close().timeout(
          const Duration(seconds: 10),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          await response.drain<void>();
          throw StateError('脚本下载失败: HTTP ${response.statusCode} ($api)');
        }
        return await response
            .transform(
              // 脚本必须是 UTF-8：drpy2 等含中文/多字节字符，用系统编码
              // （ANSI/codepage）解码会破坏字节，导致 QuickJS 解析报错。
              utf8.decoder,
            )
            .join();
      } finally {
        client.close();
      }
    }

    // 如果是文件路径，读取
    final file = File(api);
    if (await file.exists()) {
      return file.readAsString();
    }

    // 无法加载：既不是 URL 也不是本地文件
    throw StateError('无法加载脚本: $api（非 URL 且文件不存在）');
  }

  /// 释放资源。
  Future<void> dispose() async {
    await _jsHost?.dispose();
    await _jvmHost?.dispose();
    _jsHost = null;
    _jvmHost = null;
  }
}
