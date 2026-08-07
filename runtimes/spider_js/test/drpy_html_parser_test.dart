import 'package:spider_js/src/drpy/html_parser.dart';
import 'package:test/test.dart';

const htmlSample = '''
<html>
<body>
  <div class="list">
    <a href="https://example.com/1">剧集1</a>
    <a href="https://example.com/2">剧集2</a>
    <a href="https://example.com/3">剧集3</a>
  </div>
  <div class="detail">
    <h1 id="title">测试影片</h1>
    <img src="cover.jpg" alt="封面">
  </div>
</body>
</html>
''';

void main() {
  group('pdfh 单值提取', () {
    test('body&&.list&&a&&href 提取第一个链接', () {
      expect(pdfh(htmlSample, 'body&&.list&&a&&href'), 'https://example.com/1');
    });

    test('a&&Text 提取文本', () {
      expect(pdfh(htmlSample, 'a&&Text'), '剧集1');
    });

    test('img&&src 提取图片地址', () {
      expect(pdfh(htmlSample, 'img&&src'), 'cover.jpg');
    });

    test('h1&&Text 提取标题', () {
      expect(pdfh(htmlSample, 'h1&&Text'), '测试影片');
    });

    test('不存在的选择器返回空字符串', () {
      expect(pdfh(htmlSample, 'body&&.nonexistent&&a&&href'), '');
    });
  });

  group('pdfa 多值提取', () {
    test('body&&.list&&a&&href 提取全部链接', () {
      expect(pdfa(htmlSample, 'body&&.list&&a&&href'), [
        'https://example.com/1',
        'https://example.com/2',
        'https://example.com/3',
      ]);
    });

    test('a&&Text 提取全部文本', () {
      expect(pdfa(htmlSample, 'a&&Text'), ['剧集1', '剧集2', '剧集3']);
    });
  });
}
