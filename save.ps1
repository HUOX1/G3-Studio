# G3-Studio 一键保存并推送
# 用法:
#   双击 save.cmd            -> 提交信息自动用时间戳
#   save.cmd "改了什么"       -> 提交信息用你写的内容

$ErrorActionPreference = "Stop"

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

function Write-Step {
    param([string]$Text, [string]$Color = "Cyan")
    Write-Host $Text -ForegroundColor $Color
}

if (-not (Test-Path $repo)) {
    Write-Step "[错误] 项目目录不存在: $repo" "Red"
    exit 1
}

$git = if (Test-Path $gitExe) { $gitExe } else { "git" }
Set-Location $repo

# ---------- 代理 ----------
if (Test-LocalPort $proxyPort) {
    $netArgs = @("-c", "http.proxy=http://127.0.0.1:$proxyPort", "-c", "https.proxy=http://127.0.0.1:$proxyPort")
    Write-Step "[代理] Clash 在线 (:$proxyPort)，走代理" "DarkGray"
} else {
    $netArgs = @("-c", "http.proxy=", "-c", "https.proxy=")
    Write-Step "[代理] 未检测到 :$proxyPort，尝试直连" "Yellow"
}
$netArgs += @("-c", "http.sslBackend=openssl")

# ---------- 提交 ----------
$status = & $git status --porcelain
if (-not $status) {
    Write-Step "[变更] 工作区干净，无需提交" "Green"
} else {
    $count = ($status | Measure-Object).Count
    Write-Step "[变更] $count 项改动" "Cyan"

    & $git add -A

    $msg = if ($args.Count -gt 0 -and $args[0]) { [string]$args[0] } else { "update: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") }

    # 用 UTF-8 文件传提交信息，避免中文被控制台代码页搞乱
    $msgFile = Join-Path $env:TEMP "g3_auto_commit_msg.txt"
    [System.IO.File]::WriteAllText($msgFile, $msg + "`n", (New-Object System.Text.UTF8Encoding($false)))
    & $git commit -F $msgFile --quiet
    Remove-Item $msgFile -Force -ErrorAction SilentlyContinue
    Write-Step "[提交] $msg" "Cyan"
}

# ---------- 推送 ----------
Write-Step "[推送] 正在同步到 GitHub ..." "Cyan"
$pushOut = & $git @netArgs push origin main 2>&1
$code = $LASTEXITCODE

if ($code -eq 0) {
    Write-Step "[完成] 已同步" "Green"
    $pushOut | ForEach-Object { if ($_ -match '\S') { "    $_" } }
    Write-Host ""
    $head = & $git rev-parse --short HEAD
    $when = & $git log -1 --date=format:"%Y-%m-%d %H:%M" --pretty=format:"%ad"
    Write-Host "    当前提交: $head    时间: $when" -ForegroundColor DarkGray
} else {
    Write-Step "[失败] 推送未成功" "Red"
    $pushOut | ForEach-Object { if ($_ -match '\S') { "    $_" } }
    Write-Host ""
    Write-Step "排查顺序:" "Yellow"
    Write-Host "    1. 打开 Clash Verge，确认端口是 $proxyPort"
    Write-Host "    2. 确认 GitHub 能正常访问"
    Write-Host "    3. 凭据过期的话，终端跑一次 git push 重新登录"
}

exit $code
