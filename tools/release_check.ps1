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

    本文件必须保存为**带 BOM 的 UTF-8**。Windows PowerShell 5.1 的 `-File`
    对无 BOM 的脚本按 ANSI 码页解码（不看文件内容），中文会把紧随其后的
    ASCII 字符一并吃掉：ANSI=CP936 时脚本仍能解析、但 `$files` 的赋值被吞进
    字符串字面量，扫描恒为 0 个文件；ANSI=CP1252 时直接
    `ParserError: The string is missing the terminator`。校验见
    `melos run check:arch` 的 `ps1-bom` 规则。
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

# 扫到 0 个文本资源就说明这条门禁没在工作：真实构建产物里至少有
# flutter_assets/FontManifest.json 与 NativeAssetsManifest.json。让「空集」
# 直接失败，是为了把「脚本被改坏 / 路径写错 / 匹配规则失效」这三种情况从
# 「静默通过」变成「响亮失败」——本脚本历史上正是被前一种情况骗过。
if (@($files).Count -eq 0) {
    Write-Error "合规扫描失败：在 $BuildDir 下没扫到任何文本资源，说明扫描路径或匹配规则已失效，本次扫描结果不可信。" -ErrorAction Continue
    exit 1
}
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
