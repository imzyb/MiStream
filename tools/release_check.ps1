<#
.SYNOPSIS
    Release 合规扫描：确认安装包里不含源配置。

.DESCRIPTION
    扫描构建产物中的文本资源（*.json / *.yaml / *.yml），命中疑似源配置的特征
    串即失败。作为发布门禁，见 docs/10-开发规范.md §5.1。

.PARAMETER BuildDir
    要扫描的构建目录。默认 apps/mistream/build —— 注意**不是**仓库根的 build：
    仓库根不是 Flutter app，根下没有 build 目录，传错会扫到空集。

.NOTES
    目录不存在时**必须失败**而不是通过。早期的写法是
    `Get-ChildItem -Path "build" -ErrorAction SilentlyContinue`，
    路径写错时静默返回空集、扫描"通过"，门禁形同虚设。
#>
param(
    [string]$BuildDir = 'apps/mistream/build'
)

$ErrorActionPreference = 'Stop'
Write-Output "== 合规扫描：安装包不含源配置 =="
Write-Output "扫描目录：$BuildDir"

if (-not (Test-Path -LiteralPath $BuildDir)) {
    Write-Error "合规扫描失败：构建目录不存在（$BuildDir）。请先执行构建，或用 -BuildDir 指定正确路径。" -ErrorAction Continue
    exit 1
}

$patterns = @('spider', 'api\.php', 'vod_pic')
$found = @()

$files = Get-ChildItem -Path $BuildDir -Recurse -Include '*.json', '*.yaml', '*.yml' -ErrorAction SilentlyContinue
foreach ($f in $files) {
    $text = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
    foreach ($pat in $patterns) {
        if ($text -match $pat) {
            $found += "$($f.FullName):$pat"
        }
    }
}

if ($found.Count -gt 0) {
    Write-Output "发现疑似源配置："
    $found | ForEach-Object { Write-Output "  $_" }
    Write-Error "合规扫描失败：安装包不应包含源配置" -ErrorAction Continue
    exit 1
}

Write-Output "合规扫描通过（扫描 $($files.Count) 个文本资源）"
