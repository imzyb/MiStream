param(
    [Parameter(Mandatory = $true)]
    [string]$Configuration,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

if ($Configuration -notin @('Profile', 'Release')) {
    Write-Output "[spider-js] Skipping runtime bundle for $Configuration."
    exit 0
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$runtimeRoot = Join-Path $repoRoot 'runtimes\spider_js'
$engineDir = Join-Path $runtimeRoot 'lib\src\engine'
$entryPoint = Join-Path $runtimeRoot 'bin\spider_js_runtime.dart'
$bundleDir = Join-Path $repoRoot 'build\spider_js'
$checker = Join-Path $repoRoot 'tools\check_spider_js_bundle.dart'
$runtimeExe = Join-Path $bundleDir 'spider_js_runtime.exe'
$dllNames = @('libquickjs.dll', 'quickjs_wrapper.dll', 'quickjs.dll')

foreach ($path in @($entryPoint, $checker)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required Spider JS build input is missing: $path"
    }
}

foreach ($dllName in $dllNames) {
    $dllPath = Join-Path $engineDir $dllName
    if (-not (Test-Path -LiteralPath $dllPath -PathType Leaf)) {
        throw "Required QuickJS library is missing: $dllPath"
    }
}

New-Item -ItemType Directory -Path $bundleDir -Force | Out-Null
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

Write-Output '[spider-js] Compiling AOT runtime...'
& dart compile exe $entryPoint -o $runtimeExe
if ($LASTEXITCODE -ne 0) {
    throw "dart compile exe failed with exit code $LASTEXITCODE"
}

foreach ($dllName in $dllNames) {
    Copy-Item -LiteralPath (Join-Path $engineDir $dllName) -Destination $bundleDir -Force
}

Write-Output '[spider-js] Verifying bundle and JSON-RPC handshake...'
& dart run $checker --bundle $bundleDir --smoke
if ($LASTEXITCODE -ne 0) {
    throw "Spider JS bundle verification failed with exit code $LASTEXITCODE"
}

foreach ($fileName in @('spider_js_runtime.exe') + $dllNames) {
    Copy-Item -LiteralPath (Join-Path $bundleDir $fileName) -Destination $OutputDirectory -Force
}

Write-Output "[spider-js] Runtime bundle copied to $OutputDirectory"
