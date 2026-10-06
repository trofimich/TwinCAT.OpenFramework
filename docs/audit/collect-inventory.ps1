param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path)

# Read-only inspection of Sources; output is confined to this audit directory.
$ErrorActionPreference = 'Stop'
$sourceRoot = Join-Path $RepositoryRoot 'Sources'
function RelativePath([string]$Path) {
    return $Path.Substring($RepositoryRoot.Length + 1).Replace('\', '/')
}
function NodeText($Xml, [string]$Name) {
    $node = $Xml.SelectSingleNode(".//*[local-name()='$Name']")
    if ($null -ne $node) { return $node.InnerText }
    return $null
}

[xml]$systemProject = Get-Content -LiteralPath (Join-Path $sourceRoot 'TwinCAT.OpenFramework.tsproj') -Raw
$plcEntries = @($systemProject.SelectNodes('//Plc/Project'))
$projects = @()
$items = @()
$missing = @()
foreach ($project in (Get-ChildItem -LiteralPath $sourceRoot -Recurse -Filter '*.plcproj' | Sort-Object FullName)) {
    [xml]$xml = Get-Content -LiteralPath $project.FullName -Raw
    $name = NodeText $xml 'Name'
    $entry = $plcEntries | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    $references = @($xml.SelectNodes('//*[local-name()="PlaceholderReference" or local-name()="LibraryReference" or local-name()="ProjectReference"]') | ForEach-Object {
        [ordered]@{ kind = $_.LocalName; include = $_.GetAttribute('Include'); namespace = NodeText $_ 'Namespace'; defaultResolution = NodeText $_ 'DefaultResolution' }
    })
    $resolutions = @($xml.SelectNodes('//*[local-name()="PlaceholderResolution"]') | ForEach-Object {
        [ordered]@{ include = $_.GetAttribute('Include'); resolution = NodeText $_ 'Resolution' }
    })
    $compileItems = @($xml.SelectNodes('//*[local-name()="Compile"]'))
    foreach ($item in $compileItems) {
        $itemPath = Join-Path $project.DirectoryName $item.GetAttribute('Include')
        $present = Test-Path -LiteralPath $itemPath -PathType Leaf
        $items += [pscustomobject]@{ project = $name; path = RelativePath $itemPath; exists = $present }
        if (-not $present) { $missing += RelativePath $itemPath }
    }
    $projects += [ordered]@{
        path = RelativePath $project.FullName
        name = $name
        title = NodeText $xml 'Title'
        description = NodeText $xml 'Description'
        namespace = NodeText $xml 'DefaultNamespace'
        version = NodeText $xml 'ProjectVersion'
        programVersion = NodeText $xml 'ProgramVersion'
        compileItemCount = $compileItems.Count
        systemProjectIncluded = ($null -ne $entry)
        systemProjectDisabled = ($null -ne $entry -and $entry.GetAttribute('Disabled') -eq 'true')
        amsPort = $(if ($null -ne $entry) { $entry.GetAttribute('AmsPort') } else { $null })
        references = $references
        resolutions = $resolutions
    }
}

$sourceObjects = @()
$parseErrors = @()
$xmlFiles = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File | Where-Object { $_.Extension -in '.TcPOU', '.TcIO', '.TcDUT', '.TcGVL', '.TcTTO', '.TcVIS', '.plcproj', '.tsproj' })
foreach ($file in ($xmlFiles | Sort-Object FullName)) {
    try {
        [xml]$xml = Get-Content -LiteralPath $file.FullName -Raw
        $object = $xml.SelectSingleNode('/TcPlcObject/*[1]')
        $declaration = $xml.SelectSingleNode('/TcPlcObject/*/Declaration')
        $declarationText = $(if ($declaration) { $declaration.InnerText -replace '(?s)\(\*.*?\*\)', '' } else { '' })
        $sourceObjects += [pscustomobject]@{
            path = RelativePath $file.FullName
            kind = $(if ($object) { $object.LocalName } else { $xml.DocumentElement.LocalName })
            name = $(if ($object) { $object.GetAttribute('Name') } else { '' })
            declaration = ($declarationText.Trim() -replace '\r?\n', ' | ')
            methodCount = $xml.SelectNodes('//Method').Count
            propertyCount = $xml.SelectNodes('//Property').Count
        }
    } catch {
        $parseErrors += [ordered]@{ path = RelativePath $file.FullName; error = $_.Exception.Message }
    }
}
$testFiles = @(Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'TwinCAT.OpenFramework.Tests') -Recurse -Filter '*.TcPOU')
$testSuites = @($testFiles | Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match 'EXTENDS\s+TcUnit\.FB_TestSuite' } | ForEach-Object { RelativePath $_.FullName })
$testCallCount = 0
foreach ($file in $testFiles) {
    $testCallCount += [regex]::Matches((Get-Content -LiteralPath $file.FullName -Raw), '(?m)^\s*TEST\(').Count
}
$inventory = [ordered]@{
    schemaVersion = 1
    inspectedOn = '2026-10-02'
    sourceRevision = (& git -C $RepositoryRoot rev-parse HEAD)
    projects = $projects
    staticChecks = [ordered]@{
        xmlFilesChecked = $xmlFiles.Count
        xmlParseErrors = $parseErrors
        compileItemsChecked = $items.Count
        missingCompileItems = $missing
        testSuiteFiles = $testSuites
        syntacticTestCallCount = $testCallCount
        note = 'XML parsing and file existence only; not an ST compilation or runtime test. TEST call count is not executed coverage.'
    }
}
$inventory | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'inventory.json') -Encoding utf8
$sourceObjects | Export-Csv -LiteralPath (Join-Path $PSScriptRoot 'source-catalog.csv') -NoTypeInformation -Encoding utf8
$items | Export-Csv -LiteralPath (Join-Path $PSScriptRoot 'compile-items.csv') -NoTypeInformation -Encoding utf8
[pscustomobject]@{
    Projects = $projects.Count
    XmlFiles = $xmlFiles.Count
    ParseErrors = $parseErrors.Count
    CompileItems = $items.Count
    MissingItems = $missing.Count
    TestSuites = $testSuites.Count
    SyntacticTestCalls = $testCallCount
}
