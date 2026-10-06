param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)
$ErrorActionPreference = 'Stop'
$projectDirectory = Join-Path $RepositoryRoot 'Sources/TwinCAT.OpenFramework.Tests'
$project = [xml](Get-Content -LiteralPath (Join-Path $projectDirectory 'TwinCAT_OpenFramework_Tests.plcproj') -Raw)
$includes = @($project.SelectNodes("//*[local-name()='Compile']") | ForEach-Object { $_.Include })
$ids = @{}
$files = @(Get-ChildItem -LiteralPath $projectDirectory -Recurse -File | Where-Object { $_.Extension -in '.TcPOU', '.TcIO', '.TcDUT', '.TcGVL' })
foreach ($file in $files) {
    $document = [xml](Get-Content -LiteralPath $file.FullName -Raw)
    foreach ($node in $document.SelectNodes('//*[@Id]')) {
        $id = $node.Id.ToLowerInvariant()
        if ($ids.ContainsKey($id)) { throw "Duplicate object ID $id in $($file.FullName) and $($ids[$id])" }
        $ids[$id] = $file.FullName
    }
    $relative = $file.FullName.Substring($projectDirectory.Length + 1)
    if ($relative -notin $includes) { throw "Missing Compile registration: $relative" }
}
foreach ($include in $includes) {
    if (-not (Test-Path -LiteralPath (Join-Path $projectDirectory $include))) { throw "Missing Compile source: $include" }
}
if (@($includes | Group-Object | Where-Object Count -gt 1).Count) { throw 'Duplicate Compile entries' }
$controller = [xml](Get-Content -LiteralPath (Join-Path $projectDirectory 'TestAutomationController.TcPOU') -Raw)
$suiteNames = 'TaskLifecycleTest', 'TaskQueueLifecycleTest', 'TimerLifecycleTest', 'FileTaskBindingTest', 'FileTaskIntegrationTest'
$total = 0
foreach ($suiteName in $suiteNames) {
    $suite = [xml](Get-Content -LiteralPath (Join-Path $projectDirectory "Tests/TaskLifecycle/$suiteName.TcPOU") -Raw)
    $body = $suite.TcPlcObject.POU.Implementation.ST.InnerText
    $methods = @($suite.TcPlcObject.POU.Method)
    foreach ($method in $methods) {
        if ($body -notmatch ('\b' + [regex]::Escape($method.Name) + '\s*\(\s*\)')) { throw "Uncalled test method: $suiteName.$($method.Name)" }
        if ($method.Implementation.ST.InnerText -notmatch 'TEST_FINISHED\s*\(') { throw "Missing test completion: $suiteName.$($method.Name)" }
    }
    if ($controller.TcPlcObject.POU.Declaration.InnerText -notmatch (':\s*' + $suiteName + '\s*;')) { throw "Missing controller instance: $suiteName" }
    $total += $methods.Count
    Write-Output "$suiteName : $($methods.Count) test methods"
}
$timerPlaceholder = $project.SelectSingleNode("//*[local-name()='PlaceholderReference' and @Include='TwinCAT_OpenFramework_Timers']")
if ($null -eq $timerPlaceholder) { throw 'Missing Timers placeholder' }
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectDirectory 'Tests/TaskLifecycle') -File) {
    $document = [xml](Get-Content -LiteralPath $file.FullName -Raw)
    foreach ($declaration in $document.SelectNodes('//Declaration')) {
        if ($declaration.InnerText -match '(?m)^\s*[A-Za-z]\s*:') { throw "Single-letter variable in $($file.Name)" }
    }
    foreach ($implementation in $document.SelectNodes('//ST')) {
        $code = [regex]::Replace($implementation.InnerText, "'([^']|'')*'|`"([^`"]|`"`")*`"|//[^\r\n]*|\(\*[\s\S]*?\*\)", '')
        foreach ($line in ($code -split '\r?\n')) {
            if (($line.ToCharArray() | Where-Object { $_ -eq ';' }).Count -gt 1) { throw "Multiple statements on one line in $($file.Name)" }
            if ($line -match '\bTHEN\s+\S|\bDO\s+\S') { throw "Inline control block in $($file.Name)" }
        }
    }
}
Write-Output "Static checks passed: $($files.Count) XML source files, $($ids.Count) unique IDs, $total new test methods."
Write-Output 'New test style checks passed: descriptive variable names and separate statements/control blocks.'
Write-Output 'This checks source structure and registration only. ST compilation and PLC/TcUnit execution are NOT performed.'
