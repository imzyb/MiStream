import 'package:spider_js/src/drpy/type0_script.dart';
import 'package:test/test.dart';

void main() {
  group('type=0 内置通用脚本', () {
    test('包含所有标准 Spider 方法', () {
      expect(type0Script, contains('homeContent'));
      expect(type0Script, contains('categoryContent'));
      expect(type0Script, contains('detailContent'));
      expect(type0Script, contains('searchContent'));
      expect(type0Script, contains('playerContent'));
      expect(type0Script, contains('init'));
    });

    test('使用 drpy 宿主 API', () {
      expect(type0Script, contains('req('));
      expect(type0Script, contains('pdfh('));
      expect(type0Script, contains('pdfa('));
      expect(type0Script, contains('encodeURIComponent'));
    });

    test('由 ext 配置驱动', () {
      expect(type0Script, contains('this.ext'));
      expect(type0Script, contains('homeUrl'));
      expect(type0Script, contains('categoryUrl'));
      expect(type0Script, contains('searchUrl'));
    });

    test('返回标准 JSON 结构', () {
      expect(type0Script, contains('classes'));
      expect(type0Script, contains('vodId'));
      expect(type0Script, contains('vodName'));
      expect(type0Script, contains('vodPic'));
      expect(type0Script, contains('vodPlayFrom'));
    });
  });
}
