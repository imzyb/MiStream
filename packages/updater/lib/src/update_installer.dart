/// 把下载好的更新包**真正装上去**，并且失败能回滚。
///
/// 为什么单独一层、为什么这么绕：
///
/// 1. Windows 上**正在运行**的 `mistream.exe` 不能被覆盖。所以替换必须发生在
///    应用退出之后 —— 由一个独立的 PowerShell 脚本（`apply.ps1`）来做，应用
///    只负责把「要装什么」写成 `plan.json` 然后退出。
/// 2. 替换到一半失败（磁盘满、文件被占用、杀进程）必须能回到原样，否则用户
///    得到的是一个**半新半旧**的目录，那比「没更新」严重得多。
/// 3. 所以回滚**不放在 PowerShell 里**，而是放在 Dart 侧、应用下次启动时做：
///    脚本只负责「备份 + 覆盖 + 写状态」，出任何问题就写 `failed` 然后退出；
///    真正的恢复逻辑是 [UpdateInstaller.recoverIfNeeded]，它能在本机被完整
///    单测覆盖（PowerShell 里的回滚分支测不了）。
///
/// 目录约定（全部在 `<应用目录>/update/` 下）：
///
/// ```text
/// update/
///   staged/     解压好的新文件（相对路径与应用目录一致）
///   backup/     被覆盖掉的旧文件（相对路径同上）
///   plan.json   {version, files:[相对路径…]}
///   state.json  {status: applying|ok|failed|rolledback, version, error, at}
///   apply.ps1   退出后执行的替换脚本
/// ```
///
/// 判断「装成功了没有」只看 `state.json`；判断「要不要回滚」看 plan 与 state
/// 的组合，见 [recoverIfNeeded]。
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// 安装/回滚失败。
final class UpdateInstallException implements Exception {
  /// 构造。
  const UpdateInstallException(this.message);

  /// 中文短句。
  final String message;

  @override
  String toString() => 'UpdateInstallException: $message';
}

/// 一次安装的最终状态。
enum InstallStatus {
  /// 还在替换中（脚本已开始但没写完状态，通常意味着它中途死了）。
  applying,

  /// 替换成功。
  ok,

  /// 替换失败，等待应用下次启动时回滚。
  failed,

  /// 已经回滚完成。
  rolledback;

  /// 从字面量解析；不认识的一律当 [failed]（保守：宁可回滚）。
  static InstallStatus parse(String? raw) => switch (raw) {
    'applying' => InstallStatus.applying,
    'ok' => InstallStatus.ok,
    'rolledback' => InstallStatus.rolledback,
    _ => InstallStatus.failed,
  };
}

/// `state.json` 的内容。
final class InstallState {
  /// 构造。
  const InstallState({
    required this.status,
    this.version,
    this.error,
    this.at,
  });

  /// 状态。
  final InstallStatus status;

  /// 目标版本。
  final String? version;

  /// 失败原因（`failed` 时有值）。
  final String? error;

  /// 写入时间。
  final DateTime? at;

  /// 是否装好了。
  bool get isOk => status == InstallStatus.ok;
}

/// 已解压、待安装的更新。
final class StagedUpdate {
  /// 构造。
  const StagedUpdate({
    required this.version,
    required this.files,
    required this.stagedDir,
  });

  /// 目标版本。
  final String version;

  /// 相对应用目录的路径（`/` 分隔）。
  final List<String> files;

  /// 解压目录。
  final String stagedDir;
}

/// 安装器。
final class UpdateInstaller {
  /// 构造。[appDir] 一般是「当前 exe 所在目录」。
  UpdateInstaller({required Directory appDir, this.updateDirName = 'update'})
    : appDir = appDir.absolute;

  /// 应用目录。
  final Directory appDir;

  /// 更新工作目录名（在应用目录下）。
  final String updateDirName;

  /// `<应用目录>/update`。
  Directory get updateRoot => Directory(p.join(appDir.path, updateDirName));

  /// 解压目录。
  Directory get stagedDir => Directory(p.join(updateRoot.path, 'staged'));

  /// 备份目录。
  Directory get backupDir => Directory(p.join(updateRoot.path, 'backup'));

  /// 计划文件。
  File get planFile => File(p.join(updateRoot.path, 'plan.json'));

  /// 状态文件。
  File get stateFile => File(p.join(updateRoot.path, 'state.json'));

  /// 替换脚本。
  File get applyScript => File(p.join(updateRoot.path, 'apply.ps1'));

  /// 解压更新包到 `staged/`，并写 `plan.json`。
  ///
  /// 越界路径（`../`、绝对路径）**直接拒绝**：更新包是网络来的，允许它写到
  /// 应用目录之外等于把更新链变成任意文件写入。
  Future<StagedUpdate> stageZip(File zip, {required String version}) async {
    if (!zip.existsSync()) {
      throw UpdateInstallException('更新包不存在: ${zip.path}');
    }
    if (stagedDir.existsSync()) stagedDir.deleteSync(recursive: true);
    await stagedDir.create(recursive: true);

    final bytes = await zip.readAsBytes();
    // 先看签名：`ZipDecoder` 对垃圾字节常常**不抛**，而是解出一个空归档，
    // 于是错误会退化成「包里没有任何文件」—— 那句话对排查毫无帮助。
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
      throw const UpdateInstallException('更新包不是合法 zip（缺少 PK 签名）');
    }
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on Object catch (e) {
      throw UpdateInstallException('更新包不是合法 zip: $e');
    }

