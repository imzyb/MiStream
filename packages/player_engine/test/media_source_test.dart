import 'package:player_engine/player_engine.dart';
import 'package:test/test.dart';

void main() {
  group('请求头拆分', () {
    // docs/04 §6：UA 与 Referer 有专属的 mpv 选项，其余走
    // http-header-fields。同一个头写两处，实际发出去的值就取决于 mpv 的内部
    // 顺序，这三个取值器把归属一次性说清楚。
    test('取出 UA 与 Referer，其余归入 otherHeaders', () {
      final source = MediaSource(
        uri: Uri.parse('https://cdn.example.com/a.m3u8'),
        headers: const {
          'User-Agent': 'MiStream/0.1',
          'Referer': 'https://example.com/play',
          'Cookie': 'sid=abc',
          'Origin': 'https://example.com',
        },
      );

      expect(source.userAgent, 'MiStream/0.1');
      expect(source.referrer, 'https://example.com/play');
      expect(source.otherHeaders, {
        'Cookie': 'sid=abc',
        'Origin': 'https://example.com',
      });
    });

    test('头名大小写不敏感', () {
      final source = MediaSource(
        uri: Uri.parse('https://e.com/a.mp4'),
        headers: const {'user-agent': 'ua', 'REFERER': 'ref'},
      );

      expect(source.userAgent, 'ua');
      expect(source.referrer, 'ref');
      expect(source.otherHeaders, isEmpty);
    });

    test('没有这两个头时为 null', () {
      final source = MediaSource(uri: Uri.parse('https://e.com/a.mp4'));

      expect(source.userAgent, isNull);
      expect(source.referrer, isNull);
      expect(source.otherHeaders, isEmpty);
    });

    test('otherHeaders 保留原始大小写', () {
      final source = MediaSource(
        uri: Uri.parse('https://e.com/a.mp4'),
        headers: const {'X-Custom-Header': 'v'},
      );

      expect(source.otherHeaders.keys, ['X-Custom-Header']);
    });
  });

  group('默认值', () {
    test('DRM 恒为 null', () {
      final source = MediaSource(uri: Uri.parse('https://e.com/a.mp4'));

      // DrmInfo 没有公开构造函数，drm 在包外只能是 null——合规边界
      // （docs/01 §6）落在类型层面，而不是靠注释提醒。
      expect(source.drm, isNull);
    });

    test('默认不是直播', () {
      final source = MediaSource(uri: Uri.parse('https://e.com/a.mp4'));

      expect(source.isLive, isFalse);
      expect(source.externalSubtitles, isEmpty);
      expect(source.headers, isEmpty);
    });
  });
}
