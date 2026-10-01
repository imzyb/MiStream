/// 取消令牌。
///
/// 独立成文件而不是塞在 `hls_downloader.dart` 里：直链下载器也要用它，
/// 让 `http_download_client.dart` 去 import HLS 下载器只为了拿一个令牌类型，
/// 是把两个并列的下载实现拧成了依赖关系。
class CancelToken {
  bool _isCancelled = false;

  /// 是否已取消。
  bool get isCancelled => _isCancelled;

  /// 取消。
  void cancel() {
    _isCancelled = true;
  }
}
