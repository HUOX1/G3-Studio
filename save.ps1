# G3-Studio 一键保存并推送
# 用法:
#   双击 save.cmd            -> 提交信息自动用时间戳
#   save.cmd "改了什么"       -> 提交信息用你写的内容
#
# 代理策略: 自动探测 Clash 端口 7897
#   在线 -> 走代理    离线 -> 尝试直连（国内通常不通，会提示你开 Clash）

$ErrorActionPreference = "Continue"

$repo      = "D:\Sortware\本地终端开发\G3-Studio"
$gitExe    = "D:\Sortware\Git\bin\git.exe"
$proxyPort = 7897

function Test-LocalPort {
    param([int]$Port)
    $c = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $c.BeginConnect("127.0.0.1", $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne(300)) { return $false }
        $c.EndConnect($iar)
        return $true
    } catch {
        return $false
    } finally {
        $c.Close()
    }
}

# 调用 git 并安全回收 stdout/stderr（PS 5.1 下 2>&1 会把 stderr 变成 ErrorRecord）
function Invoke-Git {
    param([string[]]$GitArgs)
    $raw = & $script:git @GitArgs 2>&1
    $code = $LASTEXITCODE
    $lines = @()
    foreach ($item in $raw) {
        if ($item -is [System.Management.Automation.ErrorRecord]) {
            $lines += $item.Exception.Message
        } else {
            $lines += [string]$item
        }
    }
    return [pscustomobject]@{ Code = $code; Lines = $lines }
}

function Show-Log {
    param($Lines)
    foreach ($l in $Lines) {
        if (-not $l -or $l.Trim() -eq "") { continue }
        if ($l -match "^(warning|hint):") { continue }
        Write-Host "    $l" -ForegroundColor DarkGray
    }
}

if (-not (Test-Path $repo)) {
    Write-Host "[错误] 项目目录不存在: $repo" -ForegroundColor Red
    exit 1
}

$script:git = if (Test-Path $gitExe) { $gitExe } else { "git" }
Set-Location $repo

# ---------- 1. 代理 ----------
if (Test-LocalPort $proxyPort) {
    $netArgs = @("-c", "http.proxy=http://127.0.0.1:$proxyPort", "-c", "https.proxy=http://127.0.0.1:$proxyPort")
    Write-Host "[代理] Clash 在线 (:$proxyPort)，走代理" -ForegroundColor DarkGray
} else {
    $netArgs = @("-c", "http.proxy=", "-c", "https.proxy=")
    Write-Host "[代理] 未检测到 :$proxyPort，尝试直连" -ForegroundColor Yellow
}
$netArgs += @("-c", "http.sslBackend=openssl")

# ---------- 2. 提交 ----------
$st = Invoke-Git @("-c", "core.quotepath=false", "status", "--porcelain")
$changed = @($st.Lines | Where-Object { $_ -and $_.Trim() -ne "" })

if ($changed.Count -eq 0) {
    Write-Host "[变更] 工作区干净，无需提交" -ForegroundColor Green
} else {
    Write-Host "[变更] $($changed.Count) 项改动" -ForegroundColor Cyan
    [void](Invoke-Git @("add", "-A"))

    $msg = if ($args.Count -gt 0 -and $args[0]) { [string]$args[0] } else { "update: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") }

    # 用带 BOM 的 UTF-8 文件传提交信息，避免中文被代码页搞乱
    $msgFile = Join-Path $env:TEMP "g3_auto_commit_msg.txt"
    [System.IO.File]::WriteAllText($msgFile, $msg + "`n", (New-Object System.Text.UTF8Encoding($false)))
    $cm = Invoke-Git @("commit", "-F", $msgFile, "--quiet")
    Remove-Item $msgFile -Force -ErrorAction SilentlyContinue

    if ($cm.Code -ne 0) {
        Write-Host "[失败] 提交未成功" -ForegroundColor Red
        Show-Log $cm.Lines
        exit $cm.Code
    }
    Write-Host "[提交] $msg" -ForegroundColor Cyan
}

# ---------- 3. 推送 ----------
Write-Host "[推送] 正在同步到 GitHub ..." -ForegroundColor Cyan
$pushArgs = $netArgs + @("push", "--quiet", "origin", "main")
$ps = Invoke-Git $pushArgs

if ($ps.Code -eq 0) {
    Write-Host "[完成] 已同步" -ForegroundColor Green
    Show-Log $ps.Lines
    $head = (Invoke-Git @("rev-parse", "--short", "HEAD")).Lines -join ""
    Write-Host ""
    Write-Host "    当前提交: $head" -ForegroundColor DarkGray
} else {
    Write-Host "[失败] 推送未成功 (退出码 $($ps.Code))" -ForegroundColor Red
    Show-Log $ps.Lines
    Write-Host ""
    Write-Host "排查顺序:" -ForegroundColor Yellow
    Write-Host "    1. 打开 Clash Verge，确认端口是 $proxyPort"
    Write-Host "    2. 浏览器能不能打开 github.com"
    Write-Host "    3. 凭据过期的话，终端手动跑一次 git push 重新登录"
    exit $ps.Code
}
