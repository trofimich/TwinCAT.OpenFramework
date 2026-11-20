# TwinCAT OpenFramework Testing

Choose a base class for one scenario:

| Type | Override | Completion |
| --- | --- | --- |
| `SingleCycleTest` | `ExecuteTest` | Returning from the body completes the test. |
| `MultiCycleTest` | `ExecuteTest : TEST_CYCLE_RESULT` | Return `BUSY` to wait for another cycle, or `DONE` when finished. |
| `TestGroup<N>` (abstract) | `Children` reference property | Executes its `N` children sequentially, including nested groups. |
| `TestRunner<N>` (abstract) | `Children` reference property | Drives `N` root elements and reports the run result. |

All concrete tests, groups, and runners must provide the standard `TOF_Core.Object` properties (`ClassName`, `NamespaceName`, and `SelfSize`). Tests also have optional `BeforeTest` and `AfterTest` methods for setup and cleanup. Creating a test only stores its `name` and `parent` — it does not inspect the tree or call overridden methods yet. Always pass all `FB_init` parameters explicitly (no defaults): for example, `test : AdditionTest(name := "Addition", parent := 0);`. Use `parent := 0` for root items, and `parent := THIS^` for items inside a group.

Each item's `name` is a `WSTRING` up to 80 characters (longer names are cut off normally by TwinCAT). Full group paths built for reporters are limited to 255 characters.

## Start with one test

1. Create a function block extending `TOF_Testing.SingleCycleTest`.
2. Override `METHOD PROTECTED ExecuteTest` and add checks such as
   `Assert.ThatDInt(actual := 2 + 3).ToBe(expected := 5);`.
3. Create a concrete runner extending `TOF_Testing.TestRunner<1>` and declare your test inside it with `parent := 0`.
4. Put that test in a persistent `ITestElement` array and override `Children` to return it with `REF=`.
   Also implement `ClassName`, `NamespaceName`, and `SelfSize` (see `AdditionTestRunner`).
5. Call `runner.Execute(cleanupTaskMemory := TRUE)` once per PLC task cycle.
6. Wait until `runner.IsFinished` becomes `TRUE`, then check `AllPassed`, `ExitCode`, and the test counts.

You do not have to use a group. Even though the test itself runs in one cycle, starting the runner and reporting take a couple of extra cycles.

Executable sources:

- [AdditionTest](../TwinCAT.OpenFramework.HowTo/Testing/AdditionTest.TcPOU)
- [AdditionTestRunner](../TwinCAT.OpenFramework.HowTo/Testing/AdditionTestRunner.TcPOU)
- [SingleCycleTestExample](../TwinCAT.OpenFramework.HowTo/Testing/SingleCycleTestExample.TcPOU)

## Wait across cycles

To test something that takes more than one PLC cycle (like a timer or file operation), extend `TOF_Testing.MultiCycleTest`. Keep your state and objects in FB fields. Set things up once in `BeforeTest`, advance one small step each cycle in `ExecuteTest`, and return `TOF_Testing.TEST_CYCLE_RESULT.BUSY` to wait for the next cycle or `TOF_Testing.TEST_CYCLE_RESULT.DONE` when finished (any failed assertion also stops the test immediately when `ExecuteTest` returns). Use a typed `ENUM` if your test has multiple steps.

`Timeout` defaults to `T#1S` (change it before running; `T#0S` disables the timeout). `Elapsed` starts at zero and counts scheduled PLC task cycles using `LTIME` — so it measures PLC cycle time rather than CPU execution time or wall-clock pauses. If `Elapsed` reaches `Timeout` before the next step starts, the test stops with a timeout failure before running `ExecuteTest` again.

- [TimerDelayTest](../TwinCAT.OpenFramework.HowTo/Testing/TimerDelayTest.TcPOU)
- [MultiCycleTestExample](../TwinCAT.OpenFramework.HowTo/Testing/MultiCycleTestExample.TcPOU)

## Group related tests

