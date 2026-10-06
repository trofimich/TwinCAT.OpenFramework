$ErrorActionPreference = 'Stop'
$fixtureFolder = Join-Path $PSScriptRoot '../../Sources/TwinCAT.OpenFramework.TaskLifecycleTests'
New-Item -ItemType Directory -Path $fixtureFolder -Force | Out-Null
function New-Id { '{' + [guid]::NewGuid().ToString() + '}' }
function Member([string]$name, [string]$declaration, [string]$body, [switch]$Property) {
    $id = New-Id
    if ($Property) {
        $getId = New-Id
        return "<Property Name='$name' Id='$id'><Declaration><![CDATA[$declaration]]></Declaration><Get Name='Get' Id='$getId'><Declaration><![CDATA[]]></Declaration><Implementation><ST><![CDATA[$body]]></ST></Implementation></Get></Property>"
    }
    return "<Method Name='$name' Id='$id'><Declaration><![CDATA[$declaration]]></Declaration><Implementation><ST><![CDATA[$body]]></ST></Implementation></Method>"
}
function Write-Pou([string]$name, [string]$declaration, [string]$body, [string[]]$members) {
    $id = New-Id
    $source = "<?xml version='1.0' encoding='utf-8'?><TcPlcObject Version='1.1.0.1'><POU Name='$name' Id='$id' SpecialFunc='None'><Declaration><![CDATA[$declaration]]></Declaration><Implementation><ST><![CDATA[$body]]></ST></Implementation>$($members -join '')</POU></TcPlcObject>"
    [IO.File]::WriteAllText((Join-Path $fixtureFolder ($name + '.TcPOU')), $source, [Text.UTF8Encoding]::new($true))
}
function Object-Members([string]$name) {
    Member 'ClassName' 'PROPERTY ClassName : REFERENCE TO STRING' 'ClassName REF= _ClassName;' -Property
    Member 'NamespaceName' 'PROPERTY NamespaceName : REFERENCE TO STRING' 'NamespaceName REF= _Namespace;' -Property
    Member 'SelfSize' 'PROPERTY SelfSize : ULINT' 'SelfSize := XSIZEOF(THIS^);' -Property
}
$objectVariables = @'
    _ClassName : STRING := __POUNAME();
    _Namespace : STRING := 'OpenFrameworkAudit';
'@
$resourceDeclaration = @"
FUNCTION_BLOCK AuditResourceManager EXTENDS TOF_Core.Object IMPLEMENTS TOF_Core.IResourceManager
VAR
$objectVariables
    Acquired : BOOL;
    AcquireCalls : DINT;
    ReleaseCalls : DINT;
    AcquireDelay : DINT := 1;
    ReleaseDelay : DINT := 1;
END_VAR
"@
$resourceMembers = @(Object-Members 'AuditResourceManager')
$resourceMembers += Member 'AcquireResource' 'METHOD AcquireResource' @'
AcquireCalls := AcquireCalls + 1;
IF AcquireCalls >= AcquireDelay THEN Acquired := TRUE; END_IF
'@
$resourceMembers += Member 'ReleaseResource' 'METHOD ReleaseResource' @'
ReleaseCalls := ReleaseCalls + 1;
IF ReleaseCalls >= ReleaseDelay THEN Acquired := FALSE; END_IF
'@
$resourceMembers += Member 'ResourceAcquired' 'PROPERTY ResourceAcquired : BOOL' 'ResourceAcquired := Acquired;' -Property
$resourceMembers += Member 'GetResource' 'METHOD GetResource : TOF_Core.IObject' 'GetResource := THIS^;'
Write-Pou 'AuditResourceManager' $resourceDeclaration '' $resourceMembers
$taskDeclaration = @"
FUNCTION_BLOCK AuditTask EXTENDS TOF_Tasks.Task
VAR
$objectVariables
    Manager : AuditResourceManager;
    UseManager : BOOL;
    RunningCalls : DINT;
    WorkTicks : DINT;
    CancelRequests : DINT;
    BeforeStopCalls : DINT;
    AfterStopCalls : DINT;
