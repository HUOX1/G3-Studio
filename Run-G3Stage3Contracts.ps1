param(
    [string]$GodotPath = '',
    [string]$ProjectRoot = ''
)

# G3 Stage 6.1 cumulative regression runner. Windows PowerShell 5.1 compatible.
# Runs each existing contract scene in a separate headless Godot process.
# Does not edit source files, database files, or user settings.
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = $PSScriptRoot
}
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot -ErrorAction Stop).Path
$frontend = Join-Path $ProjectRoot 'g3_frontend'
if (-not (Test-Path -LiteralPath (Join-Path $frontend 'project.godot') -PathType Leaf)) {
    throw "Not a G3 project root: $ProjectRoot"
}

if ([string]::IsNullOrWhiteSpace($GodotPath) -and -not [string]::IsNullOrWhiteSpace($env:GODOT_PATH)) {
    $GodotPath = $env:GODOT_PATH
}
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    foreach ($commandName in @('godot', 'godot4', 'Godot_v4.7.2-stable_win64_console.exe')) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($null -ne $command -and -not [string]::IsNullOrWhiteSpace($command.Source)) {
            $GodotPath = $command.Source
            break
        }
    }
}
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    throw 'Godot not found. Pass -GodotPath "C:\path\to\Godot_console.exe" (or set GODOT_PATH).'
}
$GodotPath = (Resolve-Path -LiteralPath $GodotPath -ErrorAction Stop).Path