`SingleCycleTest`, `MultiCycleTest`, and `TestGroup<N>` all implement `ITestElement`. Create your own concrete FB extending `TestGroup<N>` with a fixed child count `N`. Declare its tests and child groups with `parent := THIS^`, then put them in an interface array. Use the inherited `_ChildCount` constant to size the array — do not declare `VAR_GENERIC CONSTANT` again in the subclass.

Override `Children` with the exact generic array type:

`PROPERTY Children : REFERENCE TO ARRAY [0.._ChildCount - 1] OF TOF_Testing.ITestElement`

Its getter only needs `Children REF= _Children;`. Always return the same valid array and do not swap children while the group exists (the compiler allows writing through a reference property, so never modify it from outside). `N = 0` uses an empty array.

Groups have no `Configure` method: `parent` is passed in `FB_init` just to describe which group owns each item (passing `parent` does not dynamically allocate or register anything). At the start of a run, `Reset` checks that the array exists, has no empty (`0`) slots, has no duplicates, matches every child's `Parent`, and contains no parent loops. `Execute` expects `Reset` to have succeeded (so if `Reset` failed, fix the issue and `Reset` again). Empty arrays or null slots throw `DataMemberNotSpecifiedException`; duplicate/mismatched/loop wiring throws `StandardException`. Because nested checks can fail after earlier sibling groups already reset, `Reset` cannot undo earlier sibling resets. Constructors do not validate the tree.

One `runner.Execute` call runs at most one test body at a time; a multi-cycle test holds its place until finished. Groups do not count as extra tests and have no setup/teardown hooks of their own. Calling `Reset` restarts the same fixed group tree.

Groups also implement `IParentTestElement`: `ChildCount` returns `N`, and `GetChildByIndex(index := ...)` returns a direct reference to child `index` without resetting or running it (throws `DataMemberNotSpecifiedException` if the array or slot is null, or `ArgumentOutOfRangeException` if `index` is outside `0..ChildCount - 1`). It works even before `Reset` or after a failed `Reset` as long as the selected slot exists; an empty group (`N = 0`) has no valid index.

`TestRunner<N>` works the same way: extend `TestRunner<N>` in your own concrete FB that owns the root tests/groups and their `ITestElement` array, and override `Children`. At startup, the runner checks that its root array is valid with no nulls, duplicates, already-running items, or children belonging to a group, and then resets and runs them (subsequent cycles skip repeating that tree check). Root items must pass `parent := 0`; one test or group can belong to only one runner. Keep all test objects alive and run each runner from one PLC task only (do not call it again from inside its own callback). Even with `N = 0`, provide a valid empty array — the runner simply finishes with zero tests.

Complete static compositions and their entry program:

- [BasicTestGroup](../TwinCAT.OpenFramework.HowTo/Testing/BasicTestGroup.TcPOU)
- [TimingTestGroup](../TwinCAT.OpenFramework.HowTo/Testing/TimingTestGroup.TcPOU)
- [BasicTestRunner](../TwinCAT.OpenFramework.HowTo/Testing/BasicTestRunner.TcPOU)
- [GroupedTestExample](../TwinCAT.OpenFramework.HowTo/Testing/GroupedTestExample.TcPOU)

## Failures, cleanup and another run

Calling `Assert.That*` or `RecordFailure(message := ...)` records the first failure and lets the rest of your `ExecuteTest` body finish normally. An uncaught exception in `BeforeTest` or `ExecuteTest` also fails the test. `AfterTest` still runs once even when `BeforeTest` fails (so write `AfterTest` safely in case setup did not finish), and an exception in `AfterTest` fails the same test. Later failures never overwrite the first failure, and the runner moves on to the next test afterward. Caught exceptions save their message, location, and which stage failed (falling back to stage/error-code text if custom formatting fails). If a custom reporter or custom element throws an exception, the run aborts (`ExitCode = -1`), saving `CallbackMessage` and `CallbackException`.

