param(
    [string]$ProjectRoot = '',
    [string]$PatchPath = ''
)

# Compatible with Windows PowerShell 5.1. The patch is applied to staged copies,
# after normalizing line endings there; the original files are replaced only
# after the staged result passes all checks.
$ErrorActionPreference = 'Stop'
$script:Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$script:ProjectMarkerFiles = @(
    'g3_frontend/scripts/game_section.gd',
    'g3_frontend/scripts/main.gd',
    'g3_frontend/scripts/navigation_drawer.gd'
)
$script:PatchTargetFiles = @()
$script:OriginalTargetFiles = @{}

function Write-Info([string]$Message) { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "[ OK ] $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Fail([string]$Message) { Write-Host "[FAIL] $Message" -ForegroundColor Red }

function Normalize-PathArgument([string]$Value, [string]$Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Label is empty."
    }

    $clean = $Value.Trim()
    if ($clean.Length -ge 2) {
        $doubleQuoted = $clean.StartsWith('"') -and $clean.EndsWith('"')
        $singleQuoted = $clean.StartsWith("'") -and $clean.EndsWith("'")
        if ($doubleQuoted -or $singleQuoted) {
            $clean = $clean.Substring(1, $clean.Length - 2)
        }
    }

    if ($clean.IndexOf([char]0) -ge 0 -or $clean.Contains("`r") -or $clean.Contains("`n")) {
        throw "$Label contains a NUL or line-break character. Re-enter the path without hidden characters."
    }
    if ($clean.Contains('"')) {
        throw "$Label contains a literal double-quote character. Pass the path as a quoted argument; do not include quote characters in the value itself."
    }
    return $clean
}

function Resolve-DirectoryPath([string]$Value, [string]$Label) {
    $clean = Normalize-PathArgument $Value $Label
    try {
        $item = Get-Item -LiteralPath $clean -ErrorAction Stop
    }
    catch {
        throw "$Label cannot be opened: [$clean]. PowerShell reported: $($_.Exception.Message)"
    }
    if (-not $item.PSIsContainer) {
        throw "$Label is not a directory: [$clean]"
    }
    return $item.FullName
}

function Resolve-PatchFile([string]$RequestedPath) {
    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        $clean = Normalize-PathArgument $RequestedPath 'PatchPath'
        if (-not [System.IO.Path]::IsPathRooted($clean)) {
            $clean = Join-Path $PSScriptRoot $clean
        }
        try {
            $item = Get-Item -LiteralPath $clean -ErrorAction Stop
        }
        catch {
            throw "Patch file cannot be opened: [$clean]. PowerShell reported: $($_.Exception.Message)"
        }
        if ($item.PSIsContainer) {
            throw "PatchPath points to a directory, not a file: [$clean]"
        }
        return $item.FullName
    }

    $preferred = Join-Path $PSScriptRoot 'G3_Nav_Drawer_Spring_Sequence_Fix.patch'
    if (Test-Path -LiteralPath $preferred -PathType Leaf) {
        return (Get-Item -LiteralPath $preferred -ErrorAction Stop).FullName
    }

    $candidates = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.patch' -File -ErrorAction SilentlyContinue)
    if ($candidates.Count -eq 1) {
        return $candidates[0].FullName
    }
    if ($candidates.Count -eq 0) {
        throw "No .patch file was found beside the injector: [$PSScriptRoot]. Put G3_Nav_Drawer_Spring_Sequence_Fix.patch in the same folder."
    }

    $names = ($candidates | ForEach-Object { $_.Name }) -join ', '
    throw "More than one .patch file was found beside the injector: $names. Rename the intended patch to G3_Nav_Drawer_Spring_Sequence_Fix.patch or pass -PatchPath explicitly."
}

function Test-TargetFiles([string]$Directory) {
    foreach ($relativePath in $script:ProjectMarkerFiles) {
        $candidate = Join-Path $Directory $relativePath
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $false
        }
    }
    return $true
}

