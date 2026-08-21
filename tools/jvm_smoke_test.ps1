$ErrorActionPreference = 'Stop'
$JarPath = 'C:\Users\Administrator\AppData\Local\Temp\opencode\qist_spider.jar'
$rt = 'I:\Cloudflare\mistream\runtimes\spider_jvm\build\spider_jvm_runtime.jar'
$libsDir = 'I:\Cloudflare\mistream\runtimes\spider_jvm\libs'
$libs = (Get-ChildItem $libsDir -Filter '*.jar' | ForEach-Object { $_.FullName }) -join ';'
$cp = "$rt;$libs"

function Send-Frame($p, [string]$json) {
    $body = [System.Text.Encoding]::UTF8.GetBytes($json)
    $header = [System.Text.Encoding]::UTF8.GetBytes("Content-Length: $($body.Length)`r`n`r`n")
    $p.StandardInput.BaseStream.Write($header, 0, $header.Length)
    $p.StandardInput.BaseStream.Write($body, 0, $body.Length)
    $p.StandardInput.BaseStream.Flush()
}

function Read-Frame($p, [int]$timeoutSec = 30) {
    $deadline = [DateTime]::Now.AddSeconds($timeoutSec)
    $header = New-Object System.Text.StringBuilder
    $prev = @(-1, -1, -1)
    while ($true) {
        if ([DateTime]::Now -gt $deadline) { throw "read timeout" }
        $b = $p.StandardOutput.BaseStream.ReadByte()
        if ($b -lt 0) { throw "stream ended" }
        [void]$header.Append([char]$b)
        if ($prev[0] -eq 13 -and $prev[1] -eq 10 -and $prev[2] -eq 13 -and $b -eq 10) { break }
        $prev[0] = $prev[1]; $prev[1] = $prev[2]; $prev[2] = $b
    }
    $h = $header.ToString().TrimEnd("`r", "`n")
    $lenMatch = [regex]::Match($h, 'Content-Length:\s*(\d+)')
    if (-not $lenMatch.Success) { throw "bad header: $h" }
    $len = [int]$lenMatch.Groups[1].Value
    $buf = New-Object byte[] $len
    $read = 0
    while ($read -lt $len) {
        if ([DateTime]::Now -gt $deadline) { throw "body read timeout" }
        $n = $p.StandardOutput.BaseStream.Read($buf, $read, $len - $read)
        if ($n -le 0) { throw "stream ended mid-body" }
        $read += $n
    }
    return [System.Text.Encoding]::UTF8.GetString($buf)
}

$java = "$env:JAVA_HOME\bin\java.exe"
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $java
$psi.Arguments = "-cp `"$cp`" io.mistream.jvm.Main"
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true

$p = [System.Diagnostics.Process]::Start($psi)

try {
    Send-Frame $p '{"jsonrpc":"2.0","id":1,"method":"runtime.handshake","params":{"protocolVersion":1}}'
    $hs = Read-Frame $p | ConvertFrom-Json
    Write-Output "== handshake ok =="

    $create = @{ jsonrpc = '2.0'; id = 2; method = 'spider.create'; params = @{
        instanceId = 'test-config'; jarPath = $JarPath; className = 'com.github.catvod.spider.Config'
    } } | ConvertTo-Json -Compress -Depth 5
    Send-Frame $p $create
    $cr = Read-Frame $p 60 | ConvertFrom-Json
    Write-Output "== create Config =="
    if ($cr.error) {
        Write-Output ("ERROR code: " + $cr.error.code)
        Write-Output ("ERROR msg: " + $cr.error.message)
        Write-Output ("ERROR stack: " + $cr.error.data.stack)
    } else {
        Write-Output ("capabilities: " + ($cr.result.capabilities -join ','))
    }

    if (-not $cr.error) {
        $homeReq = @{ jsonrpc = '2.0'; id = 3; method = 'spider.home'; params = @{
            instanceId = 'test-config'; args = @($false)
        } } | ConvertTo-Json -Compress -Depth 5
        Send-Frame $p $homeReq
        $hr = Read-Frame $p 60 | ConvertFrom-Json
        Write-Output "== Config.homeContent =="
        if ($hr.error) {
            Write-Output ("ERROR code: " + $hr.error.code)
            Write-Output ("ERROR msg: " + $hr.error.message)
            Write-Output ("ERROR stack: " + $hr.error.data.stack)
        } else {
            $body = $hr.result
            Write-Output ("len: " + $body.Length)
            Write-Output $body.Substring(0, [Math]::Min(800, $body.Length))
        }
    }
} catch {
    Write-Output ("EXCEPTION: " + $_.Exception.Message)
    $p.StandardError.ReadToEnd() | Write-Output
} finally {
    if (-not $p.HasExited) { $p.Kill() }
    $p.Dispose()
}