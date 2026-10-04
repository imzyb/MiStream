/// 文本编解码：GBK/GB18030 码表与「字节 → 文本」的编码探测。
///
/// 两个消费方，刻意放在一个包里：
///
/// * **drpy 宿主 API**（`runtimes/spider_js`）—— 脚本拿到的响应是字节，按
///   UTF-8 解会乱码，需要 [gbkDecode]。
/// * **HTTP 拉取层**（app 的直播源 / 配置拉取）—— 响应头没给 charset 时
///   要按内容猜编码，见 [decodeText]。
///
/// 码表只该有一份：`runtimes/spider_js/lib/src/drpy/gbk.dart` 现在只是本包的
/// 转出口，保住 `package:spider_js/src/drpy/gbk.dart` 这条老 import 路径。
library;

export 'src/gbk.dart'
    show GbkDecodeReport, GbkDecodeResult, gbkDecode, gbkDecodeWithReport;
export 'src/text_decoder.dart'
    show TextCharset, charsetFromContentType, decodeText;
