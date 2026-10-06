$ErrorActionPreference = 'Stop'
$resultFile = Join-Path $PSScriptRoot 't00-runtime-install-result.json'
$statusFile = Join-Path $PSScriptRoot 't00-runtime-install-status.json'
@{ StartedUtc = [DateTime]::UtcNow.ToString('o'); Package = 'TC170x.UsermodeRuntime.XAR=4026.27.0'; Status = 'Installing' } | ConvertTo-Json | Set-Content -LiteralPath $statusFile -Encoding UTF8
try {
    & 'C:/ProgramData/Beckhoff/TcPkg/TcPkg.exe' install TC170x.UsermodeRuntime.XAR=4026.27.0 --as-json | Set-Content -LiteralPath $resultFile -Encoding UTF8
    $installExitCode = $LASTEXITCODE
    @{ FinishedUtc = [DateTime]::UtcNow.ToString('o'); ExitCode = $installExitCode; RuntimeExecuted = $false } | ConvertTo-Json | Set-Content -LiteralPath $statusFile -Encoding UTF8
    exit $installExitCode
} catch {
    @{ FinishedUtc = [DateTime]::UtcNow.ToString('o'); Status = 'Blocked'; Error = $_.Exception.Message; RuntimeExecuted = $false } | ConvertTo-Json | Set-Content -LiteralPath $statusFile -Encoding UTF8
    exit 1
}