$tests = @(
    @{ Scene = 'backend_router_contract.tscn'; Marker = 'BACKEND ROUTER SCENE CONTRACT PASS: 27 checks' },
    @{ Scene = 'library_scan_controller_contract.tscn'; Marker = 'LIBRARY SCAN CONTROLLER CONTRACT PASS: 24 checks' },
    @{ Scene = 'library_scan_import_contract.tscn'; Marker = 'LIBRARY SCAN IMPORT CONTRACT PASS: 17 checks' },
    @{ Scene = 'library_scan_platform_import_contract.tscn'; Marker = 'LIBRARY SCAN PLATFORM IMPORT CONTRACT PASS: 40 checks' },
    @{ Scene = 'movie_controller_contract.tscn'; Marker = 'MOVIE CONTROLLER CONTRACT PASS: 42 checks' },
    @{ Scene = 'movie_requests_contract.tscn'; Marker = 'MOVIE REQUESTS CONTRACT PASS: 19 checks' },
    @{ Scene = 'movie_writes_contract.tscn'; Marker = 'MOVIE WRITES CONTRACT PASS: 23 checks' },
    @{ Scene = 'movie_assets_contract.tscn'; Marker = 'MOVIE ASSETS CONTRACT PASS: 32 checks' },
    @{ Scene = 'movie_scan_tmdb_contract.tscn'; Marker = 'MOVIE SCAN TMDB CONTRACT PASS: 20 checks' },
    @{ Scene = 'movie_tmdb_apply_posters_contract.tscn'; Marker = 'MOVIE TMDB POSTERS CONTRACT PASS: 29 checks' },
    @{ Scene = 'movie_play_contract.tscn'; Marker = 'MOVIE PLAY CONTRACT PASS: 20 checks' },
    @{ Scene = 'movie_play_event_order_contract.tscn'; Marker = 'MOVIE PLAY EVENT ORDER CONTRACT PASS: 16 checks' },
    @{ Scene = 'movie_play_session_order_contract.tscn'; Marker = 'MOVIE PLAY SESSION ORDER CONTRACT PASS: 14 checks' }
    @{ Scene = 'movie_play_overlap_contract.tscn'; Marker = 'MOVIE PLAY OVERLAP CONTRACT PASS: 16 checks' }
    @{ Scene = 'movie_remaining_requests_contract.tscn'; Marker = 'MOVIE REMAINING REQUESTS CONTRACT PASS: 17 checks' }
    @{ Scene = 'game_controller_contract.tscn'; Marker = 'GAME CONTROLLER CONTRACT PASS: 44 checks' }
    @{ Scene = 'game_metadata_contract.tscn'; Marker = 'GAME METADATA CONTRACT PASS: 29 checks' }
    @{ Scene = 'game_crud_contract.tscn'; Marker = 'GAME CRUD CONTRACT PASS: 33 checks' }
    @{ Scene = 'game_steam_scrape_contract.tscn'; Marker = 'GAME STEAM SCRAPE CONTRACT PASS: 36 checks' }
    @{ Scene = 'game_sgdb_contract.tscn'; Marker = 'GAME SGDB CONTRACT PASS: 37 checks' }
    @{ Scene = 'game_play_request_contract.tscn'; Marker = 'GAME PLAY REQUEST CONTRACT PASS: 29 checks' }
    @{ Scene = 'game_batch_remove_contract.tscn'; Marker = 'GAME BATCH REMOVE CONTRACT PASS: 16 checks' }
    @{ Scene = 'system_settings_controller_contract.tscn'; Marker = 'SYSTEM SETTINGS CONTROLLER CONTRACT PASS: 61 checks' }
    @{ Scene = 'system_settings_writes_contract.tscn'; Marker = 'SYSTEM SETTINGS WRITES CONTRACT PASS: 47 checks' }
    @{ Scene = 'system_settings_updates_contract.tscn'; Marker = 'SYSTEM SETTINGS UPDATES CONTRACT PASS: 37 checks' }
    @{ Scene = 'system_settings_specialized_contract.tscn'; Marker = 'SYSTEM SETTINGS SPECIALIZED CONTRACT PASS: 32 checks' }
    @{ Scene = 'cover_tool_controller_contract.tscn'; Marker = 'COVER TOOL CONTROLLER CONTRACT PASS: 53 checks' }
    @{ Scene = 'emulator_reads_contract.tscn'; Marker = 'EMULATOR READS CONTRACT PASS: 33 checks' }
    @{ Scene = 'emulator_writes_contract.tscn'; Marker = 'EMULATOR WRITES CONTRACT PASS: 43 checks' }
    @{ Scene = 'system_app_info_reads_contract.tscn'; Marker = 'SYSTEM APP INFO READS CONTRACT PASS: 43 checks' }
    @{ Scene = 'render_ownership_contract.tscn'; Marker = 'RENDER OWNERSHIP CONTRACT PASS: 44 checks' }
    @{ Scene = 'render_ownership_integration_contract.tscn'; Marker = 'RENDER OWNERSHIP INTEGRATION CONTRACT PASS: 36 checks' }
    @{ Scene = 'render_ownership_exit_order_contract.tscn'; Marker = 'RENDER OWNERSHIP EXIT ORDER CONTRACT PASS: 29 checks' }
    @{ Scene = 'backend_connection_epoch_contract.tscn'; Marker = 'BACKEND CONNECTION EPOCH CONTRACT PASS: 27 checks' }
    @{ Scene = 'steam_batch_scrape_coordinator_contract.tscn'; Marker = 'STEAM BATCH SCRAPE COORDINATOR CONTRACT PASS: 61 checks' }
    @{ Scene = 'steam_batch_scrape_main_integration_contract.tscn'; Marker = 'STEAM BATCH SCRAPE MAIN INTEGRATION CONTRACT PASS: 34 checks' }
    @{ Scene = 'movie_info_view_builder_contract.tscn'; Marker = 'MOVIE INFO VIEW BUILDER CONTRACT PASS: 27 checks' }
    @{ Scene = 'fontset_overview_builder_contract.tscn'; Marker = 'FONTSET OVERVIEW BUILDER CONTRACT PASS: 38 checks' }
    @{ Scene = 'system_home_view_builder_contract.tscn'; Marker = 'SYSTEM HOME VIEW BUILDER CONTRACT PASS: 38 checks' }
    @{ Scene = 'movie_bottom_overlay_builder_contract.tscn'; Marker = 'MOVIE BOTTOM OVERLAY BUILDER CONTRACT PASS: 43 checks' }
    @{ Scene = 'movie_dialog_assembly_builder_contract.tscn'; Marker = 'MOVIE DIALOG ASSEMBLY BUILDER CONTRACT PASS: 50 checks' }
    @{ Scene = 'game_dialog_assembly_builder_contract.tscn'; Marker = 'GAME DIALOG ASSEMBLY BUILDER CONTRACT PASS: 56 checks' }
    @{ Scene = 'library_scan_presentation_contract.tscn'; Marker = 'LIBRARY SCAN PRESENTATION CONTRACT PASS: 65 checks' }
    @{ Scene = 'library_scan_import_payload_builder_contract.tscn'; Marker = 'LIBRARY SCAN IMPORT PAYLOAD BUILDER CONTRACT PASS: 59 checks' }
    @{ Scene = 'library_scan_import_presentation_contract.tscn'; Marker = 'LIBRARY SCAN IMPORT PRESENTATION CONTRACT PASS: 56 checks' }
    @{ Scene = 'emulator_list_view_builder_contract.tscn'; Marker = 'EMULATOR LIST VIEW BUILDER CONTRACT PASS: 38 checks' }
    @{ Scene = 'cover_tool_presentation_contract.tscn'; Marker = 'COVER TOOL PRESENTATION CONTRACT PASS: 43 checks' }
    @{ Scene = 'movie_library_settings_view_builder_contract.tscn'; Marker = 'MOVIE LIBRARY SETTINGS VIEW BUILDER CONTRACT PASS: 36 checks' }
    @{ Scene = 'remove_confirmation_presenter_contract.tscn'; Marker = 'REMOVE CONFIRMATION PRESENTER CONTRACT PASS: 24 checks' }
    @{ Scene = 'movie_info_content_presentation_contract.tscn'; Marker = 'MOVIE INFO CONTENT PRESENTATION CONTRACT PASS: 36 checks' }
)

