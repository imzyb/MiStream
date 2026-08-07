/// TVBox 配置的抓取、解码、解析、映射与校验。
library;

export 'src/config_decoder.dart' show ConfigDecoder, DecodeResult;
export 'src/config_import_service.dart'
    show ConfigImportResult, ConfigImportService;
export 'src/config_models.dart';
export 'src/config_parser.dart' show ConfigParser, LooseJsonParser;
