param(
    [Parameter(Mandatory=$true)][string]$Solution,
    [Parameter(Mandatory=$true)][string]$Report
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'xae-diagnostics.ps1')
$result = [ordered]@{ Solution=$Solution; Phase='CreateDTE'; Checks=@(); Errors=@(); RuntimeExecuted=$false; TargetActivated=$false }
$dte = $null
function Save-Report { $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Report -Encoding UTF8 }
Save-Report
try {
    $dte = New-Object -ComObject TcXaeShell.DTE.17.0
    $dte.SuppressUI = $true
    $dte.MainWindow.Visible = $false
    $dte.UserControl = $false
    $dte.GetObject('TcAutomationSettings').SilentMode = $true
    $result.Phase='OpenSolution'; Save-Report
    $dte.Solution.Open($Solution)
    $manager = $dte.Solution.Projects.Item(1).Object
    foreach ($name in @('TwinCAT_OpenFramework_Core','TwinCAT_OpenFramework_Automation','TwinCAT_OpenFramework_Tests')) {
        $result.Phase='CheckAllObjects:' + $name; Save-Report
        $project = $manager.LookupTreeItem('TIPC^' + $name + '^' + $name + ' Project')
        $references = $manager.LookupTreeItem('TIPC^' + $name + '^' + $name + ' Project^References')
        $checkReturn = $project.CheckAllObjects()
        $diagnostics = @()
        $items = [OpenFrameworkXaeDiagnostics]::Errors($dte).ErrorItems
        for ($index=1; $index -le $items.Count; $index++) {
            $item=$items.Item($index)
            $diagnostics += [ordered]@{Description=$item.Description; FileName=$item.FileName; Line=$item.Line; ErrorLevel=[int]$item.ErrorLevel}
        }
        $panes = @()
        foreach ($pane in [OpenFrameworkXaeDiagnostics]::Output($dte).OutputWindowPanes) {
            $selection=$pane.TextDocument.StartPoint.CreateEditPoint()
            $panes += [ordered]@{Name=$pane.Name; Text=$selection.GetText($pane.TextDocument.EndPoint)}
        }
        $result.Checks += [ordered]@{Project=$name; CheckReturn=$checkReturn; Diagnostics=$diagnostics; Output=$panes; ReferencesXml=$references.ProduceXml($false)}
        Save-Report
    }
    $result.Phase='ChecksReturned'
} catch {
    $result.Errors += [ordered]@{Phase=$result.Phase; Message=$_.Exception.Message; HResult=$_.Exception.HResult}
    $result.Phase='Blocked'
} finally {
    if ($null -ne $dte) {
        try { $dte.Solution.Close($false); $dte.Quit() } catch { $result.Errors += $_.Exception.Message }
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($dte)
    }
    Save-Report
}
[pscustomobject]$result | Select-Object Phase,Errors,RuntimeExecuted,TargetActivated | ConvertTo-Json -Depth 5
if ($result.Phase -eq 'Blocked') { exit 1 }
