param([string]$Report = (Join-Path $PSScriptRoot 'itask-static-validation.json'))
$ErrorActionPreference = 'Stop'
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$sources = Join-Path $workspace 'Sources'
$errors = @()
$ids = @{}
$xmlCount = 0
$compileCount = 0
$projects = @(Get-ChildItem -LiteralPath $sources -Recurse -Filter '*.plcproj')
foreach ($file in Get-ChildItem -LiteralPath $sources -Recurse -File) {
    if ($file.Extension -notin @('.TcPOU','.TcIO','.TcDUT','.TcGVL','.TcTTO','.TcVIS','.plcproj','.tsproj')) { continue }
    try {
        $document = New-Object Xml.XmlDocument
        $document.Load($file.FullName)
        $xmlCount++
        if ($file.FullName -match 'TaskLifecycle|OpenFramework.Tasks\\|IResourceCleanupStatus') {
            foreach ($node in $document.SelectNodes('//*[@Id]')) {
                $id = $node.GetAttribute('Id').ToLowerInvariant()
                if ($ids.ContainsKey($id)) { $errors += "Duplicate object ID: $id in $($file.FullName) and $($ids[$id])" }
                $ids[$id] = $file.FullName
            }
        }
        if ($file.Extension -eq '.plcproj') {
            foreach ($node in $document.SelectNodes('//*[local-name()="Compile"]')) {
                $compileCount++
                $path = Join-Path $file.DirectoryName $node.GetAttribute('Include')
                if (-not (Test-Path -LiteralPath $path)) { $errors += "Missing Compile: $path" }
            }
        }
    } catch { $errors += "$($file.FullName): $($_.Exception.Message)" }
}
$suitePath = Join-Path $sources 'TwinCAT.OpenFramework.Tests/Tests/TaskLifecycle/TaskLifecycleTest.TcPOU'
$suite = [xml](Get-Content -LiteralPath $suitePath -Raw)
$tests = @($suite.SelectNodes('//Method') | Where-Object { $_.Name -like 'Test*' })
$body = $suite.TcPlcObject.POU.Implementation.ST.InnerText
foreach ($test in $tests) {
    if (-not $body.Contains($test.Name + '();')) { $errors += "Test method not scheduled: $($test.Name)" }
    if (-not $test.Implementation.ST.InnerText.Contains('TEST_FINISHED();')) { $errors += "No test finish path: $($test.Name)" }
}
$controller = [xml](Get-Content (Join-Path $sources 'TwinCAT.OpenFramework.Tests/TestAutomationController.TcPOU') -Raw)
if (-not $controller.TcPlcObject.POU.Declaration.InnerText.Contains('_TaskLifecycleTest : TaskLifecycleTest;')) { $errors += 'Suite is not instantiated by TestAutomationController' }
$result = [ordered]@{
    CheckedUtc = [DateTime]::UtcNow.ToString('o')
    Scope = 'XML parsing, Compile files, IDs in Tasks and new fixtures, suite registration'
    PlcProjects = $projects.Count
    ParsedXmlFiles = $xmlCount
    CompileEntries = $compileCount
    LifecycleTestMethods = $tests.Count
    Errors = $errors
    STCompilationExecuted = $false
    RuntimeTestsExecuted = $false
}
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Report -Encoding UTF8
$result | ConvertTo-Json -Depth 5
if ($errors.Count) { exit 1 }
