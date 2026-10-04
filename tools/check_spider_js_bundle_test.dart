/// Tests for the Spider JS release-bundle checker.
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('checker fails when a required runtime file is missing', () async {
    final directory = await Directory.systemTemp.createTemp(
      'mistream_spider_bundle_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    for (final name in const [
      'spider_js_runtime.exe',
      'libquickjs.dll',
      'quickjs.dll',
    ]) {
      await File(
        '${directory.path}${Platform.pathSeparator}$name',
      ).writeAsBytes(const [1]);
    }

    final result = await Process.run(
      Platform.resolvedExecutable,
      [
        'run',
        'tools/check_spider_js_bundle.dart',
        '--bundle',
        directory.path,
      ],
    );

    expect(result.exitCode, isNonZero);
    expect(result.stderr, contains('quickjs_wrapper.dll'));
  });
}
