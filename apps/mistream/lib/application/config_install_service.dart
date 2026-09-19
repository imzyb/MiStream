/// 配置安装服务：把解析好的 TVBox 配置落库，并置引导完成标记。
///
/// 解码与解析复用 `core_config` 的 `ConfigImportService.import`（纯函数，
/// 不碰库）；本服务只负责持久化，这样 Presentation 层就不必直连 `storage`
/// （`docs/10` §3.3，由 `tools/arch_check` 强制）。
library;

import 'dart:io';

import 'package:core_config/core_config.dart';
import 'package:core_domain/core_domain.dart';
import 'package:punycoder/punycoder.dart';
import 'package:storage/storage.dart';

/// 将配置 URL 中的 Unicode 域名规范化为 ASCII/Punycode。
///
/// 保留 scheme、端口、查询参数和路径；无效或无法转换时返回原值，
/// 交由 HTTP 层返回可读错误。
String normalizeConfigUrl(String rawUrl) {
  final value = rawUrl.trim();
  final schemeEnd = value.indexOf('://');
  if (schemeEnd < 0) return value;

  final prefix = value.substring(0, schemeEnd + 3);
  final rest = value.substring(schemeEnd + 3);
  final authorityEnd = RegExp(r'[/\\?#]').firstMatch(rest)?.start;
  final authority = authorityEnd == null
      ? rest
      : rest.substring(0, authorityEnd);
  final suffix = authorityEnd == null ? '' : rest.substring(authorityEnd);
  final hostStart = authority.lastIndexOf('@') + 1;
  final hostPort = authority.substring(hostStart);
  final colon = hostPort.lastIndexOf(':');
  final host = colon > 0 ? hostPort.substring(0, colon) : hostPort;
  if (!host.runes.any((rune) => rune > 0x7f)) return value;

  try {
    final asciiHost = domainToAscii(host);
    final authorityPrefix = authority.substring(0, hostStart);
    final port = colon > 0 ? hostPort.substring(colon) : '';
    return '$prefix$authorityPrefix$asciiHost$port$suffix';
  } on Object {
    return value;
  }
}

/// 引导完成标记的设置键。
///
/// 唯一定义处——之前引导页与启动入口各写各的字面量，很容易写歪。
final SettingKey<bool> kOnboardingDoneKey = SettingKey.boolKey(
  'onboarding_done',
);

/// 配置安装服务。
class ConfigInstallService {
  /// 以仓储集合构造。
  ConfigInstallService(this._repositories);

  final Repositories _repositories;

  /// 引导是否已完成。
  Future<bool> isOnboardingDone() =>
      _repositories.settings.read(kOnboardingDoneKey, false);

  /// 置引导完成标记（「跳过」与「导入成功」都走这里）。
  Future<void> markOnboardingDone() =>
      _repositories.settings.write(kOnboardingDoneKey, true);

  /// 把 [result] 中的站点写入库，并置引导完成标记。
  ///
  /// [sourceUrl] 配置源 URL（用于 type=3 站点解析相对脚本路径）。
  /// 返回写入的站点数。
  Future<int> install(
    ConfigImportResult result, {
    String name = '导入配置',
    String? sourceUrl,
  }) async {
    final now = DateTime.now().toUtc();

    final configSourceId = await _repositories.configSources.add(
      ConfigSourcesCompanion.insert(
        name: name,
        url: Value(sourceUrl),
        rawHash: '',
        format: result.format,
        spider: Value(result.config.spider),
        spiderMd5: Value(result.config.spiderMd5),
        createdAt: now,
        updatedAt: now,
      ),
    );

    for (final site in result.config.sites) {
      await _repositories.sites.upsert(
        SitesCompanion.insert(
          configId: Value(configSourceId),
          siteKey: site.key,
          name: site.name,
          typeCode: site.type,
          runtime: 'http',
          api: site.api,
          ext: Value(site.ext),
          searchable: Value(site.searchable),
          quickSearch: Value(site.quickSearch),
          filterable: Value(site.filterable),
          priority: Value(site.priority),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    await markOnboardingDone();
    return result.config.sites.length;
  }

  /// 从 URL 拉取并安装配置，`replace` 为真时先清空旧订阅。
  Future<Result<int, AppError>> installFromUrl(
    String url, {
    bool replace = true,
    String? aesKey,
  }) async {
    final normalizedUrl = normalizeConfigUrl(url);
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return const Err(
        LocalError(
          code: ErrorCode.invalidArgument,
          message: '配置地址无效，请输入完整的 HTTP/HTTPS 地址',
        ),
      );
    }

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      final req = await client
          .getUrl(uri)
          .timeout(
            const Duration(seconds: 10),
          );
      req.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Safari/537.36',
      );
      req.headers.set(HttpHeaders.acceptHeader, '*/*');
      final resp = await req.close().timeout(const Duration(seconds: 15));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        await resp.drain<void>();
        return Err(
          RemoteError(
            code: ErrorCode.configFetchFailed,
            message: '订阅拉取失败 HTTP ${resp.statusCode}',
          ),
        );
      }
      final bytes = await resp.fold<List<int>>(
        <int>[],
        (a, b) => a..addAll(b),
      );
      client.close();
      final result = ConfigImportService.import(bytes, aesKey: aesKey);
      if (result.isErr) return Err(result.errorOrNull!);
      if (replace) {
        // 清理旧订阅与站点（保留收藏/历史）
        await _repositories.sites.clear();
        await _repositories.configSources.clear();
      }
      final count = await install(
        result.valueOrNull!,
        name: '订阅 ${DateTime.now().toIso8601String().substring(0, 10)}',
        sourceUrl: normalizedUrl,
      );
      return Ok(count);
    } on Object catch (e, st) {
      return Err(AppError.from(e, st));
    }
  }
}
