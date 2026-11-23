# TwinCAT.OpenFramework HowTo

## Run the first example

The supplied 10 ms PlcTask calls MAIN, which calls SingleCycleTestExample.Execute() once per scan.
Start with [AdditionTest.ExecuteTest](Testing/AdditionTest.TcPOU). It checks that adding 2 and 3 gives 5.
When the PLC runs, open the SingleCycleTestExample program instance in Watch. After
`_Runner.IsFinished` becomes TRUE, expect `_Runner.PassedTests = 1`, `_Runner.AllPassed = TRUE`
and `_Report.IsReady = TRUE`. The reporter builds JUnit XML in memory.

To try a different row below, replace MAIN in the HowTo task's POU list with the selected program.
Use one program per example task. Running MAIN and SingleCycleTestExample at the same time would drive
the same instance twice. For examples with a request bit, write the inputs first, then **write TRUE once**
to the request bit in Watch. The program clears the bit itself. Avoid forcing it.

## Learn a framework API

| Program | Try this in Watch | Expected observation |
| --- | --- | --- |
| [BuildDiagnosticMessageExample](Strings/BuildDiagnosticMessageExample.TcPOU) | Change `_StationName`, `_StationNumber` or `_StatusText`. | Both outputs start as `Station 3: Waiting for part`. With long input `_MessageWithEllipsis` ends in `...`. |
| [ScaleAnalogInputExample](IO/ScaleAnalogInputExample.TcPOU) | Set `_RawInput` to 5000, 20000, 22000 and -1000 in turn. No I/O links are needed. | `_TemperatureCelsius` reads 25, 100, 100 and 0, respectively. |
| [BorrowedListExample](Collections/BorrowedListExample.TcPOU) | Change `_SourceValue` from 42 to 7. | `_Value` becomes 7 on the next scan. The list still contains the same entry, which refers to the program variable. |
| [ExceptionSnapshotExample](Exceptions/ExceptionSnapshotExample.TcPOU) | Set `_RunRequested`. | `_Error.TopMessage` contains “Example operation failed” and remains available after the scan that caught the exception. |
| [JsonConfigurationExample](JSON/JsonConfigurationExample.TcPOU) | Set `_InputValue` to 7 and set `_RunRequested`. | On `_Succeeded`, the JSON in `_Document` has a numeric field named `value` equal to 7, and `_OutputValue` is 7. On failure inspect `_Error.TopMessage`. |
| [CyclicTimerTaskExample](Tasks/CyclicTimerTaskExample.TcPOU) | Set `_StartRequested` and wait for `_Completed`. Repeat with `_Interval = T#30S` and set `_CancelRequested` while running. | On expiry `_WorkDone` is TRUE. After cancellation `_Completed` is TRUE, `_WorkDone` is FALSE and `_StopMessage` explains why. |
| [SequentialTaskQueueExample](Tasks/SequentialTaskQueueExample.TcPOU) | Set `_StartRequested`. Watch `_FirstTimer.State.Value`, `_SecondTimer.State.Value` and `_Queue.PendingTaskCount`. Repeat after `_Completed`. | The first timer runs for 3 s while the second stays `READY`. The second then runs for 6 s. The pending count drops from 2 to 1 to 0. When `_Completed` is TRUE, expect `_WorkDone = TRUE`. |
| [CheckDirectoryExample](FileSystem/CheckDirectoryExample.TcPOU) | Set `_DirectoryPath` to an existing directory on the PLC target and set `_CheckRequested`. Then repeat with the path of an existing regular file. | When both `_Completed` and `_Succeeded` are TRUE, `_DirectoryExists` is TRUE for the directory and FALSE for the file. If the check fails, read `_StopMessage`. |
| [TextFileExample](FileSystem/TextFileExample.TcPOU) | In an existing writable directory on the PLC target, choose a disposable `_FilePath`. Writing truncates an existing file. Set `_WriteMode` TRUE, leave the default text and set `_RunRequested`. After success, set `_WriteMode` FALSE and request again. | Wait for `_Completed` and check `_Succeeded` each time. After the read, `_ReadText` contains `OpenFramework example`. A read fetches one bounded string and may stop at a line feed. On failure read `_StopMessage`. |

For the message example, paste the following ASCII text into `_StatusText` with the default station name
and number. The combined message exceeds 255 bytes. Compare the end of `_Message` and `_MessageWithEllipsis`.

```text
1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890
```

The analog example uses a simulated 16-bit value. Its endpoints define the example calibration and can be
changed in the converter declaration. The input and both endpoints use the same raw representation, INT16.

The queue example resets both timer instances before enqueueing them in order. The program advances only
the queue. If the batch fails, inspect `_StopMessage` after `_Completed` becomes TRUE.

The timer and file examples start a new operation only while idle. Each calls Execute on the running
task once per scan until it stops. In TextFileExample the manager drives its child and closes the file.
For online change and independent verification of closure see [FileSystem online change](../../Guides/FileSystemOnlineChange.md).

## Write and organize tests

| Program | Where to read the test | Expected result after `_Runner.IsFinished` |
| --- | --- | --- |
| [SingleCycleTestExample](Testing/SingleCycleTestExample.TcPOU) | [AdditionTest](Testing/AdditionTest.TcPOU) defines the assertion. [AdditionTestRunner](Testing/AdditionTestRunner.TcPOU) registers the test as its only root. | One passed test. |
| [MultiCycleTestExample](Testing/MultiCycleTestExample.TcPOU) | [TimerDelayTest](Testing/TimerDelayTest.TcPOU) keeps its TON between calls and returns BUSY until the 20 ms delay elapses. [TimerDelayTestRunner](Testing/TimerDelayTestRunner.TcPOU) owns it. | One passed test after several scans with the supplied task period. |
| [GroupedTestExample](Testing/GroupedTestExample.TcPOU) | [BasicTestRunner](Testing/BasicTestRunner.TcPOU) owns [BasicTestGroup](Testing/BasicTestGroup.TcPOU). The group registers Addition and a nested [TimingTestGroup](Testing/TimingTestGroup.TcPOU) containing the timer test. | Two passed tests. Groups organize tests and do not add to the leaf count. |

## Read a mapped analog input

[IOModelsExample](IO/IOModelsExample.TcPOU) requires an EL3001 with the standard status-plus-INT16 PDO.
Follow the XAE mapping list in the program declaration, then set `_BindingsConfigured` TRUE.
Read `_Voltage` only while `_InputValid` is TRUE. A valid raw value of 0 gives 0 V and 32767 gives 10 V.
The first scan establishes the toggle baseline. On later scans `_InputUpdated` is TRUE when the input is valid
and the toggle differs from the preceding scan. A PLC trace can show a one-scan update that Watch misses.

For complete applications see [Intersection](../../Guides/SignalControlledIntersectionDemo.md)
and [Workflow](../../Guides/WorkflowConstruction.md).
