import 'package:download/download.dart';
import 'package:test/test.dart';

void main() {
  group('sanitizeDownloadName', () {
    test('普通中文标题原样保留', () {
      expect(sanitizeDownloadName('庆余年 第二季'), '庆余年 第二季');
    });

    test('非法字符换成下划线', () {
      expect(
        sanitizeDownloadName(r'a/b\c:d*e?f"g<h>i|j'),
        'a_b_c_d_e_f_g_h_i_j',
      );
    });

    test('控制字符换成下划线', () {
      expect(sanitizeDownloadName('a\tb\nc'), 'a_b_c');
    });

    test('去掉结尾的点和空格', () {
      // Windows 会悄悄吃掉它们，于是「库里的路径」与「盘上的路径」对不上。
      expect(sanitizeDownloadName('第1集.'), '第1集');
      expect(sanitizeDownloadName('第1集  '), '第1集');
      expect(sanitizeDownloadName('第1集 . . '), '第1集');
    });

    test('超长标题被截断', () {
      final name = sanitizeDownloadName('甲' * 200);
      expect(name.runes.length, kMaxDownloadNameLength);
    });

    test('截断不会把一个字符切成两半', () {
      // 用 runes 而不是 substring：后者按 UTF-16 码元切，遇到 emoji 会把代理对
      // 劈开，产出一个非法字符串。
      final name = sanitizeDownloadName('🎬' * 200);
      expect(name.runes.length, kMaxDownloadNameLength);
      expect(name, '🎬' * kMaxDownloadNameLength);
    });

    test('Windows 保留设备名加前缀', () {
      expect(sanitizeDownloadName('CON'), '_CON');
      expect(sanitizeDownloadName('aux'), '_aux');
      // 带扩展名同样会被当成设备名。
      expect(sanitizeDownloadName('NUL.mp4'), '_NUL.mp4');
      // 只是以保留名开头不算。
      expect(sanitizeDownloadName('CONTACT'), 'CONTACT');
    });

    test('清理后为空时回落到默认名', () {
      expect(sanitizeDownloadName('...'), 'download');
      expect(sanitizeDownloadName(''), 'download');
      expect(sanitizeDownloadName('///'), '___');
    });

    test('自定义回落名', () {
      expect(sanitizeDownloadName('', fallback: '未命名'), '未命名');
    });
  });
}
