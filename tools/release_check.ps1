$ErrorActionPreference = 'Stop'
Write-Output "== 合规扫描：安装包不含源配置 =="

$patterns = @('spider','api\.php','vod_pic')
$found = @()
# 扫描 build 目录下的文本资源（非二进制）
$files = Get-ChildItem -Path "build" -Recurse -Include "*.json","*.yaml","*.yml" -ErrorAction SilentlyContinue
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
  Write-Error "合规扫描失败：安装包不应包含源配置"
  exit 1
}

Write-Output "合规扫描通过"