$failed = 0
foreach ($test in $tests) {
    $scenePath = Join-Path (Join-Path $frontend 'tests') $test.Scene
    if (-not (Test-Path -LiteralPath $scenePath -PathType Leaf)) {
        Write-Host "[FAIL] Missing scene: $($test.Scene)" -ForegroundColor Red
        $failed++
        continue
    }
    Write-Host "[RUN ] $($test.Scene)" -ForegroundColor Cyan
    # Native stderr can be surfaced as PowerShell ErrorRecord in Windows PS 5.1.
    # Capture it without treating it as a PowerShell terminating exception.
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $lines = @(& $GodotPath --headless --path $frontend ("res://tests/" + $test.Scene) 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    foreach ($line in $lines) {
        Write-Host ([string]$line)
    }
    $output = ($lines | ForEach-Object { [string]$_ }) -join "`n"
    $markerSeen = $output.Contains($test.Marker)
    $reportedFailure = $output.Contains('[FAIL]') -or $output.Contains('CONTRACT FAIL:')
    if ($exitCode -eq 0 -and $markerSeen -and -not $reportedFailure) {
        Write-Host "[ OK ] $($test.Scene)" -ForegroundColor Green
    }
    else {
        Write-Host "[FAIL] $($test.Scene): exit=$exitCode marker=$markerSeen failure=$reportedFailure" -ForegroundColor Red
        $failed++
    }
}

if ($failed -eq 0) {
    Write-Host 'G3 UI-S6e REGRESSION PASS: 1769/1769 contract checks (50 scenes)' -ForegroundColor Green
    exit 0
}
Write-Host "G3 UI-S6e REGRESSION FAIL: $failed of $($tests.Count) scenes failed" -ForegroundColor Red
exit 1
