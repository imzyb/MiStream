/// Verifies a packaged Spider JS runtime and optionally performs a handshake.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _requiredFiles = <String>[
  'spider_js_runtime.exe',
  'libquickjs.dll',
  'quickjs_wrapper.dll',
  'quickjs.dll',
];

Future<void> main(List<String> args) async {
  final bundleIndex = args.indexOf('--bundle');
  if (bundleIndex == -1 || bundleIndex + 1 >= args.length) {
    stderr.writeln(
      'Usage: dart run tools/check_spider_js_bundle.dart '
      '--bundle <directory> [--smoke]',
    );
    exitCode = 64;
    return;
  }

  final directory = Directory(args[bundleIndex + 1]).absolute;
  final missing = <String>[
    for (final name in _requiredFiles)
      if (!File('${directory.path}${Platform.pathSeparator}$name').existsSync())
        name,
  ];
  if (missing.isNotEmpty) {
    stderr.writeln('Missing Spider JS bundle files: ${missing.join(', ')}');
    exitCode = 1;
    return;
  }

  if (args.contains('--smoke')) {
    await _verifyHandshake(directory);
  }

  stdout.writeln('Spider JS bundle verified: ${directory.path}');
}

Future<void> _verifyHandshake(Directory directory) async {
  final executable =
      '${directory.path}${Platform.pathSeparator}spider_js_runtime.exe';
  final process = await Process.start(
    executable,
    const [],
    workingDirectory: directory.path,
  );
  final stderrFuture = process.stderr.transform(utf8.decoder).join();

  try {
    final request = jsonEncode({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'runtime.handshake',
      'params': {'protocolVersion': 1},
    });
    final body = utf8.encode(request);
    process.stdin.add(utf8.encode('Content-Length: ${body.length}\r\n\r\n'));
    process.stdin.add(body);
    await process.stdin.flush();

    final response = await _readFrame(process.stdout).timeout(
      const Duration(seconds: 10),
    );
    final decoded = jsonDecode(response);
    if (decoded is! Map<String, Object?> || decoded['id'] != 1) {
      throw StateError('Unexpected handshake response: $response');
    }
    final result = decoded['result'];
    if (result is! Map || result['protocolVersion'] != 1) {
      throw StateError('Incompatible handshake response: $response');
    }
  } finally {
    process.kill();
    await process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
    final childStderr = await stderrFuture;
    if (childStderr.trim().isNotEmpty) {
      stderr.writeln(childStderr.trim());
    }
  }
}

Future<String> _readFrame(Stream<List<int>> stream) async {
  final iterator = StreamIterator<int>(stream.expand((chunk) => chunk));
  final header = <int>[];
  while (true) {
    if (!await iterator.moveNext()) {
      throw const FormatException('Runtime closed before sending a frame');
    }
    header.add(iterator.current);
    final length = header.length;
    if (length >= 4 &&
        header[length - 4] == 13 &&
        header[length - 3] == 10 &&
        header[length - 2] == 13 &&
        header[length - 1] == 10) {
      break;
    }
    if (header.length > 8192) {
      throw const FormatException('Runtime response header is too large');
    }
  }

  final headerText = utf8.decode(header);
  final match = RegExp(
    r'Content-Length:\s*(\d+)',
    caseSensitive: false,
  ).firstMatch(headerText);
  if (match == null) {
    throw FormatException('Missing Content-Length: $headerText');
  }
  final contentLength = int.parse(match.group(1)!);
  final body = <int>[];
  while (body.length < contentLength) {
    if (!await iterator.moveNext()) {
      throw const FormatException('Runtime response body was truncated');
    }
    body.add(iterator.current);
  }
  await iterator.cancel();
  return utf8.decode(body);
}