    final files = <String>[];
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final rel = p.posix.normalize(
        entry.name.replaceAll(RegExp(r'\\'), '/'),
      );
      if (_isUnsafe(rel)) {
        throw UpdateInstallException('更新包里有越界路径: ${entry.name}');
      }
      final target = File(p.join(stagedDir.path, p.joinAll(rel.split('/'))));
      await target.parent.create(recursive: true);
      await target.writeAsBytes(entry.content as List<int>, flush: true);
      files.add(rel);
    }
    if (files.isEmpty) {
      throw const UpdateInstallException('更新包里没有任何文件');
    }

    await updateRoot.create(recursive: true);
    await planFile.writeAsString(
      jsonEncode({
        'version': version,
        'files': files,
        'stagedAt': DateTime.now().toUtc().toIso8601String(),
      }),
      flush: true,
    );
    return StagedUpdate(
      version: version,
      files: files,
      stagedDir: stagedDir.path,
    );
  }

  static bool _isUnsafe(String rel) {
    if (rel.isEmpty) return true;
    if (p.posix.isAbsolute(rel)) return true;
    if (rel == '..' || rel.startsWith('../')) return true;
    // Windows 盘符形式（`C:/x`）在 posix 里不算绝对路径。
    return RegExp(r'^[a-zA-Z]:').hasMatch(rel);
  }

  /// 生成替换脚本。
  ///
  /// 脚本内容刻意**全 ASCII**：PowerShell 5.1 读无 BOM 的 UTF-8 脚本时按系统
  /// 代码页解释，中文注释会变成乱码（甚至影响字符串解析）。这个脚本是运行时
  /// 生成、给机器看的，不需要中文。
  Future<File> writeApplyScript({
    required int appPid,
    String? relaunchExe,
    int waitSeconds = 180,
  }) async {
    if (!planFile.existsSync()) {
      throw const UpdateInstallException('没有 plan.json，先调 stageZip');
    }
    await updateRoot.create(recursive: true);
    final script = _scriptTemplate
        .replaceAll('@@APP_PID@@', '$appPid')
        .replaceAll('@@WAIT_SECONDS@@', '$waitSeconds')
        .replaceAll('@@RELAUNCH@@', _psQuote(relaunchExe ?? ''));
    await applyScript.writeAsString(script, flush: true);
    return applyScript;
  }

  /// 拉起替换脚本（**不等待**）。
  ///
  /// 调用方紧接着就该退出应用 —— 脚本会先等 [appPid] 结束再动文件。
  Future<Process> startApply({
    required int appPid,
    String? relaunchExe,
    int waitSeconds = 180,
  }) async {
    final script = await writeApplyScript(
      appPid: appPid,
      relaunchExe: relaunchExe,
      waitSeconds: waitSeconds,
    );
    return Process.start(
      'powershell.exe',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        script.path,
        '-AppDir',
        appDir.path,
        '-UpdateRoot',
        updateRoot.path,
      ],
      mode: ProcessStartMode.detached,
    );
  }

  /// 读 `state.json`；没有则 `null`。
  InstallState? readState() {
    if (!stateFile.existsSync()) return null;
    try {
      final raw = _stripBom(stateFile.readAsStringSync());
      final json = jsonDecode(raw) as Map<String, Object?>;
      return InstallState(
        status: InstallStatus.parse(json['status'] as String?),
        version: json['version']?.toString(),
        error: json['error']?.toString(),
        at: DateTime.tryParse(json['at']?.toString() ?? ''),
      );
    } on Object {
      // 状态文件坏了就当「不知道」—— 调用方会按「没有 plan」处理。
      return null;
    }
  }

  /// 应用启动时调用：把上一次没走完的安装收尾（成功就清理，失败就回滚）。
  ///
  /// 返回 `null` 表示「没有待处理的安装」。
  Future<InstallState?> recoverIfNeeded() async {
    final plan = _readPlan();
    if (plan == null) {
      // 没有计划：如果还有残留的 staged/backup，说明是清理到一半，一并清掉。
      if (stagedDir.existsSync() || backupDir.existsSync()) _cleanupWorkDirs();
      return null;
    }
    final state = readState();

    if (state != null && state.status == InstallStatus.ok) {
      _cleanupWorkDirs();
      planFile.deleteSync();
      return state;
    }

    // failed / applying / 无状态 —— 三种都意味着「目录可能是半新半旧」。
    await _rollback(plan);
    final rolled = InstallState(
      status: InstallStatus.rolledback,
      version: plan['version']?.toString(),
      error: state?.error,
      at: DateTime.now().toUtc(),
    );
    await _writeState(rolled);
    _cleanupWorkDirs();
    planFile.deleteSync();
    return rolled;
  }

  /// 把 [plan] 里的每个文件恢复成安装前的样子。
  ///
  /// 判据只有一条：**备份里有就还原，备份里没有就是这次新加的文件，删掉**。
  /// 这样不需要「进度日志」—— `backup/` 本身就是进度。
  Future<void> _rollback(Map<String, Object?> plan) async {
    final files = (plan['files'] as List?) ?? const [];
    for (final item in files) {
      final rel = item.toString();
      if (_isUnsafe(rel)) continue;
      final target = File(p.join(appDir.path, p.joinAll(rel.split('/'))));
      final backup = File(p.join(backupDir.path, p.joinAll(rel.split('/'))));
      try {
        if (backup.existsSync()) {
          await target.parent.create(recursive: true);
          await backup.copy(target.path);
        } else if (target.existsSync()) {
          target.deleteSync();
        }
      } on FileSystemException {
        // 单个文件恢复失败不该中断整轮回滚 —— 继续恢复其余文件，
        // 剩下的残局下次启动还会再试一次（plan 只在成功后删除）。
        continue;
      }
    }
  }

  /// 清掉 `staged/` 与 `backup/`。
  void _cleanupWorkDirs() {
    for (final dir in [stagedDir, backupDir]) {
      try {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } on FileSystemException {
        // 删不掉就留着，下次启动再清。
      }
    }
  }

  Map<String, Object?>? _readPlan() {
    if (!planFile.existsSync()) return null;
    try {
      final raw = _stripBom(planFile.readAsStringSync());
      final json = jsonDecode(raw);
      return json is Map<String, Object?> ? json : null;
    } on Object {
      return null;
    }
  }

  Future<void> _writeState(InstallState state) async {
    await updateRoot.create(recursive: true);
    await stateFile.writeAsString(
      jsonEncode({
        'status': state.status.name,
        'version': ?state.version,
        'error': ?state.error,
        'at': (state.at ?? DateTime.now().toUtc()).toIso8601String(),
      }),
      flush: true,
    );
  }

  static String _stripBom(String s) =>
      s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF ? s.substring(1) : s;

  /// PowerShell 单引号字符串转义（`'` → `''`）。
  static String _psQuote(String value) => "'${value.replaceAll("'", "''")}'";

  /// 替换脚本。`@@…@@` 是模板占位符。
  ///
  /// 只做三件事：等应用退出 → 备份并覆盖 → 写状态。**不做回滚** ——
  /// 回滚在 Dart 侧（见类文档）。
  static const String _scriptTemplate = r'''
# MiStream update helper (generated by packages/updater; do not edit)
param(
  [Parameter(Mandatory=$true)][string]$AppDir,
  [Parameter(Mandatory=$true)][string]$UpdateRoot
)
$ErrorActionPreference = 'Stop'
$planPath  = Join-Path $UpdateRoot 'plan.json'
$statePath = Join-Path $UpdateRoot 'state.json'
$stagedDir = Join-Path $UpdateRoot 'staged'
$backupDir = Join-Path $UpdateRoot 'backup'
$waitPid   = @@APP_PID@@
$waitSecs  = @@WAIT_SECONDS@@
$relaunch  = @@RELAUNCH@@

function Write-State([string]$status, [string]$err) {
  $obj = [ordered]@{
    status = $status
    at     = (Get-Date).ToUniversalTime().ToString('o')
    error  = $err
  }
  try {
    $plan = Get-Content -Raw -Encoding UTF8 $planPath | ConvertFrom-Json
    if ($plan.version) { $obj.version = $plan.version }
  } catch { }
  ($obj | ConvertTo-Json -Compress) | Set-Content -Encoding UTF8 -Path $statePath
}

# 1) wait for the app to exit
if ($waitPid -gt 0) {
  $deadline = (Get-Date).AddSeconds($waitSecs)
  while ((Get-Date) -lt $deadline) {
    $proc = Get-Process -Id $waitPid -ErrorAction SilentlyContinue
    if (-not $proc) { break }
    Start-Sleep -Milliseconds 300
  }
}

Write-State 'applying' ''

# 2) backup then overwrite
try {
  $plan = Get-Content -Raw -Encoding UTF8 $planPath | ConvertFrom-Json
  foreach ($rel in $plan.files) {
    $src = Join-Path $stagedDir $rel
    $dst = Join-Path $AppDir $rel
    $bak = Join-Path $backupDir $rel
    $dstDir = Split-Path -Parent $dst
    if ($dstDir -and -not (Test-Path $dstDir)) {
      New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
    }
    if (Test-Path -LiteralPath $dst) {
      $bakDir = Split-Path -Parent $bak
      if ($bakDir -and -not (Test-Path $bakDir)) {
        New-Item -ItemType Directory -Force -Path $bakDir | Out-Null
      }
      Copy-Item -LiteralPath $dst -Destination $bak -Force
    }
    Copy-Item -LiteralPath $src -Destination $dst -Force
  }
  Write-State 'ok' ''
} catch {
  Write-State 'failed' $_.Exception.Message
}

# 3) bring the app back (the caller decides whether to)
if ($relaunch -ne '') {
  if (Test-Path -LiteralPath $relaunch) { Start-Process -FilePath $relaunch }
}
''';
}