function ConvertFrom-GitEscapedPath([string]$Value) {
    $bytes = New-Object 'System.Collections.Generic.List[byte]'
    for ($i = 0; $i -lt $Value.Length; $i++) {
        $character = $Value[$i]
        if ($character -eq [char]92) {
            $i++
            if ($i -ge $Value.Length) {
                throw 'Patch contains an incomplete escape in a quoted target path.'
            }
            $escaped = $Value[$i]
            if (($i + 2) -lt $Value.Length -and [string]$escaped -match '^[0-7]$' -and
                [string]$Value[$i + 1] -match '^[0-7]$' -and [string]$Value[$i + 2] -match '^[0-7]$') {
                $octal = [string]$escaped + [string]$Value[$i + 1] + [string]$Value[$i + 2]
                $bytes.Add([byte][Convert]::ToInt32($octal, 8))
                $i += 2
                continue
            }
            switch ([string]$escaped) {
                't' { $bytes.Add([byte]9) }
                'n' { $bytes.Add([byte]10) }
                'r' { $bytes.Add([byte]13) }
                'b' { $bytes.Add([byte]8) }
                'f' { $bytes.Add([byte]12) }
                'v' { $bytes.Add([byte]11) }
                '\' { $bytes.Add([byte]92) }
                '"' { $bytes.Add([byte]34) }
                default { throw "Patch contains an unsupported escape in a quoted target path: [\$escaped]" }
            }
        }
        else {
            foreach ($byte in [System.Text.Encoding]::UTF8.GetBytes([string]$character)) {
                $bytes.Add($byte)
            }
        }
    }
    return [System.Text.UTF8Encoding]::new($false, $true).GetString($bytes.ToArray())
}

function Get-PatchTargetFiles([string]$Path) {
    $patchText = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $targets = New-Object 'System.Collections.Generic.List[string]'
    $targetSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($line in [regex]::Split($patchText, "`r?`n")) {
        $leftPath = $null
        $rightPath = $null
        if ($line -match '^diff --git a/(.+) b/(.+)$') {
            $leftPath = $Matches[1]
            $rightPath = $Matches[2]
        }
        elseif ($line -match '^diff --git "a/(.+)" "b/(.+)"$') {
            $leftPath = ConvertFrom-GitEscapedPath $Matches[1]
            $rightPath = ConvertFrom-GitEscapedPath $Matches[2]
        }
        else {
            continue
        }

        foreach ($relativePath in @($leftPath, $rightPath)) {
            $relativePath = $relativePath.Replace('\', '/')
            if ([string]::IsNullOrWhiteSpace($relativePath) -or
                [System.IO.Path]::IsPathRooted($relativePath) -or
                $relativePath -match '^[A-Za-z]:' -or
                @($relativePath.Split('/')) -contains '..' -or
                @($relativePath.Split('/')) -contains '.') {
                throw "Patch contains an unsafe project-relative path: [$relativePath]"
            }
            if ($relativePath -match '(^|/)(\.git|\.venv|\.pytest_cache)(/|$)') {
                throw "Patch target is outside the source scope: [$relativePath]"
            }
            if ($targetSet.Add($relativePath)) {
                $targets.Add($relativePath)
            }
        }
    }

    if ($targets.Count -eq 0) {
        throw 'Patch does not contain any supported diff --git file headers. No project files were changed.'
    }
    return @($targets)
}

function Find-ProjectRoot([string]$StartDirectory) {
    $start = Resolve-DirectoryPath $StartDirectory 'ProjectRoot'
    $directory = Get-Item -LiteralPath $start -ErrorAction Stop
    $gitRootSeen = $null

    while ($null -ne $directory) {
        if (Test-TargetFiles $directory.FullName) {
            return $directory.FullName
        }

        $gitMarker = Join-Path $directory.FullName '.git'
        if (($null -eq $gitRootSeen) -and (Test-Path -LiteralPath $gitMarker)) {
            $gitRootSeen = $directory.FullName
        }
        $directory = $directory.Parent
    }

    if ($null -ne $gitRootSeen) {
        throw "A Git root was found at [$gitRootSeen], but the expected G3 project marker files were not found there or below the starting path. Expected: $($script:ProjectMarkerFiles -join ', ')."
    }
    throw "Could not locate the G3 project from [$start]. This injector searches upward for the expected G3 project marker files instead of relying on Git's localized console output. Put the injector in the project root, or run it with -ProjectRoot pointing to a folder inside the project."
}

function Convert-FileToLf([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes -contains 0) {
        return 'BINARY'
    }
    try {
        $strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
        $text = $strictUtf8.GetString($bytes)
        if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) {
            $text = $text.Substring(1)
        }
    }
    catch {
        return 'BINARY'
    }
    $withoutCrlf = $text.Replace("`r`n", '')
    if ($withoutCrlf.Contains("`r")) {
        throw "Source file contains standalone CR characters and cannot be safely normalized: [$Path]"
    }
    $hasCrlf = $text.Contains("`r`n")
    $hasBareLf = $withoutCrlf.Contains("`n")
    if ($hasCrlf -and $hasBareLf) {
        throw "Source file already has mixed CRLF/LF line endings: [$Path]. No project files were changed. Normalize this file first, or provide a consistent source copy."
    }

    if ($hasCrlf) { $mode = 'CRLF' } else { $mode = 'LF' }
    $normalized = $text.Replace("`r`n", "`n")
    [System.IO.File]::WriteAllText($Path, $normalized, $script:Utf8NoBom)
    return $mode
}

