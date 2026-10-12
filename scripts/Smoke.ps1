param([string]$StudioPath)

$ErrorActionPreference = 'Stop'
$taskRepoPath = Split-Path -Parent $PSScriptRoot
$taskPlacePath = Join-Path $taskRepoPath 'build/Guiltless.rbxlx'
$taskScriptPath = Join-Path $PSScriptRoot 'StudioSmoke.luau'

if (-not (Test-Path -LiteralPath $taskPlacePath)) {
    throw 'Build the place with scripts/Build.ps1 first.'
}
if (-not $StudioPath) {
    $taskVersionsPath = Join-Path $env:LOCALAPPDATA 'Roblox/Versions'
    $taskStudioFiles = Get-ChildItem -LiteralPath $taskVersionsPath -Directory | ForEach-Object {
        $taskCandidatePath = Join-Path $_.FullName 'RobloxStudioBeta.exe'
        if (Test-Path -LiteralPath $taskCandidatePath) { Get-Item -LiteralPath $taskCandidatePath }
    }
    $taskStudioFile = $taskStudioFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $taskStudioFile) { throw 'Roblox Studio is not installed. Supply -StudioPath if it is elsewhere.' }
    $StudioPath = $taskStudioFile.FullName
}

# Use a unique output file so an earlier successful run cannot satisfy this run.
$taskLogPath = Join-Path $taskRepoPath ('build/studio-smoke-' + [guid]::NewGuid().ToString('N') + '.log')
$taskArguments = @(
    '--task', 'RunScript',
    '--localPlaceFile', ('"' + $taskPlacePath + '"'),
    '--runScriptFile', ('"' + $taskScriptPath + '"'),
    '--outputFile', ('"' + $taskLogPath + '"'),
    '--quitAfterExecution'
)
$taskProcess = Start-Process -FilePath $StudioPath -ArgumentList $taskArguments -WindowStyle Hidden -PassThru
if (-not $taskProcess.WaitForExit(120000)) {
    Stop-Process -Id $taskProcess.Id -ErrorAction SilentlyContinue
    throw "Studio test timed out. Logs: $taskLogPath"
}
if (-not (Test-Path -LiteralPath $taskLogPath)) {
    throw "Studio did not produce test output. It may have started an automatic update; wait for that to finish, then retry. Exit code: $($taskProcess.ExitCode)"
}
$taskOutput = Get-Content -LiteralPath $taskLogPath -Raw
# Studio echoes the entire driver source. Only an actual standalone result line
# can pass, never the print statement included in that source echo.
$taskMatch = [regex]::Match($taskOutput, '(?m)^GUILTLESS_PHASE0_PASS (\{[^\r\n]+\})\r?$')
if ($taskProcess.ExitCode -ne 0 -or -not $taskMatch.Success) {
    Write-Output $taskOutput
    throw "Studio did not confirm a client/server round trip. Logs: $taskLogPath"
}
$taskResult = $taskMatch.Groups[1].Value | ConvertFrom-Json
if ($taskResult.ok -ne $true -or -not $taskResult.nonce -or -not $taskResult.client) {
    throw "Studio returned an invalid success result. Logs: $taskLogPath"
}
Write-Output $taskMatch.Value
Write-Output "Logs: $taskLogPath"