If dynamic memory runs out (`__NEW` fails), execution stops outside normal recovery handlers — it is never converted into a passing test, and normal cleanup hooks may not run. For method-local FBs on code paths that can throw exceptions, do not rely on `FB_exit` to free resources (TwinCAT skips `FB_exit` when an exception leaves a method); keep resource owners in persistent FB fields and clean them up explicitly.

Once a test run finishes, `runner.Reset()` prepares the runner for another run (on the next `Execute`, tests reset and run `BeforeTest` again; calling `Reset()` while a run is still in progress does nothing). `Reset` does not run `AfterTest` teardown — it is not a cancel command. If a custom element or reporter aborted the run (`ExitCode = -1`), clean up any external resources you opened first, then call `runner.Reset()` — after an abort, `Reset` re-validates the tree and resets all elements right away (even if an element was left running; if your custom `Reset` throws, fix the issue and call `runner.Reset()` again).

After a normal run finishes (`IsFinished = TRUE`), `ExitCode` equals the number of failed tests and `AllPassed` tells you whether every test passed. Reporters also support skipped-test counts for custom elements (the built-in single/multi-cycle test classes do not skip tests).

## Assertion semantics

Use a typed entry for literals, variables, properties, arithmetic and function/method results:

```structuredtext
Assert.ThatDInt(actual := 2 + 3).ToBe(expected := 5);
Assert.ThatBool(actual := first.Equals(other := second)).IsTrue();
Assert.ThatReal(actual := measuredTemperature, message := "Measured temperature")
	.IsGreaterThanOrEquals(expected := REAL#20.0, tolerance := LREAL#0.1)
	.IsLessThanOrEquals(expected := REAL#30.0, tolerance := LREAL#0.1);
```

Each typed assertion copies the actual value right when `Assert.That*` is called — it does not hold a pointer to temporary expressions and does not use dynamic memory. Expected values are only used during each check. Finish one assertion chain before starting another on the same `Assert` helper: do not store a reference to the assertion context, and do not call `Assert` again while computing an argument for the current check. Use each test runner and `Assert` helper from one PLC task only.
Each assertion type has its own small persistent helper object inside the provider (plus generic `AssertionContext`), storing a copy of the value, a link back to the test reporter, and the failure prefix message without dynamic allocations. Shared `TestServices` formatting and floating-point comparison helpers keep no state between calls. `Prepare` methods and internal helpers live in the `Service methods` folder.

| Entry methods | Context/input types |
| --- | --- |
| `ThatBool` | `BoolAssertionContext` / `BOOL` |
| `ThatSInt`, `ThatInt`, `ThatDInt`, `ThatLInt` | Matching `SInt`/`Int`/`DInt`/`LInt` contexts and signed IEC types |
| `ThatUSInt`, `ThatUInt`, `ThatUDInt`, `ThatULInt` | Matching unsigned contexts and IEC types |
| `ThatByte`, `ThatWord`, `ThatDWord`, `ThatLWord` | Matching bit-string contexts and IEC types |
| `ThatReal`, `ThatLongReal` | `RealAssertionContext` / `REAL`; `LongRealAssertionContext` / `LREAL` |
| `ThatString`, `ThatWideString` | `StringAssertionContext` / `STRING(255)`; `WideStringAssertionContext` / `WSTRING(255)` |
| `ThatTime`, `ThatLongTime` | `TimeAssertionContext` / `TIME`; `LongTimeAssertionContext` / `LTIME` |
| `ThatDate`, `ThatLongDate` | `DateAssertionContext` / `DATE`; `LongDateAssertionContext` / `LDATE` |
| `ThatDateTime`, `ThatLongDateTime` | `DATE_AND_TIME` and `LDATE_AND_TIME` contexts |
| `ThatTimeOfDay`, `ThatLongTimeOfDay` | `TIME_OF_DAY` and `LTIME_OF_DAY` contexts |
| `ThatPointer` | `PointerAssertionContext` / `PVOID` |

