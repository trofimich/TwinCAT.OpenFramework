param(
    [string]$Solution = (Join-Path $PSScriptRoot '../../CompiledLibraries/audit/T00/Sources/TwinCAT.OpenFramework.sln'),
    [string]$Report = (Join-Path $PSScriptRoot 't00-xae-baseline.json'),
    [switch]$ExportCurrent
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'xae-diagnostics.ps1')
$result = [ordered]@{ StartedUtc = [DateTime]::UtcNow.ToString('o'); Solution = [IO.Path]::GetFullPath($Solution); Phase = 'CreateDTE'; Checks = @(); Errors = @(); RuntimeExecuted = $false }
$dte = $null
$libraryManager = $null
$repositoryInserted = $false
$repositoryName = 'OpenFrameworkAudit-' + [guid]::NewGuid().ToString('N')
$auditVersion = '1.0.10.65000'
function Save-Report { $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Report -Encoding UTF8 }
Save-Report
try {
    if ($ExportCurrent) {
        $solutionFolder = Split-Path $result.Solution
        foreach ($file in Get-ChildItem $solutionFolder -Recurse -Filter '*.plcproj') {
            $source = [IO.File]::ReadAllText($file.FullName)
            $source = [regex]::Replace($source, '<ProjectVersion>[^<]+</ProjectVersion>', '<ProjectVersion>' + $auditVersion + '</ProjectVersion>')
            [IO.File]::WriteAllText($file.FullName, $source, [Text.UTF8Encoding]::new($false))
        }
    }
    $dte = New-Object -ComObject TcXaeShell.DTE.17.0
    $dte.SuppressUI = $true
    $dte.MainWindow.Visible = $false
    $dte.UserControl = $false
    $settings = $dte.GetObject('TcAutomationSettings')
    $settings.SilentMode = $true
    $result.Phase = 'OpenSolution'; Save-Report
    $dte.Solution.Open($result.Solution)
    $result.ProjectCount = $dte.Solution.Projects.Count
    $systemManager = $dte.Solution.Projects.Item(1).Object
    $exported = @()
    if ($ExportCurrent) {
        $libraryManager = $systemManager.LookupTreeItem('TIPC^TwinCAT_OpenFramework_Tasks^TwinCAT_OpenFramework_Tasks Project^References')
        $repositoryFolder = Join-Path (Split-Path $result.Solution) ('../repository-' + $repositoryName)
        New-Item -ItemType Directory -Path $repositoryFolder -Force | Out-Null
        $libraryManager.InsertRepository($repositoryName, [IO.Path]::GetFullPath($repositoryFolder), 0)
        $repositoryInserted = $true
        $result.Repository = $repositoryName
        $result.AuditVersion = $auditVersion
    }
    foreach ($name in @('TwinCAT_OpenFramework_Core', 'TwinCAT_OpenFramework_Comparision', 'TwinCAT_OpenFramework_Collections', 'TwinCAT_OpenFramework_Tasks')) {
        $result.Phase = 'CheckAllObjects:' + $name; Save-Report
        $project = $systemManager.LookupTreeItem('TIPC^' + $name + '^' + $name + ' Project')
        $references = $systemManager.LookupTreeItem('TIPC^' + $name + '^' + $name + ' Project^References')
        if ($ExportCurrent) {
            foreach ($dependency in $exported) {
                if ($references.References | Where-Object { $_.PlaceholderName -eq $dependency.Placeholder }) {
                    $references.SetEffectiveResolution($dependency.Placeholder, $dependency.Title, $auditVersion, $dependency.Company)
                }
            }
        }
        $checkReturn = $project.CheckAllObjects()
        $diagnostics = @()
        $items = [OpenFrameworkXaeDiagnostics]::Errors($dte).ErrorItems
        for ($index = 1; $index -le $items.Count; $index++) {
            $item = $items.Item($index)
            $diagnostics += [ordered]@{ Description = $item.Description; FileName = $item.FileName; Line = $item.Line; ErrorLevel = [int]$item.ErrorLevel }
        }
        $referenceXml = $references.ProduceXml($false)
        $result.Checks += [ordered]@{ Project = $name; CheckReturn = $checkReturn; Diagnostics = $diagnostics; ReferencesXml = $referenceXml }
        Save-Report
        if ($checkReturn -eq $false -or ($diagnostics | Where-Object { $_.ErrorLevel -eq 2 })) { throw ('Compiler check failed: ' + $name) }
        if ($ExportCurrent) {
            $projectFile = Get-ChildItem (Split-Path $result.Solution) -Recurse -Filter ($name + '.plcproj') | Select-Object -First 1
            $projectXml = [xml][IO.File]::ReadAllText($projectFile.FullName)
            $properties = $projectXml.Project.PropertyGroup
            $libraryFile = Join-Path $repositoryFolder ($name + '.library')
            $project.SaveAsLibrary([IO.Path]::GetFullPath($libraryFile), $false)
            $libraryManager.InstallLibrary($repositoryName, [IO.Path]::GetFullPath($libraryFile), $false)
            $exported += @{ Placeholder = [string]$properties.Placeholder; Title = [string]$properties.Title; Company = [string]$properties.Company; File = [IO.Path]::GetFullPath($libraryFile); SHA256 = (Get-FileHash -LiteralPath $libraryFile -Algorithm SHA256).Hash }
            $result.Exports = $exported
            Save-Report
        }
    }
    $result.Phase = 'ChecksFinished'
} catch {
    $result.Errors += [ordered]@{ Phase = $result.Phase; Message = $_.Exception.Message; HResult = $_.Exception.HResult }
    $result.Phase = 'Blocked'
} finally {
    if ($repositoryInserted) {
        try { $libraryManager.RemoveRepository($repositoryName); $result.RepositoryRemoved = $true }
        catch { $result.RepositoryRemoved = $false; $result.CleanupError = $_.Exception.Message }
    }
    $result.FinishedUtc = [DateTime]::UtcNow.ToString('o'); Save-Report
    if ($null -ne $dte) {
        try { $dte.Solution.Close($false); $dte.Quit() } catch { Write-Warning $_.Exception.Message }
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($dte)
    }
}
[pscustomobject]@{ Phase = $result.Phase; ProjectsChecked = $result.Checks.Count; Exports = @($result.Exports).Count; Errors = $result.Errors; RepositoryRemoved = $result.RepositoryRemoved; Report = $Report } | ConvertTo-Json -Depth 5
if ($result.Phase -eq 'Blocked') { exit 1 }