END_VAR
"@
$taskMembers = @(Object-Members 'AuditTask')
$taskMembers += Member 'ResourceManager' 'PROPERTY ResourceManager : TOF_Core.IResourceManager' @'
ResourceManager := 0;
IF UseManager THEN ResourceManager := Manager; END_IF
'@ -Property
$taskMembers += Member 'OnRunning' @'
METHOD PROTECTED OnRunning
VAR_OUTPUT
    processingState : TOF_Tasks.TASK_PROCESSING_STATE;
END_VAR
VAR_IN_OUT
    stopReasonMessage : TOF_Core.ERROR_MESSAGE;
END_VAR
'@ @'
RunningCalls := RunningCalls + 1;
processingState := TOF_Tasks.TASK_PROCESSING_STATE.BUSY;
IF WorkTicks > 0 AND_THEN RunningCalls >= WorkTicks THEN
    processingState := TOF_Tasks.TASK_PROCESSING_STATE.DONE;
END_IF
'@
$taskMembers += Member 'OnCancelRequested' 'METHOD PROTECTED OnCancelRequested' 'CancelRequests := CancelRequests + 1;'
$taskMembers += Member 'OnBeforeStop' 'METHOD PROTECTED OnBeforeStop' 'BeforeStopCalls := BeforeStopCalls + 1;'
$taskMembers += Member 'OnAfterStop' 'METHOD PROTECTED OnAfterStop' 'AfterStopCalls := AfterStopCalls + 1;'
Write-Pou 'AuditTask' $taskDeclaration '' $taskMembers
$queueDeclaration = @"
FUNCTION_BLOCK AuditQueue EXTENDS TOF_Tasks.TaskQueue
VAR
$objectVariables
    Manager : AuditResourceManager;
    UseManager : BOOL;
END_VAR
"@
$queueMembers = @(Object-Members 'AuditQueue')
$queueMembers += Member 'ResourceManager' 'PROPERTY ResourceManager : TOF_Core.IResourceManager' @'
ResourceManager := 0;
IF UseManager THEN ResourceManager := Manager; END_IF
'@ -Property
$queueMembers += Member 'Enqueue' @'
METHOD Enqueue
VAR_INPUT
    task : TOF_Tasks.ITask;
END_VAR
'@ 'EnqueueTask(task);'
Write-Pou 'AuditQueue' $queueDeclaration '' $queueMembers
$mainDeclaration = @'
PROGRAM MAIN
VAR
    Finished : BOOL;
    Checks : DINT;
    Failures : DINT;
    FirstFailure : STRING(255);
    Children : ARRAY [0..7] OF AuditTask;
    Parents : ARRAY [0..6] OF AuditQueue;
    InnerQueue : AuditQueue;
    step : DINT;
END_VAR
'@
$mainBody = @'
IF Finished THEN RETURN; END_IF

(* Cancel before the first Execute must not start queued work. *)
Parents[0].Enqueue(Children[0]);
Check(Parents[0].Start(), 'early start refused');
Check(Parents[0].Cancel(), 'early cancel refused');
Parents[0].Execute();
Check(Parents[0].State.Stopped AND_THEN Children[0].State.Ready, 'early cancel started child');
Check(Children[0].RunningCalls = 0, 'processing after stop');