Every assertion type provides `ToBe` and `NotToBe`. `ThatBool` adds `IsTrue` / `IsFalse`; `ThatPointer` adds `IsNull` / `IsNotNull`. Numbers, strings, dates, and times support `<`, `<=`, `>`, `>=` checks, and strings add `ToContain`. Time-of-day comparisons use TwinCAT's native time-of-day order (`TOD` / `LTOD`), and floating-point checks follow the Core rule where `NaN` ("not a number") sorts first.

Choose the `Assert.That*` method that matches the type you want to test: `ThatReal` converts both numbers to `REAL`, `ThatLongReal` converts them to `LREAL`, and 64-bit integer helpers keep full integer precision without float rounding. Typed string helpers (`ThatString`, `ThatWideString`) accept up to 255 characters. For longer strings, mixing different integer types, structs, or FBs, use generic `Assert.That(actual := variable, message := "...")` — remember that `ANY` inputs only accept live variables (store literals, constants, properties, or expressions in a local variable first). Struct/FB equality in generic `That` compares raw memory bytes (including alignment padding); to compare objects by domain rules, call `Assert.ThatBool(actual := objA.Equals(other := objB)).IsTrue()`. `ThatPointer` compares memory addresses only; for interfaces or `REFERENCE TO`, use `Assert.ThatBool` with `= 0` or `__ISVALIDREF(...)`.

Only `ThatReal` and `ThatLongReal` have an optional `tolerance : LREAL := LREAL#0.0` parameter (in `ToBe`, `NotToBe`, `IsGreaterThanOrEquals`, and `IsLessThanOrEquals`). Set `tolerance >= 0.0` to allow that much difference for that single check (negative values, `NaN`, or infinity immediately fail the test). A tolerance of `0.0` checks exact equality while treating `NaN = NaN` and `+0.0 = -0.0`. Opposite-sign numbers safely avoid subtraction overflow, generic `That` has no tolerance, and the next floating-point check resets back to `0.0` automatically.

Every `Assert.That*` call accepts an optional `message : WSTRING(255) := ""` prefix for all checks in that chain (reusing `Assert` clears the previous prefix unless you pass a new `message`). Each failed check adds details showing expected vs. actual values, and the test keeps the first failure. `WithMessage` and `WithTolerance` have been removed.

## Reporters and task boundaries

By default, results are printed to TwinCAT ADS logs (`AdsReporter`). Set `runner.Reporter` before starting to use another reporter. `JUnitXmlReporter` builds a single JUnit XML testsuite where each testcase's `classname` is the group path (`ITestElement.GetPath()` walks up `Parent` names separated by `/`, ignoring empty names and truncating at 255 characters with `...`; loops in `Parent` links throw `StandardException`). Read `ContentLength` bytes starting at `ContentAddress` once `IsReady` is `TRUE` (before resetting or starting another run — an aborted run may leave partial XML, and never assign the `JUnitXmlReporter` FB directly to another variable).

Run each test tree, runner, and reporter from one cyclic PLC task only, and do not call them again from inside their own callbacks. To run tests in more than one task:

1. Give each task its own runner, test/group instances, and reporter.
2. Give tested code separate data per task, or add your own cross-task synchronization.
3. Keep starting, configuring, and reading results inside each runner's own task — copy finished results safely if another task needs them.
4. Use a separate `JUnitXmlReporter` per task (`AdsReporter` / ADS logging has no guarantee for concurrent calls from multiple tasks).

`SingleCycleTestExample` and `MultiCycleTestExample` in `HowTo` use completely separate objects and in-memory reports, so you can map them to different PLC tasks to see this setup. *(By default, `HowTo` maps `MAIN` on `PlcTask` and `MAIN` calls `SingleCycleTestExample.Execute()` — never run the same `PROGRAM` both from `MAIN` and from its own task mapping at the same time.)*

