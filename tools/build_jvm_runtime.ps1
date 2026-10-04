$ErrorActionPreference = 'Stop'
$srcRoot = 'runtimes/spider_jvm/src/main/java'
$libsDir = 'runtimes/spider_jvm/libs'
$outDir = 'runtimes/spider_jvm/build/classes'
$jarOut = 'runtimes/spider_jvm/build/spider_jvm_runtime.jar'

Write-Output "== jvm:build =="

if (-not (Get-Command javac -ErrorAction SilentlyContinue)) {
  Write-Error "javac 未找到，请安装 JDK 17 并加入 PATH"
  exit 1
}

$libs = (Get-ChildItem $libsDir -Filter '*.jar' | Where-Object { $_.Name -ne 'dx-30.0.2.jar' } | ForEach-Object { $_.FullName }) -join ';'
if (-not $libs) { Write-Error "libs 为空"; exit 1 }

Remove-Item $outDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$files = Get-ChildItem $srcRoot -Recurse -Filter "*.java"
Write-Output "Compiling $($files.Count) java files..."
# `--release 17` 不能省：不加的话字节码版本跟着**编译器**走。CI 的 windows-latest
# 不保证永远是 JDK 17，一旦镜像升到 JDK 21，这里会静默产出 major 65 的 jar，而
# ADR-006 要求用户自己装的是 **JRE 17+** —— 产物在用户机器上直接
# UnsupportedClassVersionError，本地与 CI 都全绿，只有用户看到「站点全不可用」。
# 钉住 target 让「编译用 JDK」与「运行用 JRE」两个版本解耦。
$argList = @('-encoding','UTF-8','--release','17','-cp', $libs, '-d', $outDir) + ($files | ForEach-Object { $_.FullName })
& javac @argList
if ($LASTEXITCODE -ne 0) { Write-Error "javac 失败 $LASTEXITCODE"; exit $LASTEXITCODE }

Write-Output "Packaging $jarOut..."
& jar cfe $jarOut io.mistream.jvm.Main -C $outDir .
if ($LASTEXITCODE -ne 0) { Write-Error "jar 失败 $LASTEXITCODE"; exit $LASTEXITCODE }

$info = Get-Item $jarOut
Write-Output "OK $($info.Length) bytes -> $jarOut"
