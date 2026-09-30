/// 转出口：GBK 编解码已移到 `packages/text_codec`。
///
/// 为什么留这个文件而不是直接删掉：`package:spider_js/src/drpy/gbk.dart`
/// 这条路径被 `spider_js.dart` 的导出表、`host_bridge.dart`、`compat_runner.dart`
/// 与两个测试文件引用，而且它是 drpy 宿主 API 清单
/// （`docs/05-Spider引擎.md` §2.2）在代码里的落点。留着这一行，这些引用
/// 与文档都不必动。
///
/// 移出去的理由是**码表只该有一份**：HTTP 拉取层（app 的直播源 / 配置拉取）
/// 也要用同一份 GBK 码表，而它不该为了这个去依赖 `spider_js`（那会把 QuickJS
/// FFI 与整个宿主桥拖进 app 的编译单元）。
library;

export 'package:text_codec/text_codec.dart'
    show GbkDecodeReport, GbkDecodeResult, gbkDecode, gbkDecodeWithReport;