For standalone tests, call `runner.Execute()` (which defaults `cleanupTaskMemory` to `TRUE`). `Execute` checks for out-of-memory errors and then frees all temporary exceptions and auto-disposed objects created anywhere in that PLC task cycle — so call it after any other code in that cycle that reads temporary exceptions. If you run tests inside `AutomationRunner` (or run multiple test runners in one task), pass `cleanupTaskMemory := FALSE` and let the main cycle loop call `DynamicMemoryManager.RaiseIfAllocationFailed()` outside `__TRY`/`__CATCH` recovery blocks followed by `CleanupMemory()` at the end of the cycle. (`Execute` still checks for out-of-memory errors even when `cleanupTaskMemory := FALSE`; once dynamic memory runs out, the global flag stays set until the PLC application restarts.)

## Migration from TcUnit / older test versions

* Replace old `TestSuite`, `ITestSuite`, `AsyncTestContext`, and `CurrentTestSession` classes by putting each test into its own `SingleCycleTest` or `MultiCycleTest` function block (using `BeforeTest`/`AfterTest` and returning `TEST_CYCLE_RESULT.BUSY` / `DONE`).
* Put your fixed `ITestElement` child arrays inside concrete subclasses of `TestGroup<N>` and `TestRunner<N>` using `_ChildCount` for array bounds (do not redeclare `VAR_GENERIC CONSTANT`), implement `ClassName`, `NamespaceName`, and `SelfSize`, and pass `parent` explicitly at every construction site (`0` for root items, `THIS^` inside groups). `TestRunner.Configure` and `BindParent` were removed — test trees cannot be swapped between runs.
* `Reset(reporter := ...)` no longer takes a path, elements no longer store a copied parent path, and custom `TestElement` subclasses must override `Reset(reporter : ITestReporter)` (calling `SUPER^.Reset(reporter := reporter)`) instead of the removed `OnReset`. Missing `Children` arrays or null slots throw `DataMemberNotSpecifiedException`; duplicate slots, wrong `Parent` links, parent loops, or already-running roots throw `StandardException`. Startup failures set `IsFinished := TRUE`, `ExitCode := -1`, and `CallbackMessage`; `Group.Reset` and recovery `Reset` rethrow errors so you can fix them and retry.
* The ADS start message and the reporter start callback use the sum of the roots’ read-only TestCount values. Each leaf counts once, including skipped tests. Empty groups contribute zero.
* Custom reporters must implement `ReportRunStart(testCount)`, `ReportTestCaseResult(groupPath, testName, outcome, duration, message)`, and `ReportRunEnd(totalTests, passedTests, failedTests, skippedTests, duration)` with `WSTRING(80)` for `testName` and `VAR_IN_OUT CONSTANT` for `message`. Reporters throw `ArgumentValueNotSupportedException` if passed an invalid outcome enum value.
* `Assert.That*` replaces the removed `WithMessage` and `WithTolerance` modifiers with a `message` parameter on each `That*` call and a `tolerance` parameter on floating-point checks (`Generic` `That` takes variables only, with no tolerance). Typed `Assert.That*` helpers convert inputs using normal IEC rules before comparing. Rebuild all dependent projects after upgrading.

The framework's own regression suite is [TestRunnerContractTest](../TwinCAT.OpenFramework.Tests/Tests/Testing/TestRunnerContractTest.TcPOU).
The test controller advances it independently of `TOF_Testing.TestRunner`. Its 16 scenarios use direct assertions
and ADS reporting, run once per PLC application initialization, and have a separate summary.

## Source layout

- `TestElements`: shared element lifecycle, interfaces and state.
- `TestElements/Groups`: sequential group and its fixed child composition.
- `TestElements/Tests`: individual case lifecycle, interface/outcome/cycle result and single/multi-cycle strategies.
- `Runner`: root scheduling and its phase enum.
- `Assertions`: fluent provider and generic comparison/diagnostic context.
- `Assertions/TypedContexts`: copied operands and concrete literal-friendly assertion signatures.
- `Reporting`: reporter interface and ADS/JUnit implementations.
- `Internal`: namespace metadata.
- `TestServices`: caught-exception formatting and stateless assertion reporting/floating helpers.
- `Version`: generated library version metadata.

Regression tests live in the `Tests` project and standalone runnable examples live in `HowTo` (`Tests` and `HowTo` reference the `Testing` library; `HowTo` also references `Core`).
