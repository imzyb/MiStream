/// 首次启动引导页：导入配置源。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core_config/core_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mistream/app/app.dart';
import 'package:mistream/app/router.dart';
import 'package:punycoder/punycoder.dart';

/// 首次启动引导页。
///
/// 展示三种导入方式：粘贴 URL、粘贴 Base64、从文件导入。
/// 导入成功后将配置解析并写入数据库，跳转到首页。
class OnboardingPage extends StatefulWidget {
  /// 构造引导页。
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _urlController = TextEditingController();
  final _base64Controller = TextEditingController();
  bool _importing = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _base64Controller.dispose();
    _httpClient?.close();
    super.dispose();
  }

  Future<void> _importFromUrl() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() => _error = '请输入配置地址');
      return;
    }

    setState(() {
      _importing = true;
      _error = null;
    });

    // TVBox 订阅站常按 UA 分流：认 okhttp 才给配置，浏览器 UA 一律 302 到
    // 首页。所以先用客户端形态的 UA 试，拿到网页再退到浏览器 UA 试一次——
    // 两类站点都覆盖到，且不必让用户去猜该用哪个。
    final first = await _importWithUserAgent(rawUrl, kConfigFetchUserAgent);
    if (first != _ImportAttempt.notConfig) return;
    if (!mounted) return;
    await _importWithUserAgent(rawUrl, kConfigFetchBrowserUserAgent);
  }

  /// 用指定 [userAgent] 走一次完整的「拉取 → 识别 → 导入」。
  ///
  /// 返回值告诉调用方要不要换 UA 再试一次：拿到网页/图片这类**不是配置**
  /// 的内容时返回 [_ImportAttempt.notConfig]，其余情况（成功或已给出明确
  /// 错误）都返回 [_ImportAttempt.done]，由本方法负责把错误显示出去。
  Future<_ImportAttempt> _importWithUserAgent(
    String rawUrl,
    String userAgent,
  ) async {
    try {
      // 处理中文域名 (IDN): 将 Unicode 域名转为 punycode，保留路径原样
      final normalizedUrl = _normalizeUrl(rawUrl);
      final bytes = await _fetchWithRedirects(
        normalizedUrl,
        userAgent: userAgent,
      );
      if (bytes == null) return _ImportAttempt.done; // error already shown

      // 检查内容类型：跳过图片等二进制文件
      final contentType = _lastContentType ?? '';
      if (contentType.contains('image/') ||
          contentType.contains('audio/') ||
          contentType.contains('video/')) {
        setState(() {
          _importing = false;
          _error =
              '该地址返回的是${contentType.split('/').first}文件，不是配置。\n'
              '${_diagnosticSuffix()}';
        });
        return _ImportAttempt.notConfig;
      }

      // 检查是否为 HTML 页面
      final preview = utf8
          .decode(bytes.take(200).toList(), allowMalformed: true)
          .trim();
      if (preview.startsWith('<!DOCTYPE') ||
          preview.startsWith('<html') ||
          preview.startsWith('<HTML') ||
          preview.startsWith('<!doctype')) {
        // 尝试从 HTML 中提取可用的配置链接
        final html = utf8.decode(bytes, allowMalformed: true);
        final suggestions = _extractConfigUrls(html);
        if (suggestions.isNotEmpty && mounted) {
          setState(() => _importing = false);
          await _showConfigSuggestions(suggestions);
          return _ImportAttempt.done;
        }
        setState(() {
          _importing = false;
          _error =
              '该地址返回的是 HTML 页面，不是 JSON 配置。\n'
              '${_diagnosticSuffix()}';
        });
        return _ImportAttempt.notConfig;
      }

      // 尝试解析 JSON
      final text = utf8.decode(bytes, allowMalformed: true);
      try {
        jsonDecode(text);
      } on FormatException {
        // 尝试 Base64 解码
        try {
          final decoded = base64.decode(text.trim());
          final decodedText = utf8.decode(decoded, allowMalformed: true);
          jsonDecode(decodedText);
          // Base64 解码成功，用解码后的字节
          await _processImport(decoded, sourceUrl: normalizedUrl);
          return _ImportAttempt.done;
        } on Object {
          setState(() {
            _importing = false;
            _error = '该地址返回的内容不是有效的 JSON 格式';
          });
          return _ImportAttempt.done;
        }
      }

      await _processImport(bytes, sourceUrl: normalizedUrl);
      return _ImportAttempt.done;
    } on TimeoutException {
      setState(() {
        _importing = false;
        _error = '下载超时，请检查网络连接';
      });
      return _ImportAttempt.done;
    } on Object catch (e) {
      setState(() {
        _importing = false;
        _error = '下载失败: $e';
      });
      return _ImportAttempt.done;
    }
  }

  /// 把「实际请求链」拼成一行诊断后缀，附在失败文案后面。
  ///
  /// 地址填对却被重定向到首页时，这一行是唯一能说明问题的证据——没有它，
  /// 「返回 HTML」看起来就像地址写错了。
  String _diagnosticSuffix() {
    final parts = <String>[
      if (_lastContentType != null && _lastContentType!.isNotEmpty)
        _lastContentType!,
      'UA: $_lastUserAgent',
    ];
    if (_redirectChain.length > 1) {
      parts.add('重定向: ${_redirectChain.join(' → ')}');
    }
    return parts.join('；');
  }

  HttpClient? _httpClient;
  String? _lastContentType;

  /// 本次实际使用的 UA，失败时拼进诊断信息。
  String _lastUserAgent = '';

  /// 本次请求走过的完整 URL 链（首个元素是起始地址）。
  ///
  /// 「地址填对了却被踢到首页」这种失败，只有把链打出来才看得懂。
  List<String> _redirectChain = <String>[];

  HttpClient get client =>
      _httpClient ??= HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;

  /// 带重定向和 JS redirect 跟随的 HTTP GET。
  Future<List<int>?> _fetchWithRedirects(
    String startUrl, {
    required String userAgent,
    int maxRedirects = 3,
  }) async {
    _lastContentType = null;
    _lastUserAgent = userAgent;
    _redirectChain = <String>[startUrl];
    var url = startUrl;
    for (var i = 0; i <= maxRedirects; i++) {
      final normalizedUrl = _normalizeUrl(url);
      final uri = Uri.parse(normalizedUrl);
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', userAgent);
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );

      _lastContentType = response.headers.value('content-type') ?? '';

      // HTTP 重定向
      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location = response.headers.value('location');
        if (location != null) {
          await response.drain<void>();
          // Location 可能是相对地址，必须按当前 URL 解析后再用。
          url = uri.resolve(location).toString();
          _redirectChain.add(url);
          continue;
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        setState(() {
          _importing = false;
          _error = '下载失败: HTTP ${response.statusCode}；${_diagnosticSuffix()}';
        });
        return null;
      }

      final bytes = await response.fold<List<int>>(
        [],
        (prev, chunk) => prev..addAll(chunk),
      );

      // 检查 JS 重定向: window.location.replace('...')
      final text = utf8.decode(bytes, allowMalformed: true);
      final jsRedirect = _extractJsRedirect(text);
      if (jsRedirect != null) {
        // 如果是相对路径，拼接为绝对路径
        if (jsRedirect.startsWith('/')) {
          final baseUri = Uri.parse(url);
          url = '${baseUri.scheme}://${baseUri.host}$jsRedirect';
        } else if (!jsRedirect.startsWith('http')) {
          final baseUri = Uri.parse(url);
          url = '${baseUri.scheme}://${baseUri.host}/$jsRedirect';
        } else {
          url = jsRedirect;
        }
        _redirectChain.add(url);
        continue;
      }

      return bytes;
    }

    setState(() {
      _importing = false;
      _error = '重定向次数过多；${_diagnosticSuffix()}';
    });
    return null;
  }

  /// 从 HTML 中提取 JS 重定向 URL。
  String? _extractJsRedirect(String html) {
    // window.location.replace('...')
    final match = RegExp(
      r'''window\.location\.replace\s*\(\s*['"]([^'"]+)['"]''',
    ).firstMatch(html);
    if (match != null) return match.group(1);

    // window.location.href = '...'
    final match2 = RegExp(
      r'''window\.location\.href\s*=\s*['"]([^'"]+)['"]''',
    ).firstMatch(html);
    if (match2 != null) return match2.group(1);

    // window.location = '...'
    final match3 = RegExp(
      r'''window\.location\s*=\s*['"]([^'"]+)['"]''',
    ).firstMatch(html);
    if (match3 != null) return match3.group(1);

    return null;
  }

  /// 从 HTML 页面中提取配置链接。
  List<Map<String, String>> _extractConfigUrls(String html) {
    final results = <Map<String, String>>[];
    // 匹配 data-clipboard-text="..." 中的 URL
    final regex = RegExp('data-clipboard-text="([^"]+)"');
    for (final match in regex.allMatches(html)) {
      final url = match.group(1)!;
      // 只保留可能是配置的链接（.json 或以 / 结尾的 API）
      if (url.endsWith('.json') || url.endsWith('/')) {
        // 从同级 <span> 中提取名称
        final labelMatch = RegExp(
          r'data-clipboard-text="${RegExp.escape(url)}"[^>]*>.*?<span>([^<]+)</span>',
          dotAll: true,
        ).firstMatch(html);
        final label = labelMatch?.group(1)?.trim() ?? url;
        results.add({'label': label, 'url': url});
      }
    }
    return results;
  }

  /// 显示配置链接建议对话框。
  Future<void> _showConfigSuggestions(
    List<Map<String, String>> suggestions,
  ) async {
    if (!mounted) return;
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('发现以下配置链接'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: suggestions.length,
            itemBuilder: (ctx, i) {
              final s = suggestions[i];
              return ListTile(
                title: Text(s['label']!),
                subtitle: Text(
                  s['url']!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                dense: true,
                onTap: () => Navigator.of(ctx).pop(s['url']),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (chosen != null && mounted) {
      _urlController.text = chosen;
      await _importFromUrl();
    }
  }

  /// 规范化 URL，将中文域名转为 punycode 格式。
  String _normalizeUrl(String url) {
    final schemeEnd = url.indexOf('://');
    if (schemeEnd == -1) return url;

    final scheme = url.substring(0, schemeEnd + 3);
    final rest = url.substring(schemeEnd + 3);

    // 找到路径开始的位置
    final pathStart = rest.indexOf('/');
    final domainPart = pathStart == -1 ? rest : rest.substring(0, pathStart);
    final pathPart = pathStart == -1 ? '' : rest.substring(pathStart);

    // 检查域名是否包含非 ASCII 字符
    if (!domainPart.runes.any((r) => r > 127)) {
      return url;
    }

    // 使用 punycoder 将域名转为 punycode (ASCII)
    try {
      final asciiDomain = domainToAscii(domainPart);
      return '$scheme$asciiDomain$pathPart';
    } on Object {
      return url;
    }
  }

  Future<void> _importFromBase64() async {
    final text = _base64Controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '请输入 Base64 配置');
      return;
    }

    setState(() {
      _importing = true;
      _error = null;
    });

    try {
      final bytes = base64.decode(text);
      await _processImport(bytes);
    } on Object catch (e) {
      setState(() {
        _importing = false;
        _error = '解码失败: $e';
      });
    }
  }

  Future<void> _processImport(List<int> bytes, {String? sourceUrl}) async {
    final result = ConfigImportService.import(bytes);
    if (result.isErr) {
      setState(() {
        _importing = false;
        _error = result.errorOrNull!.message;
      });
      return;
    }

    final installer = AppScope.of(context).configInstaller;
    final done = OnboardingScope.of(context);

    try {
      await installer.install(result.valueOrNull!, sourceUrl: sourceUrl);
      // 翻转标记即触发 redirect 重算，把用户带去首页——不再手工 context.go，
      // 免得「标记没写成但页面已经跳走」。
      done.value = true;
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _importing = false;
          _error = '保存失败: $e';
        });
      }
    }
  }

  /// 跳过导入：只置引导完成标记，之后可在设置里补配置。
  Future<void> _skip() async {
    final installer = AppScope.of(context).configInstaller;
    final done = OnboardingScope.of(context);
    try {
      await installer.markOnboardingDone();
      done.value = true;
    } on Object catch (e) {
      if (mounted) setState(() => _error = '保存失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 48),
                // Logo
                Icon(
                  Icons.play_circle_fill,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '欢迎使用 MiStream',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '请导入 TVBox 配置以开始使用',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 48),

                // 方式一：URL
                Text(
                  '方式一：粘贴配置地址',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          hintText: 'https://example.com/tvbox.json',
                          isDense: true,
                        ),
                        onSubmitted: (_) => unawaited(_importFromUrl()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _importing
                          ? null
                          : () => unawaited(_importFromUrl()),
                      icon: _importing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 方式二：Base64
                Text(
                  '方式二：粘贴 Base64 配置',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _base64Controller,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '粘贴 Base64 编码的配置内容...',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: _importing
                        ? null
                        : () => unawaited(_importFromBase64()),
                    child: const Text('导入'),
                  ),
                ),
                const SizedBox(height: 24),

                // 方式三：从剪贴板粘贴
                Text(
                  '方式三：从剪贴板粘贴',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _importing
                        ? null
                        : () => unawaited(_importFromClipboard()),
                    icon: const Icon(Icons.content_paste),
                    label: const Text('粘贴并导入'),
                  ),
                ),

                // 错误提示
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.onErrorContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // 跳过
                TextButton(
                  onPressed: _importing ? null : () => unawaited(_skip()),
                  child: const Text('跳过，稍后配置'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _importFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) {
        setState(() => _error = '剪贴板为空');
        return;
      }

      // 尝试 URL
      if (text.startsWith('http://') || text.startsWith('https://')) {
        _urlController.text = text;
        await _importFromUrl();
        return;
      }

      // 尝试 Base64
      _base64Controller.text = text;
      await _importFromBase64();
    } on Object catch (e) {
      setState(() => _error = '读取剪贴板失败: $e');
    }
  }
}

/// 一次导入尝试的结论。
enum _ImportAttempt {
  /// 已成功，或已给出明确错误（错误已显示在界面上）。
  done,

  /// 拿到的是网页/图片这类「不是配置」的内容，值得换个 UA 再试一次。
  notConfig,
}
