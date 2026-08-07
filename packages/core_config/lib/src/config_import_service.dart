/// TVBox 配置导入服务：解码 → 解析 → 校验。
///
/// docs/05-Spider引擎.md §5。
library;

import 'package:core_config/src/config_decoder.dart';
import 'package:core_config/src/config_models.dart';
import 'package:core_config/src/config_parser.dart';
import 'package:core_domain/core_domain.dart';

/// 配置导入结果。
class ConfigImportResult {
  final TvBoxConfig config;
  final String format;
  final int siteCount;

  const ConfigImportResult({
    required this.config,
    required this.format,
    required this.siteCount,
  });
}

/// 配置导入服务。
class ConfigImportService {
  /// 导入配置：解码 + 解析。
  ///
  /// [raw] 原始字节，[aesKey] AES 密钥（可选）。
  static Result<ConfigImportResult, AppError> import(
    List<int> raw, {
    String? aesKey,
  }) {
    // 1. 解码
    final decoded = ConfigDecoder.decode(raw, aesKey: aesKey);
    if (decoded.isErr) {
      return Err(decoded.errorOrNull!);
    }

    // 2. 解析
    final config = ConfigParser.parse(decoded.valueOrNull!.json);
    if (config == null) {
      return Err(
        LocalError(
          code: ErrorCode.configParseFailed,
          message: decoded.valueOrNull!.format == 'aes'
              ? 'AES 解密后 JSON 结构非法'
              : 'JSON 结构非法',
        ),
      );
    }

    // 3. 校验：必须有至少一个站点
    if (config.sites.isEmpty) {
      return Err(
        LocalError(
          code: ErrorCode.configEmpty,
          message: '解析成功但无可用站点',
        ),
      );
    }

    return Ok(
      ConfigImportResult(
        config: config,
        format: decoded.valueOrNull!.format,
        siteCount: config.sites.length,
      ),
    );
  }
}