(* An indefinite resource-owning child must receive cancel and finish release. *)
Children[1].UseManager := TRUE;
Children[1].Manager.ReleaseDelay := 4;
Parents[1].Enqueue(Children[1]);
Parents[1].Start();
FOR step := 1 TO 4 DO Parents[1].Execute(); END_FOR
Check(Children[1].Manager.Acquired, 'child resource not acquired');
Check(Parents[1].Cancel(), 'cancel running parent refused');
Check(NOT Parents[1].Cancel(), 'duplicate cancel accepted');
FOR step := 1 TO 16 DO Parents[1].Execute(); END_FOR
Check(Parents[1].State.Stopped AND_THEN Children[1].State.Stopped, 'delayed child did not stop');
Check(NOT Children[1].Manager.Acquired, 'child resource retained');
Check(Children[1].CancelRequests = 1, 'cancel callback repeated');
Check(Children[1].BeforeStopCalls = 1 AND_THEN Children[1].AfterStopCalls = 1, 'stop callback repeated');
Check(Parents[1].FinalStopReason.ExternalCancel, 'parent cancel result lost');

(* Parent release must start after child cleanup, pending work stays READY. *)
Children[2].UseManager := TRUE;
Children[2].Manager.ReleaseDelay := 4;
Parents[2].UseManager := TRUE;
Parents[2].Manager.ReleaseDelay := 2;
Parents[2].Enqueue(Children[2]);
Parents[2].Enqueue(Children[7]);
Parents[2].Start();
FOR step := 1 TO 5 DO Parents[2].Execute(); END_FOR
Parents[2].Cancel();
FOR step := 1 TO 16 DO
    Parents[2].Execute();
    IF Children[2].State.Running THEN
        Check(Parents[2].Manager.ReleaseCalls = 0, 'parent released before child');
    END_IF
END_FOR
Check(Parents[2].State.Stopped AND_THEN NOT Parents[2].Manager.Acquired, 'parent cleanup incomplete');
Check(Children[7].State.Ready, 'next child started during cancel');

(* Resource-free indefinite child. *)
Parents[3].Enqueue(Children[3]);
Parents[3].Start();
Parents[3].Execute();
Parents[3].Cancel();
FOR step := 1 TO 4 DO Parents[3].Execute(); END_FOR
Check(Parents[3].State.Stopped AND_THEN Children[3].State.Stopped, 'resource-free child cancellation');

(* Two levels of composition. *)
Children[4].UseManager := TRUE;
Children[4].Manager.ReleaseDelay := 3;
InnerQueue.UseManager := TRUE;
InnerQueue.Manager.ReleaseDelay := 2;
InnerQueue.Enqueue(Children[4]);
Parents[4].Enqueue(InnerQueue);
Parents[4].Start();
FOR step := 1 TO 8 DO Parents[4].Execute(); END_FOR
Parents[4].Cancel();
FOR step := 1 TO 20 DO Parents[4].Execute(); END_FOR
Check(Parents[4].State.Stopped AND_THEN InnerQueue.State.Stopped AND_THEN Children[4].State.Stopped, 'nested cancellation');
Check(NOT InnerQueue.Manager.Acquired AND_THEN NOT Children[4].Manager.Acquired, 'nested resources retained');

(* Normal finite work still completes successfully. *)
Children[5].WorkTicks := 3;
Parents[5].StopWhenNoPendingTasks := TRUE;
Parents[5].Enqueue(Children[5]);
Parents[5].Start();
FOR step := 1 TO 12 DO Parents[5].Execute(); END_FOR
Check(Parents[5].State.Stopped AND_THEN Parents[5].FinalStopReason.WorkDone, 'normal completion changed');
Check(Children[5].RunningCalls = 3, 'finite task extra processing');

(* Cancel during child acquire: fake manager supports neutralizing pending acquire. *)
Children[6].UseManager := TRUE;
Children[6].Manager.AcquireDelay := 5;
Parents[6].Enqueue(Children[6]);
Parents[6].Start();
Parents[6].Execute();
Parents[6].Execute();
Parents[6].Cancel();
FOR step := 1 TO 8 DO Parents[6].Execute(); END_FOR
Check(Parents[6].State.Stopped AND_THEN Children[6].State.Stopped, 'cancel during acquire');
Check(Children[6].RunningCalls = 0, 'processing after acquiring cancel');
Finished := TRUE;
TOF_Core.ExceptionManager.Cleanup();
TOF_Core.DynamicMemoryManager.CleanupMemory();
'@
$checkMethod = Member 'Check' @'
METHOD PRIVATE Check
VAR_INPUT
    condition : BOOL;
    message : STRING(255);
