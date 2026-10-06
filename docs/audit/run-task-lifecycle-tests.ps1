param(
    [string]$LibraryReport = (Join-Path $PSScriptRoot 't00-xae-current-libraries.json'),
    [string]$Report = (Join-Path $PSScriptRoot 't00-lifecycle-runtime.json'),
    [switch]$CompileOnly
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'xae-diagnostics.ps1')
$auditNetId = '199.42.42.250.1.1'
$runId = [guid]::NewGuid().ToString('N')
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$runFolder = Join-Path $workspace ('CompiledLibraries/audit/runs/' + $runId)
New-Item -ItemType Directory -Path $runFolder -Force | Out-Null
$result = [ordered]@{ StartedUtc = [DateTime]::UtcNow.ToString('o'); RunFolder = $runFolder; Phase = 'CreateDTE'; RuntimeExecuted = $false; TargetNetId = $auditNetId; Errors = @() }
$dte = $null
$libraryManager = $null
$repositoryInserted = $false
$client = $null
$repositoryName = 'OpenFrameworkTests-' + $runId
function Save-Report { $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Report -Encoding UTF8 }
function Read-Diagnostics {
    $messages = @()
    $items = [OpenFrameworkXaeDiagnostics]::Errors($dte).ErrorItems
    for ($index = 1; $index -le $items.Count; $index++) {
        $item = $items.Item($index)
        $messages += @{ Description = $item.Description; FileName = $item.FileName; Line = $item.Line; ErrorLevel = [int]$item.ErrorLevel }
    }
    return $messages
}
function Read-Output {
    $panes = @()
    foreach ($pane in [OpenFrameworkXaeDiagnostics]::Output($dte).OutputWindowPanes) {
        try {
            $document = $pane.TextDocument
            $point = $document.StartPoint.CreateEditPoint()
            $panes += @{ Name = $pane.Name; Text = $point.GetText($document.EndPoint) }
        } catch { $panes += @{ Name = $pane.Name; Error = $_.Exception.Message } }
    }
    return $panes
}
Save-Report
try {
    $dte = New-Object -ComObject TcXaeShell.DTE.17.0
    $dte.SuppressUI = $true; $dte.MainWindow.Visible = $false; $dte.UserControl = $false
    $settings = $dte.GetObject('TcAutomationSettings'); $settings.SilentMode = $true
    $dte.ExecuteCommand('View.ErrorList', '')
    $dte.ExecuteCommand('View.Output', '')
    $dte.Solution.Create($runFolder, 'TaskLifecycleAudit')
    $template = 'C:/Program Files (x86)/Beckhoff/TwinCAT/3.1/Components/Base/PrjTemplate/TwinCAT Project.tsproj'
    $null = $dte.Solution.AddFromTemplate($template, (Join-Path $runFolder 'System'), 'TaskLifecycleAudit', $false)
    $systemManager = $dte.Solution.Projects.Item(1).Object
    $systemManager.SetTargetNetId($auditNetId)
    if ($systemManager.GetTargetNetId() -ne $auditNetId) { throw 'Refusing to use a target other than isolated Usermode Runtime.' }
    if ($systemManager.LookupTreeItem('TIID').ChildCount -ne 0) { throw 'Refusing to deploy a configuration containing IO devices.' }
    $result.Phase = 'ImportFixtures'; Save-Report
    $plc = $systemManager.LookupTreeItem('TIPC')
    $fixtureProject = Join-Path $workspace 'Sources/TwinCAT.OpenFramework.TaskLifecycleTests/TaskLifecycleTests.plcproj'
    $projectRoot = $plc.CreateChild('TaskLifecycleTests', 0, '', $fixtureProject)
    $project = $systemManager.LookupTreeItem('TIPC^TaskLifecycleTests^TaskLifecycleTests Project')
    $libraryManager = $systemManager.LookupTreeItem('TIPC^TaskLifecycleTests^TaskLifecycleTests Project^References')
    $repositoryFolder = Join-Path $runFolder 'Repository'
    New-Item -ItemType Directory -Path $repositoryFolder -Force | Out-Null
    $libraryManager.InsertRepository($repositoryName, $repositoryFolder, 0)
    $repositoryInserted = $true
    $libraries = Get-Content -LiteralPath $LibraryReport -Raw | ConvertFrom-Json
    foreach ($library in $libraries.Exports) { $libraryManager.InstallLibrary($repositoryName, $library.File, $false) }
    foreach ($library in $libraries.Exports) {
        if ($library.Placeholder -in @('TwinCAT_OpenFramework_Core', 'TwinCAT_OpenFramework_Tasks')) {
            $libraryManager.SetEffectiveResolution($library.Placeholder, $library.Title, $libraries.AuditVersion, $library.Company)
        }
    }
    $result.Phase = 'CheckAllObjects'; Save-Report
    $result.CheckReturn = $project.CheckAllObjects()
    $result.SubsystemErrors = $systemManager.GetLastErrorMessages()
    Start-Sleep -Milliseconds 500
    $result.Diagnostics = @(Read-Diagnostics)
    $result.Output = @(Read-Output)
    Save-Report
    $result.Phase = 'Build'; Save-Report
    $dte.Solution.SolutionBuild.Build($true)
    $result.LastBuildInfo = $dte.Solution.SolutionBuild.LastBuildInfo
    Start-Sleep -Milliseconds 500
    $result.Diagnostics = @(Read-Diagnostics)
    $result.Output = @(Read-Output)
    if ($result.LastBuildInfo -ne 0 -or ($result.Diagnostics | Where-Object { $_.ErrorLevel -eq 2 })) { throw 'Native build failed.' }
    if ($CompileOnly) {
        $result.Phase = 'CompiledOnly'
    } else {
        $result.Phase = 'ActivateIsolatedConfiguration'; Save-Report
        $projectRoot.BootProjectAutostart = $true
        $projectRoot.GenerateBootProject($true)
        if ($systemManager.GetTargetNetId() -ne $auditNetId) { throw 'Target changed before activation.' }
        $systemManager.ActivateConfiguration()
        $systemManager.StartRestartTwinCAT()
        $result.Phase = 'ReadResults'; Save-Report
        Add-Type -Path 'C:/Program Files (x86)/Beckhoff/TwinCAT/3.1/Components/Plc/LacBinaries/GAC_MSIL/TwinCAT.Ads/4.3.28.0__180016cd49e5e8c3/TwinCAT.Ads.dll'
        $client = New-Object TwinCAT.Ads.TcAdsClient
        $client.Connect($auditNetId, 851)
        $deadline = [DateTime]::UtcNow.AddSeconds(30)
        $finished = $false
        while ([DateTime]::UtcNow -lt $deadline) {
            try {
                $finishedHandle = $client.CreateVariableHandle('MAIN.Finished')
                try { $finished = $client.ReadAny($finishedHandle, [bool]) } finally { $client.DeleteVariableHandle($finishedHandle) }
                if ($finished) { break }
            } catch { $result.LastReadError = $_.Exception.Message }
            Start-Sleep -Milliseconds 250
        }
        if (-not $finished) { throw 'Native fixture run did not report Finished within 30 seconds.' }
        $result.RuntimeExecuted = $true
        foreach ($symbol in @('Checks', 'Failures')) {
            $handle = $client.CreateVariableHandle('MAIN.' + $symbol)
            try { $result[$symbol] = $client.ReadAny($handle, [int]) } finally { $client.DeleteVariableHandle($handle) }
        }
        $handle = $client.CreateVariableHandle('MAIN.FirstFailure')
        try { $result.FirstFailure = $client.ReadAny($handle, [string], [int[]]@(255)) } finally { $client.DeleteVariableHandle($handle) }
        if ($result.Failures -ne 0) { throw 'Native lifecycle assertions failed.' }
        $result.Phase = 'Passed'
    }
} catch {
    $result.Errors += @{ Phase = $result.Phase; Message = $_.Exception.Message; HResult = $_.Exception.HResult }
    $result.Phase = 'BlockedOrFailed'
} finally {
    if ($client) { $client.Dispose() }
    if ($repositoryInserted) {
        try { $libraryManager.RemoveRepository($repositoryName); $result.RepositoryRemoved = $true }
        catch { $result.RepositoryRemoved = $false; $result.CleanupError = $_.Exception.Message }
    }
    $result.FinishedUtc = [DateTime]::UtcNow.ToString('o'); Save-Report
    if ($dte) {
        try { $dte.Solution.Close($false); $dte.Quit() } catch { Write-Warning $_.Exception.Message }
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($dte)
    }
}
[pscustomobject]@{ Phase = $result.Phase; Checks = $result.Checks; Failures = $result.Failures; RuntimeExecuted = $result.RuntimeExecuted; Errors = $result.Errors; Report = $Report } | ConvertTo-Json -Depth 5
if ($result.Phase -eq 'BlockedOrFailed') { exit 1 }
