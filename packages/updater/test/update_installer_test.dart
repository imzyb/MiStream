import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:updater/updater.dart';

/// 造一个 zip 文件。
File zipOf(Map<String, String> entries, Directory dir) {
  final archive = Archive();
  entries.forEach((name, content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  final file = File(p.join(dir.path, 'update.zip'));
  file.writeAsBytesSync(ZipEncoder().encode(archive));
  return file;
}

/// 读一个 JSON 对象文件。
///
/// 用「先判类型再 map」而不是 `as Map<String, Object?>`：后者会触发
/// `cast_nullable_to_non_nullable`，而这里本来就该在类型不对时**明确失败**。
Map<String, Object?> _readJsonMap(File file) {
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) throw StateError('不是 JSON 对象: ${file.path}');
  return decoded.map((k, v) => MapEntry(k.toString(), v));
}

/// 本机能不能跑 PowerShell（跑不了就跳过集成用例，而不是假装通过）。
bool _canRunPowerShell() {
  try {
    final r = Process.runSync('powershell.exe', [
      '-NoProfile',
      '-Command',
      'exit 0',
    ]);
    return r.exitCode == 0;
  } on Object {
    return false;
  }
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mistream-installer');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  UpdateInstaller installerFor(String appDirName) => UpdateInstaller(
    appDir: Directory(p.join(root.path, appDirName))..createSync(),
  );

  group('stageZip', () {
    test('解压到 staged/，plan.json 记录相对路径', () async {
      final app = installerFor('app');
      final zip = zipOf({
        'mistream.exe': 'new-exe',
        'data/app.so': 'new-so',
        'runtimes/x/y.txt': 'new-y',
      }, root);

      final staged = await app.stageZip(zip, version: '0.2.0');

      expect(staged.files, containsAll(['mistream.exe', 'data/app.so']));
      expect(
        File(p.join(app.stagedDir.path, 'data', 'app.so')).readAsStringSync(),
        'new-so',
      );
      final plan = _readJsonMap(app.planFile);
      expect(plan['version'], '0.2.0');
      expect(plan['files'], hasLength(3));
    });

    test('重复 stage 会先清掉上一次的 staged（不残留旧文件）', () async {
      final app = installerFor('app');
      await app.stageZip(
        zipOf({'a.txt': '1', 'b.txt': '2'}, root),
        version: '0.2.0',
      );
      await app.stageZip(zipOf({'a.txt': '9'}, root), version: '0.2.1');

      expect(
        File(p.join(app.stagedDir.path, 'b.txt')).existsSync(),
        isFalse,
        reason: '上一次的 b.txt 必须被清掉',
      );
      expect(
        File(p.join(app.stagedDir.path, 'a.txt')).readAsStringSync(),
        '9',
      );
    });

    test('越界路径一律拒绝（../ 与盘符绝对路径）', () async {
      final app = installerFor('app');
      for (final bad in ['../evil.txt', 'a/../../evil.txt', 'C:/evil.txt']) {
        await expectLater(
          app.stageZip(zipOf({bad: 'x'}, root), version: '0.2.0'),
          throwsA(isA<UpdateInstallException>()),
          reason: '不该允许 $bad',
        );
      }
    });

    test('空包拒绝', () async {
      final app = installerFor('app');
      await expectLater(
        app.stageZip(zipOf({}, root), version: '0.2.0'),
        throwsA(isA<UpdateInstallException>()),
      );
    });

    test('不是 zip 时报清晰错误', () async {
      final app = installerFor('app');
      final fake = File(p.join(root.path, 'bad.zip'))
        ..writeAsStringSync('not a zip');
      await expectLater(
        app.stageZip(fake, version: '0.2.0'),
        throwsA(
          isA<UpdateInstallException>().having(
            (e) => e.message,
            'message',
            contains('不是合法 zip'),
          ),
        ),
      );
    });
  });

  group('writeApplyScript', () {
    test('脚本是纯 ASCII（PowerShell 5.1 读中文会乱码）', () async {
      final app = installerFor('app');
      await app.stageZip(zipOf({'a.txt': '1'}, root), version: '0.2.0');
      final script = await app.writeApplyScript(
        appPid: 1234,
        relaunchExe: r'C:\Program Files\Mi Stream\mistream.exe',
      );
      final bytes = script.readAsBytesSync();
      expect(
        bytes.every((b) => b < 0x80),
        isTrue,
        reason: '脚本里出现非 ASCII 字符，PowerShell 5.1 会按系统代码页解释',
      );
      final text = script.readAsStringSync();
      expect(text, contains(r'$waitPid   = 1234'));
      expect(text, contains(r"'C:\Program Files\Mi Stream\mistream.exe'"));
    });

    test('没有 plan.json 时拒绝生成（避免生成一个什么都不做的脚本）', () async {
      final app = installerFor('app');
      await expectLater(
        app.writeApplyScript(appPid: 1),
        throwsA(isA<UpdateInstallException>()),
      );
    });
  });

  group('recoverIfNeeded', () {
    /// 造一个「装到一半」的现场：应用目录里是新内容，backup 里有旧内容。
    Future<UpdateInstaller> brokenInstall() async {
      final app = installerFor('app');
      final zip = zipOf({
        'mistream.exe': 'new-exe',
        'data/app.so': 'new-so',
        'data/new-only.txt': 'brand-new',
      }, root);
      await app.stageZip(zip, version: '0.2.0');

      // 旧文件（会被覆盖的两个）
      File(
        p.join(app.appDir.path, 'mistream.exe'),
      ).writeAsStringSync('old-exe');
      File(p.join(app.appDir.path, 'data', 'app.so'))
        ..createSync(recursive: true)
        ..writeAsStringSync('old-so');
      // 模拟脚本已经覆盖 + 备份
      File(
        p.join(app.appDir.path, 'mistream.exe'),
      ).writeAsStringSync('new-exe');
      File(
        p.join(app.appDir.path, 'data', 'app.so'),
      ).writeAsStringSync('new-so');
      File(
        p.join(app.appDir.path, 'data', 'new-only.txt'),
      ).writeAsStringSync('brand-new');
      File(p.join(app.backupDir.path, 'mistream.exe'))
        ..createSync(recursive: true)
        ..writeAsStringSync('old-exe');
      File(p.join(app.backupDir.path, 'data', 'app.so'))
        ..createSync(recursive: true)
        ..writeAsStringSync('old-so');
      return app;
    }

    test('没有 plan → 返回 null，不碰任何东西', () async {
      final app = installerFor('app');
      File(p.join(app.appDir.path, 'keep.txt')).writeAsStringSync('keep');
      expect(await app.recoverIfNeeded(), isNull);
      expect(
        File(p.join(app.appDir.path, 'keep.txt')).readAsStringSync(),
        'keep',
      );
    });

    test('state=ok → 清理 staged/backup/plan，保留 state 供 UI 报「已更新」', () async {
      final app = await brokenInstall();
      app.stateFile.writeAsStringSync(
        jsonEncode({'status': 'ok', 'version': '0.2.0'}),
      );

      final state = await app.recoverIfNeeded();
      expect(state?.status, InstallStatus.ok);
      expect(app.stagedDir.existsSync(), isFalse);
      expect(app.backupDir.existsSync(), isFalse);
      expect(app.planFile.existsSync(), isFalse);
      expect(app.stateFile.existsSync(), isTrue);
      expect(
        File(p.join(app.appDir.path, 'mistream.exe')).readAsStringSync(),
        'new-exe',
        reason: '成功路径不该动已装好的文件',
      );
    });

    test('state=failed → 还原被覆盖的，删掉新增的', () async {
      final app = await brokenInstall();
      app.stateFile.writeAsStringSync(
        jsonEncode({'status': 'failed', 'error': '磁盘满'}),
      );

      final state = await app.recoverIfNeeded();
      expect(state?.status, InstallStatus.rolledback);
      expect(state?.error, '磁盘满', reason: '失败原因要带到回滚结果里');
      expect(
        File(p.join(app.appDir.path, 'mistream.exe')).readAsStringSync(),
        'old-exe',
      );
      expect(
        File(p.join(app.appDir.path, 'data', 'app.so')).readAsStringSync(),
        'old-so',
      );
      expect(
        File(p.join(app.appDir.path, 'data', 'new-only.txt')).existsSync(),
        isFalse,
        reason: '备份里没有它 → 说明是这次新加的文件，要删掉',
      );
      expect(app.planFile.existsSync(), isFalse);
    });

    test('state=applying（脚本中途死了）→ 同样回滚', () async {
      final app = await brokenInstall();
      app.stateFile.writeAsStringSync(jsonEncode({'status': 'applying'}));

      final state = await app.recoverIfNeeded();
      expect(state?.status, InstallStatus.rolledback);
      expect(
        File(p.join(app.appDir.path, 'mistream.exe')).readAsStringSync(),
        'old-exe',
      );
    });

    test('没有 state 但有 plan → 回滚（脚本连状态都没写出来）', () async {
      final app = await brokenInstall();
      expect(app.stateFile.existsSync(), isFalse);

      final state = await app.recoverIfNeeded();
      expect(state?.status, InstallStatus.rolledback);
      expect(
        File(p.join(app.appDir.path, 'data', 'app.so')).readAsStringSync(),
        'old-so',
      );
    });

    test('坏掉的 state.json 当成失败处理（宁可回滚）', () async {
      final app = await brokenInstall();
      app.stateFile.writeAsStringSync('{not json');
      final state = await app.recoverIfNeeded();
      expect(state?.status, InstallStatus.rolledback);
    });
  });

  group('apply.ps1 真跑（Windows 集成）', () {
    test('正常替换：文件被覆盖、旧文件进 backup、state=ok', () async {
      if (!_canRunPowerShell()) {
        markTestSkipped('本机跑不了 powershell.exe');
        return;
      }
      final app = installerFor('app');
      File(
        p.join(app.appDir.path, 'mistream.exe'),
      ).writeAsStringSync('old-exe');
      final zip = zipOf({
        'mistream.exe': 'new-exe',
        'data/app.so': 'new-so',
      }, root);
      await app.stageZip(zip, version: '0.2.0');
      final script = await app.writeApplyScript(appPid: 0);

      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        script.path,
        '-AppDir',
        app.appDir.path,
        '-UpdateRoot',
        app.updateRoot.path,
      ]).timeout(const Duration(seconds: 90));

      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout} stderr=${result.stderr}',
      );
      expect(
        File(p.join(app.appDir.path, 'mistream.exe')).readAsStringSync(),
        'new-exe',
      );
      expect(
        File(p.join(app.appDir.path, 'data', 'app.so')).readAsStringSync(),
        'new-so',
        reason: '新目录要自动创建',
      );
      expect(
        File(p.join(app.backupDir.path, 'mistream.exe')).readAsStringSync(),
        'old-exe',
        reason: '旧文件必须留底，否则回滚无从下手',
      );
      expect(app.readState()?.status, InstallStatus.ok);
      expect(app.readState()?.version, '0.2.0');
    });

    test('替换失败：state=failed，且 recoverIfNeeded 能还原', () async {
      if (!_canRunPowerShell()) {
        markTestSkipped('本机跑不了 powershell.exe');
        return;
      }
      final app = installerFor('app');
      File(
        p.join(app.appDir.path, 'mistream.exe'),
      ).writeAsStringSync('old-exe');
      final zip = zipOf({'mistream.exe': 'new-exe'}, root);
      await app.stageZip(zip, version: '0.2.0');

      // 故意删掉一个 staged 文件 → Copy-Item 必然失败，模拟「装到一半出错」。
      File(p.join(app.stagedDir.path, 'mistream.exe')).deleteSync();

      final script = await app.writeApplyScript(appPid: 0);
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        script.path,
        '-AppDir',
        app.appDir.path,
        '-UpdateRoot',
        app.updateRoot.path,
      ]).timeout(const Duration(seconds: 90));
      expect(result.exitCode, 0, reason: '脚本自己不该以非 0 退出');

      final failed = app.readState();
      expect(failed?.status, InstallStatus.failed);
      expect(failed?.error, isNotNull);

      final recovered = await app.recoverIfNeeded();
      expect(recovered?.status, InstallStatus.rolledback);
      expect(
        File(p.join(app.appDir.path, 'mistream.exe')).readAsStringSync(),
        'old-exe',
      );
    });
  });
}