END_VAR
'@ @'
Checks := Checks + 1;
IF NOT condition THEN
    Failures := Failures + 1;
    IF FirstFailure = '' THEN FirstFailure := message; END_IF
END_IF
'@
Write-Pou 'MAIN' $mainDeclaration $mainBody @($checkMethod)
$projectId = New-Id
$applicationId = New-Id
$typeSystemId = New-Id
$taskId = New-Id
$projectText = @"
<?xml version='1.0' encoding='utf-8'?>
<Project DefaultTargets='Build' xmlns='http://schemas.microsoft.com/developer/msbuild/2003'>
  <PropertyGroup>
    <FileVersion>1.0.0.0</FileVersion><SchemaVersion>2.0</SchemaVersion>
    <ProjectGuid>$projectId</ProjectGuid><Name>TaskLifecycleTests</Name>
    <ProgramVersion>3.1.4026.27</ProgramVersion><Application>$applicationId</Application><TypeSystem>$typeSystemId</TypeSystem>
    <DefaultNamespace>TaskLifecycleTests</DefaultNamespace><DownloadApplicationInfo>true</DownloadApplicationInfo><GenerateTpy>false</GenerateTpy>
  </PropertyGroup>
  <ItemGroup>
    <Compile Include='AuditResourceManager.TcPOU'><SubType>Code</SubType></Compile>
    <Compile Include='AuditTask.TcPOU'><SubType>Code</SubType></Compile>
    <Compile Include='AuditQueue.TcPOU'><SubType>Code</SubType></Compile>
    <Compile Include='MAIN.TcPOU'><SubType>Code</SubType></Compile>
    <Compile Include='AuditTaskCycle.TcTTO'><SubType>Code</SubType></Compile>
    <PlaceholderReference Include='TwinCAT_OpenFramework_Core'><DefaultResolution>TwinCAT Open Framework Core, 1.0.10.65000 (Oleksandr Tiutyk FOP)</DefaultResolution><Namespace>TOF_Core</Namespace></PlaceholderReference>
    <PlaceholderReference Include='TwinCAT_OpenFramework_Tasks'><DefaultResolution>TwinCAT Open Framework Tasks, 1.0.10.65000 (Oleksandr Tiutyk FOP)</DefaultResolution><Namespace>TOF_Tasks</Namespace></PlaceholderReference>
    <PlaceholderReference Include='Tc2_Standard'><DefaultResolution>Tc2_Standard, * (Beckhoff Automation GmbH)</DefaultResolution><Namespace>Tc2_Standard</Namespace></PlaceholderReference>
    <PlaceholderReference Include='Tc2_System'><DefaultResolution>Tc2_System, * (Beckhoff Automation GmbH)</DefaultResolution><Namespace>Tc2_System</Namespace></PlaceholderReference>
  </ItemGroup>
</Project>
"@
[IO.File]::WriteAllText((Join-Path $fixtureFolder 'TaskLifecycleTests.plcproj'), $projectText, [Text.UTF8Encoding]::new($false))
$taskText = "<?xml version='1.0' encoding='utf-8'?><TcPlcObject Version='1.1.0.1'><Task Name='AuditTaskCycle' Id='$taskId'><CycleTime>10000</CycleTime><Priority>20</Priority><PouCall><Name>MAIN</Name></PouCall></Task></TcPlcObject>"
[IO.File]::WriteAllText((Join-Path $fixtureFolder 'AuditTaskCycle.TcTTO'), $taskText, [Text.UTF8Encoding]::new($true))
Write-Output 'Created standalone native ST fixtures: seven lifecycle scenarios. No runtime execution performed.'