function Restore-FileLineEnding([string]$Path, [string]$Mode) {
    if ($Mode -eq 'BINARY') {
        return
    }
    $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $text = $text.Replace("`r`n", "`n")
    if ($text.Contains("`r")) {
        throw "Unexpected standalone CR found while restoring line endings: [$Path]"
    }
    if ($Mode -eq 'CRLF') {
        $text = $text.Replace("`n", "`r`n")
    }
    [System.IO.File]::WriteAllText($Path, $text, $script:Utf8NoBom)
}


function Show-PatchMismatchDiagnostics([string]$PatchPath, [string]$ProjectDirectory, [object[]]$NativeOutput) {
    Write-Host ''
    Write-Warn 'Patch mismatch diagnostics (read-only; project files remain unchanged):'

    $outputText = (@($NativeOutput) | ForEach-Object { [string]$_ }) -join "`n"
    $mismatchItems = New-Object 'System.Collections.Generic.List[object]'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($match in [regex]::Matches($outputText, '(?im)patch failed:\s*(.+?):(\d+)')) {
        $relative = $match.Groups[1].Value.Trim().Replace('\', '/')
        $lineNumber = 0
        [void][int]::TryParse($match.Groups[2].Value, [ref]$lineNumber)
        $key = "$relative`:$lineNumber"
        if ($seen.Add($key)) {
            $mismatchItems.Add([pscustomobject]@{ RelativePath = $relative; LineNumber = $lineNumber })
        }
    }

    if ($mismatchItems.Count -eq 0) {
        Write-Warn 'Git did not report a parseable "patch failed: path:line" location.'
        Write-Host 'Native Git output:'
        Show-NativeOutput ([pscustomobject]@{ Output = @($NativeOutput) })
        Write-Host 'Patch target files:'
        foreach ($relative in $script:PatchTargetFiles) {
            Write-Host "  - $relative"
        }
        return
    }

    $patchLines = [regex]::Split([System.IO.File]::ReadAllText($PatchPath, [System.Text.Encoding]::UTF8).Replace("`r`n", "`n"), "`n")
    foreach ($item in $mismatchItems) {
        $relative = $item.RelativePath
        $lineNumber = $item.LineNumber

        # Only inspect files already validated as safe patch targets.
        if (-not ($script:PatchTargetFiles | Where-Object { $_.Replace('\', '/') -ieq $relative })) {
            Write-Warn "Git reported a path that is not in the parsed target list: [$relative]. Skipping source inspection."
            continue
        }

        Write-Host ''
        Write-Host "  [MISMATCH] $relative (Git context line: $lineNumber)" -ForegroundColor Yellow
        $sourcePath = Join-Path $ProjectDirectory ($relative.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
            $sourceLines = [System.IO.File]::ReadAllLines($sourcePath, [System.Text.Encoding]::UTF8)
            $hash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
            Write-Host "  Current source SHA256: $hash"
            $first = [Math]::Max(1, $lineNumber - 6)
            $last = [Math]::Min($sourceLines.Length, $lineNumber + 6)
            Write-Host "  Current source lines ${first}-${last}:"
            for ($n = $first; $n -le $last; $n++) {
                $marker = if ($n -eq $lineNumber) { '>>' } else { '  ' }
                Write-Host ('  {0} {1,6}: {2}' -f $marker, $n, $sourceLines[$n - 1])
            }
        }
        else {
            Write-Warn "Current target file does not exist: [$sourcePath]"
        }

        # Find this file's diff section and show relevant hunk headers/context.
        $sectionStart = -1
        $sectionEnd = $patchLines.Length
        for ($i = 0; $i -lt $patchLines.Length; $i++) {
            if ($patchLines[$i] -match '^diff --git a/(.+) b/(.+)$') {
                $candidate = $Matches[1].Replace('\', '/')
                if ($candidate -ieq $relative) {
                    $sectionStart = $i
                    for ($j = $i + 1; $j -lt $patchLines.Length; $j++) {
                        if ($patchLines[$j] -match '^diff --git ') {
                            $sectionEnd = $j
                            break
                        }
                    }
                    break
                }
            }
            elseif ($patchLines[$i] -match '^diff --git "a/(.+)" "b/(.+)"$') {
                try { $candidate = (ConvertFrom-GitEscapedPath $Matches[1]).Replace('\', '/') } catch { $candidate = '' }
                if ($candidate -ieq $relative) {
                    $sectionStart = $i
                    for ($j = $i + 1; $j -lt $patchLines.Length; $j++) {
                        if ($patchLines[$j] -match '^diff --git ') {
                            $sectionEnd = $j
                            break
                        }
                    }
                    break
                }
            }
        }

        if ($sectionStart -ge 0) {
            Write-Host '  Patch hunk context (first 12 lines per hunk):'
            $shownHunks = 0
            for ($i = $sectionStart; $i -lt $sectionEnd; $i++) {
                if ($patchLines[$i] -match '^@@') {
                    Write-Host "    $($patchLines[$i])" -ForegroundColor Cyan
                    $shown = 0
                    for ($j = $i + 1; $j -lt $sectionEnd -and $shown -lt 12; $j++) {
                        if ($patchLines[$j] -match '^@@|^diff --git ') { break }
                        if ($patchLines[$j] -match '^[ +\-\\]') {
                            Write-Host ('      ' + $patchLines[$j])
                            $shown++
                        }
                    }
                    $shownHunks++
                    if ($shownHunks -ge 4) {
                        Write-Host '      ... additional hunks omitted'
                        break
                    }
                }
            }
        }
        else {
            Write-Warn 'Could not locate the matching diff section in the patch file.'
        }
    }

    Write-Host ''
    Write-Info 'Use the reported current-source excerpt and patch hunk to rebuild the patch against this exact source. Do not force-apply.'
}

function Invoke-Git([string[]]$GitArgs) {
    $oldPreference = $ErrorActionPreference
    try {
        # Windows PowerShell 5.1 can turn native stderr into ErrorRecord objects.
        # Capture output and decide using the native process exit code instead.
        $ErrorActionPreference = 'Continue'
        $output = & git @GitArgs 2>&1
        $code = $LASTEXITCODE
        return [pscustomobject]@{ Output = @($output); ExitCode = [int]$code }
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }
}

function Show-NativeOutput($Result) {
    foreach ($line in $Result.Output) {
        if ($null -ne $line -and -not [string]::IsNullOrWhiteSpace([string]$line)) {
            Write-Host ([string]$line)
        }
    }
}

$stageRoot = $null
$backupRoot = $null
$keepBackup = $false
$commitStarted = $false
$alreadyApplied = $false
$exitCode = 0
$eolModes = @{}

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git was not found in PATH. Install Git for Windows or open the Git-enabled terminal and try again.'
    }

    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        $ProjectRoot = $PSScriptRoot
    }
    $projectStart = Resolve-DirectoryPath $ProjectRoot 'ProjectRoot'
    $project = Find-ProjectRoot $projectStart
    $patch = Resolve-PatchFile $PatchPath
    $script:PatchTargetFiles = @(Get-PatchTargetFiles $patch)

    Write-Host '========================================'
    Write-Host 'G3 NAV DRAWER SPRING FIX INJECTOR'
    Write-Host '========================================'
    Write-Info "Project: $project"
    Write-Info "Patch:   $patch"
    Write-Info 'The project files will not be touched until the staged patch passes validation.'

    $stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('G3NavSpringFix_Stage_' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null

    foreach ($relativePath in $script:PatchTargetFiles) {
        $sourcePath = Join-Path $project $relativePath
        $stagePath = Join-Path $stageRoot $relativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $stagePath) -Force | Out-Null
        if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
            Copy-Item -LiteralPath $sourcePath -Destination $stagePath -ErrorAction Stop
            $script:OriginalTargetFiles[$relativePath] = $true
            $eolModes[$relativePath] = Convert-FileToLf $stagePath
        }
    }

    # Normalize the patch itself to LF too. Git sees only ASCII relative paths in
    # the staging directory; Chinese project paths never need to pass through git.exe.
    $patchText = [System.IO.File]::ReadAllText($patch, [System.Text.Encoding]::UTF8)
    $patchText = $patchText.Replace("`r`n", "`n")
    if ($patchText.Contains("`r")) {
        throw 'Patch contains standalone CR characters. Save the patch as UTF-8 text and retry.'
    }
    [System.IO.File]::WriteAllText((Join-Path $stageRoot 'fix.patch'), $patchText, $script:Utf8NoBom)

    Push-Location -LiteralPath $stageRoot
    try {
        $reverseResult = Invoke-Git @('apply', '--reverse', '--check', '--ignore-whitespace', '--whitespace=error', 'fix.patch')
        if ($reverseResult.ExitCode -eq 0) {
            $alreadyApplied = $true
        }
        else {
            Write-Info 'Checking the patch against staged copies of all affected source files...'
            $checkResult = Invoke-Git @('apply', '--check', '--whitespace=error', 'fix.patch')
            if ($checkResult.ExitCode -ne 0) {
                Show-NativeOutput $checkResult
                Show-PatchMismatchDiagnostics $patch $project $checkResult.Output
                throw 'Patch context does not match the current source. No project files were changed; do not force-apply it. Use the diagnostics above to rebuild the patch against the current source version.'
            }
            Write-Ok 'Staged pre-check passed.'

            $applyResult = Invoke-Git @('apply', '--whitespace=error', 'fix.patch')
            if ($applyResult.ExitCode -ne 0) {
                Show-NativeOutput $applyResult
                throw 'Git failed to apply the patch to staged copies. No project files were changed.'
            }
        }
    }
    finally {
        Pop-Location
    }

    if ($alreadyApplied) {
        Write-Ok 'Patch is already applied. No project files were changed.'
    }
    else {
        foreach ($relativePath in $script:PatchTargetFiles) {
            $stagedPath = Join-Path $stageRoot $relativePath
            if ((Test-Path -LiteralPath $stagedPath -PathType Leaf) -and $eolModes.ContainsKey($relativePath)) {
                Restore-FileLineEnding $stagedPath $eolModes[$relativePath]
            }
        }

        # Verify the patch is represented in the staged result even after restoring
        # each file's original LF/CRLF convention.
        Push-Location -LiteralPath $stageRoot
        try {
            $verifyResult = Invoke-Git @('apply', '--reverse', '--check', '--ignore-whitespace', '--whitespace=error', 'fix.patch')
            if ($verifyResult.ExitCode -ne 0) {
                Show-NativeOutput $verifyResult
                throw 'The staged result failed its final reverse-check. Project files were not changed.'
            }
        }
        finally {
            Pop-Location
        }

        $backupRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('G3NavSpringFix_Backup_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
        foreach ($relativePath in $script:PatchTargetFiles) {
            $sourcePath = Join-Path $project $relativePath
            if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
                $backupPath = Join-Path $backupRoot $relativePath
                New-Item -ItemType Directory -Path (Split-Path -Parent $backupPath) -Force | Out-Null
                Copy-Item -LiteralPath $sourcePath -Destination $backupPath -ErrorAction Stop
            }
        }
        Write-Info "Byte-for-byte backup: $backupRoot"

        $commitStarted = $true
        foreach ($relativePath in $script:PatchTargetFiles) {
            $stagedPath = Join-Path $stageRoot $relativePath
            $targetPath = Join-Path $project $relativePath
            if (Test-Path -LiteralPath $stagedPath -PathType Leaf) {
                New-Item -ItemType Directory -Path (Split-Path -Parent $targetPath) -Force | Out-Null
                Copy-Item -LiteralPath $stagedPath -Destination $targetPath -Force -ErrorAction Stop
            }
            elseif (Test-Path -LiteralPath $targetPath -PathType Leaf) {
                Remove-Item -LiteralPath $targetPath -Force -ErrorAction Stop
            }
        }

        foreach ($relativePath in $script:PatchTargetFiles) {
            $stagedPath = Join-Path $stageRoot $relativePath
            $targetPath = Join-Path $project $relativePath
            $stagedExists = Test-Path -LiteralPath $stagedPath -PathType Leaf
            $targetExists = Test-Path -LiteralPath $targetPath -PathType Leaf
            if ($stagedExists -ne $targetExists) {
                throw "Final file verification failed: $relativePath"
            }
            if ($stagedExists) {
                $stagedHash = (Get-FileHash -LiteralPath $stagedPath -Algorithm SHA256).Hash
                $targetHash = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash
                if ($stagedHash -ne $targetHash) {
                    throw "Final file verification failed: $relativePath"
                }
            }
        }

        $keepBackup = $true
        Write-Ok 'Patch applied and verified.'
        Write-Ok 'Original line-ending style was preserved for each target file.'
        Write-Host "Backup retained at: $backupRoot"
        Write-Host 'Next: open Godot and test drawer open/close sequencing.'
    }
}
catch {
    Write-Fail $_.Exception.Message
    if ($commitStarted -and $backupRoot -and (Test-Path -LiteralPath $backupRoot -PathType Container)) {
        Write-Warn 'A write failed during final replacement. Restoring the affected files from the byte-for-byte backup...'
        $restoreFailed = $false
        foreach ($relativePath in $script:PatchTargetFiles) {
            $backupPath = Join-Path $backupRoot $relativePath
            $targetPath = Join-Path $project $relativePath
            try {
                if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
                    New-Item -ItemType Directory -Path (Split-Path -Parent $targetPath) -Force | Out-Null
                    Copy-Item -LiteralPath $backupPath -Destination $targetPath -Force -ErrorAction Stop
                }
                elseif (-not $script:OriginalTargetFiles.ContainsKey($relativePath) -and
                    (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
                    Remove-Item -LiteralPath $targetPath -Force -ErrorAction Stop
                }
            }
            catch {
                $restoreFailed = $true
                Write-Fail "Could not restore $relativePath : $($_.Exception.Message)"
            }
        }
        $keepBackup = $true
        if (-not $restoreFailed) {
            Write-Ok 'Target files were restored to their pre-patch bytes.'
        }
        Write-Warn "Backup retained for manual recovery: $backupRoot"
    }
    Write-Host 'No git reset, checkout, clean, stash, or commit was performed.'
    $exitCode = 1
}
finally {
    if ($stageRoot -and (Test-Path -LiteralPath $stageRoot -PathType Container)) {
        Remove-Item -LiteralPath $stageRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($backupRoot -and -not $keepBackup -and (Test-Path -LiteralPath $backupRoot -PathType Container)) {
        Remove-Item -LiteralPath $backupRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

exit $exitCode
