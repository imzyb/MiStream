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
    super.dispose();
  }

  Future<void> _importFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = '请输入配置地址');
      return;
    }

    setState(() {
      _importing = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(url);
      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();
      final bytes = await response.fold<List<int>>(
        [],
        (prev, chunk) => prev..addAll(chunk),
      );
      client.close();

      await _processImport(bytes);
    } on Object catch (e) {
      setState(() {
        _importing = false;
        _error = '下载失败: $e';
      });
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

  Future<void> _processImport(List<int> bytes) async {
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
      await installer.install(result.valueOrNull!);
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
