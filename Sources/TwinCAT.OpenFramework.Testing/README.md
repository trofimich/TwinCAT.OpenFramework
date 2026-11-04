# TwinCAT OpenFramework Testing

Choose a base class for one scenario:

| Type | Override | Completion |
| --- | --- | --- |
| `SingleCycleTest` | `ExecuteTest` | Returning from the body completes the test. |
| `MultiCycleTest` | `ExecuteTest` | Return to wait for another cycle; call `Complete()` when done. |
| `TestGroup<N>` (abstract) | `Children` reference property | Executes its `N` children sequentially, including nested groups. |
| `TestRunner<N>` (abstract) | `Children` reference property | Drives `N` root elements and reports the run result. |

Concrete tests, groups and runners provide the Core.Object metadata properties: ClassName, NamespaceName and SelfSize.
Both test base classes provide optional BeforeTest and AfterTest hooks. Construction only copies the display
name and assigned parent, without inspecting the tree or invoking overridable code. Pass every argument explicitly:
`test : AdditionTest(name := "Addition", parent := 0);`. A root has no parent; nested elements use `parent := THIS^`.
Individual names use WSTRING with an 80-character limit throughout construction, INamed access and reporter testName.
Longer input is truncated by ordinary IEC conversion. Computed group paths have a separate 255-character limit.

## Start with one test

1. Create an FB extending `TOF_Testing.SingleCycleTest`.
2. Override `METHOD PROTECTED ExecuteTest` and write assertions such as
   `Assert.ThatDInt(actual := 2 + 3).ToBe(expected := 5);`.
3. Create a concrete FB extending `TOF_Testing.TestRunner<1>` and declare the test instance inside it with `parent := 0`.
4. Initialize a persistent interface array from that instance and override `Children` to return it by reference.
   Provide the concrete runner's ClassName, NamespaceName and SelfSize; see AdditionTestRunner.
5. Call `runner.Execute(cleanupTaskMemory := TRUE)` once per task cycle at the task boundary.
6. Wait for `runner.IsFinished`, then read `AllPassed`, `ExitCode` and the result counts.

A group is optional. The body is single-cycle; runner startup and reporting use additional cycles.

Executable sources:

- [AdditionTest](../TwinCAT.OpenFramework.HowTo/Testing/AdditionTest.TcPOU)
- [AdditionTestRunner](../TwinCAT.OpenFramework.HowTo/Testing/AdditionTestRunner.TcPOU)
- [SingleCycleTestExample](../TwinCAT.OpenFramework.HowTo/Testing/SingleCycleTestExample.TcPOU)

## Wait across cycles

Extend `TOF_Testing.MultiCycleTest`. Keep the scenario's persistent objects and state in FB fields. Prepare them
once in `BeforeTest`, advance one bounded step in `ExecuteTest`, and call `Complete()` when the checks are done.
Use a typed enumeration if the scenario needs multiple phases. There is no numeric step API or separate context FB.

The `Timeout` property defaults to `T#1S`; configure it before starting. `T#0S` disables the deadline. `Elapsed`
starts at zero on the first execution and accumulates nominal calling-task periods in `LTIME` internally.
The deadline is checked before the next body, so it can prevent that body from executing at the deadline.
This measures scheduled PLC cycles, not wall-clock time or CPU execution time.

- [TimerDelayTest](../TwinCAT.OpenFramework.HowTo/Testing/TimerDelayTest.TcPOU)
- [MultiCycleTestExample](../TwinCAT.OpenFramework.HowTo/Testing/MultiCycleTestExample.TcPOU)

## Group related tests

SingleCycleTest, MultiCycleTest and abstract TestGroup<N> implement ITestElement. Create a concrete descendant
of TestGroup with a fixed child count. Declare its persistent tests and nested groups with parent := THIS^,
then initialize its interface array from those instances. Use the inherited _ChildCount for array bounds;
do not redeclare VAR_GENERIC CONSTANT in the descendant.

Override this property with the exact generic array type:

`PROPERTY Children : REFERENCE TO ARRAY [0.._ChildCount - 1] OF TOF_Testing.ITestElement`

Its getter only binds `Children REF= _Children;`. Return the same valid array and unchanged child list throughout
the group lifetime. The reference is borrowed and read-only by contract: the language still allows writes through
a reference property, so application code must not mutate it. N = 0 uses an empty array.

There is no group Configure call. Parent is assigned in FB_init and has no binding method. It describes the
assigned group even before execution; it does not register the child or transfer allocation ownership.
Reset validates array storage, non-null slots, duplicates, matching parents and acyclic parent chains
once at the beginning of each run, before calling a direct child Reset. Execute uses Children without
repeating validation and requires a successful Reset, including after any failed Reset. Missing storage or a null slot raises DataMemberNotSpecifiedException; other
topology violations raise StandardException. Nested validation or external callbacks can still fail after earlier
siblings have reset, so Reset does not guarantee rollback. The constructors perform no topology checks.

One root call executes at most one leaf body. A pending multi-cycle test holds the sequence until it completes.
Group nodes add no tests to the totals and have no setup or teardown hooks. Reset reuses the same fixed composition.

Groups expose `IParentTestElement`: `ChildCount` is the fixed direct count, and
`GetChildByIndex(index := ...)` borrows a child in execution order without resetting or executing it.
Missing array storage or a null selected slot raises `DataMemberNotSpecifiedException`;
an index outside `0..ChildCount - 1` raises `ArgumentOutOfRangeException`. Storage is checked first.
The accessor is available before Reset and after a rejected Reset when the selected slot exists;
it does not repeat whole-tree validation. An empty group has no valid child index.

TestRunner<N> is also abstract. Its concrete descendant owns root tests/groups and persistent interface-array
storage and overrides Children with the same reference signature and stable-storage contract. There is no Configure.
Runner startup validates the storage and rejects null, duplicate, running or group-owned roots before resetting
any direct root or reporting run start. Subsequent execution cycles do not repeat topology validation.
Roots explicitly use parent := 0; the runner is not their Parent. Each root belongs to one runner only;
cross-runner sharing is forbidden without an automatic registry. Keep the graph alive and use one task without reentry.
N = 0 still requires valid empty array storage and finishes with zero tests.
Group validation is recursive through Reset, not a whole-tree transaction: earlier siblings may already be reset.

Complete static compositions and their entry program:

- [BasicTestGroup](../TwinCAT.OpenFramework.HowTo/Testing/BasicTestGroup.TcPOU)
- [TimingTestGroup](../TwinCAT.OpenFramework.HowTo/Testing/TimingTestGroup.TcPOU)
- [BasicTestRunner](../TwinCAT.OpenFramework.HowTo/Testing/BasicTestRunner.TcPOU)
- [GroupedTestExample](../TwinCAT.OpenFramework.HowTo/Testing/GroupedTestExample.TcPOU)

## Failures, cleanup and another run

Assertions and `RecordFailure(message := ...)` copy the first failure and let the current callback return normally.
They do not stop subsequent statements in that callback. An uncaught preparation or body exception becomes a failed
test. `AfterTest` runs once even when `BeforeTest` fails, so it must tolerate partial preparation. A teardown
exception also fails that same test. Later diagnostics do not replace the first failure. The next test can proceed.
Caught exceptions retain copied message/source text and the interrupted stage. If a custom exception formatter
throws, a stage/code fallback is retained. Reporter or external-element aborts expose the copied `CallbackMessage`
alongside the native transport code in `CallbackException`. Neither retains an exception object after task cleanup.

Terminal OOM interrupts normal execution outside recoverable handlers. It is never converted into a passing result,
and normal cleanup hooks are not promised after terminal OOM. Method-local FBs on throwing paths must not rely on
`FB_exit` for resource cleanup; use persistent instance fields and explicit scenario cleanup.

`runner.Reset()` rearms a completed runner. The next Execute recursively resets observations and runs each scenario's
preparation again. Reset during normal execution is ignored. Element Reset is infrastructure, not cancellation:
it does not execute teardown. A throwing external element or reporter aborts with `ExitCode = -1`, and the callback
is not retried. Before resetting such an aborted tree, recover any remaining user resources explicitly.
After abort, Reset validates the fixed root storage and topology and recursively resets the same tree immediately.
Running roots are allowed during recovery. Invalid storage or topology raises before any root Reset and retains
the aborted observations. It invokes element Reset callbacks, but no scenario, teardown or reporter callback.
If a custom Reset throws, the runner retains its aborted observations; fix the cause and retry Reset.
For other runs, tree reset remains deferred until the next Execute.

For normal completion, `ExitCode` is the number of failed leaves. `AllPassed` is meaningful after `IsFinished`.
Skipped results are supported by the common counts and reporter contract for custom elements; the two test bases
do not provide a skip command.

## Assertion semantics

Use a typed entry for literals, variables, properties, arithmetic and function/method results:

```structuredtext
Assert.ThatDInt(actual := 2 + 3).ToBe(expected := 5);
Assert.ThatBool(actual := first.Equals(other := second)).IsTrue();
Assert.ThatReal(actual := measuredTemperature, message := "Measured temperature")
	.IsGreaterThanOrEquals(expected := REAL#20.0, tolerance := LREAL#0.1)
	.IsLessThanOrEquals(expected := REAL#30.0, tolerance := LREAL#0.1);
```

Each typed context copies actual into persistent instance storage before the entry returns. It does not retain
the address of a temporary input or allocate heap storage. Expected values are used only during their comparison.
Finish one immediate chain before starting another on the same provider, regardless of type; do not retain context
references or reenter the provider while evaluating an operand. Instances are confined to the owning test task.
The provider contains one persistent context for each type, increasing static case storage without heap allocation.
Typed contexts and the generic `AssertionContext` are independent and extend `Core.Object` directly. Each stores
its own operand or descriptor, a borrowed receiver link and a copied message. Typed predicates do not create generic value
descriptors: ordinary values compare directly, strings compare by code unit, and REAL/LREAL use stateless
floating helpers matching Core canonical semantics. Shared `TestServices` reporting retains no chain state.
`Prepare` methods and private context helpers are grouped under `Service methods` in the PLC project.

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

Every context has `ToBe` and `NotToBe`. Boolean contexts add `IsTrue`/`IsFalse`; pointer contexts add
`IsNull`/`IsNotNull`. Other typed contexts provide strict and inclusive ordering. String contexts also provide
`ToContain` with a substring in the same encoding. Time-of-day ordering uses native IEC comparisons of time since
midnight without wrapping or converting to a duration. Numeric, date and duration ordering compares typed values;
floating ordering preserves the Core NaN-first policy.

Concrete input types apply ordinary IEC conversions before assertion code executes. Choose the entry matching
the intended representation: `ThatReal` converts both operands to REAL; `ThatLongReal` converts them to LREAL.
Signed and unsigned 64-bit integer contexts preserve integer precision without floating-point conversion.
String inputs are bounded to 255 characters and ordinary parameter conversion can truncate longer inputs.
For arbitrary-length strings, heterogeneous integer comparisons, structures and FB variables, generic
`That(actual := variable, message := "...")` remains available. Both its actual and expected ANY operands must
be live variables; literals, constants, properties and expression results require typed entries or intermediates.
Generic That borrows storage rather than taking a snapshot. USER_DEFINED/FB equality compares stored bytes,
including padding and aliases; use `ThatBool` with an explicit object Equals result for domain equality.
Pointer equality compares addresses and does not inspect targets. For interfaces/references, use `ThatBool`
with an explicit null comparison or `__ISVALIDREF` predicate.

Only `RealAssertionContext` and `LongRealAssertionContext` expose a `tolerance : LREAL := LREAL#0.0` argument in
`ToBe`, `NotToBe`, `IsGreaterThanOrEquals` and `IsLessThanOrEquals`. It is a finite nonnegative absolute distance
for that call only. Strict ordering and other context types have no tolerance argument. Negative values, NaN
and infinity record failure before comparison. Zero requests Core canonical floating equality; NaNs compare
equal to NaNs, signed zeros are equal, and unequal nonfinite values never become close. Inclusive ordering
accepts Core ordering or closeness to the boundary. Finite opposite-sign distances avoid overflowing subtraction.
Generic comparisons remain exact. A following floating assertion without tolerance uses zero independently.

Every That entry has an optional `message : WSTRING(255) := ""` copied as the diagnostic prefix for the entire
chain. A successful assertion does not consume it. A new entry without a message replaces the previous prefix
with empty text. Assertions append their own expected/actual diagnostic; the test case retains its first failure.
`WithMessage`, `WithTolerance` and the modifier-reset mechanism have been removed.

## Reporters and task boundaries

The default reporter writes ADS diagnostics. Set `runner.Reporter` before starting to use a custom reporter.
`JUnitXmlReporter` builds one flat JUnit testsuite; each testcase's `classname` contains its group path.
`ITestElement.GetPath()` computes the full path through `Parent`, including the element's own name, without Reset.
Nonempty names are separated by `/`; an empty name adds no separator. The result retains up to 255 wide characters,
with a final ellipsis on overflow. Cyclic parent links raise `StandardException`; use the tree from its owning task.
Leaf reporting uses `Parent.GetPath()` as the group path, or empty text for a root leaf, keeping the test name separate.
`Reset(reporter := ...)` no longer accepts a path, and elements no longer store a copied parent path.
Paths are display names, not unique identifiers. Adding GetPath and changing Reset require consumer migration and rebuild.
Test names and copied error diagnostics are escaped, including wide Unicode characters.

Read `ContentLength` bytes from `ContentAddress` after `IsReady`, before report reset or the next run.
An aborted callback can leave incomplete XML and partial result counts. Do not copy the reporter's buffer-owning FB.

Run each tree, runner and reporter from one cyclic PLC task without reentry. To run independently in several tasks:

1. Give every task its own runner, test/group instances and reporter.
2. Give tested objects separate mutable state, or use their explicitly documented synchronization.
3. Call each runner from its owning task and keep configuration and observation in that task. Other tasks must not
   directly inspect live mutable state; transfer completed results through an externally synchronized mechanism.
4. Use a separate `JUnitXmlReporter` per task for independent in-memory output. The ADS backend has no established
   concurrent-call guarantee, even for separate reporter instances.

`SingleCycleTestExample` and `MultiCycleTestExample` own disjoint objects and in-memory reports. Assign them to
different tasks to inspect this arrangement. The examples are registered in HowTo but are not automatically mapped
to PLC tasks by this change. Do not assign the same program instance to multiple tasks.
The existing HowTo `PlcTask` maps `MAIN`, which calls `SingleCycleTestExample.Execute()`.
Each example PROGRAM also delegates its mapped cyclic body to its own Execute method. Use one entry path per instance;
do not additionally map SingleCycleTestExample while MAIN is driving it. These standalone methods perform task cleanup;
hosts with additional transient-exception consumers must supply a shared boundary instead.

For standalone execution, use `runner.Execute()` or explicitly pass `cleanupTaskMemory := TRUE` (the default).
Execute checks terminal allocation failure and then cleans all registered auto-disposed objects and the exception
payload of the current PLC task, not only objects created by this runner. Borrowed references to those objects
become invalid, so call it after the last transient-exception consumer in the task cycle.

When called from AutomationRunner or any other host that performs current-task memory cleanup, pass
`cleanupTaskMemory := FALSE`. With several runners in one task, pass FALSE to each and let the host provide
one shared boundary. In every task cycle, the host must call `DynamicMemoryManager.RaiseIfAllocationFailed`
outside recoverable handlers, then `CleanupMemory` after all transient-exception consumers. Execute still checks
terminal allocation failure when FALSE is passed. Fatal allocation state is application-wide and is cleared only
by application reinitialization.

## Migration

This model replaces `TestSuite`, `ITestSuite`, `AsyncTestContext` and `CurrentTestSession`.
Move each guarded scenario into its own FB. Remove `RunTests` enumeration and `Test`/`AsyncTest` guards.
Move per-scenario setup and cleanup into `BeforeTest`/`AfterTest`; use `Complete()` for multi-cycle completion.
Keep fluent `Assert.That…` expressions inside the leaf test. Declare fixed group and runner children instead of
passing `ITestSuite` arrays on every Execute call. Runner root count is now a generic constant.

Custom reporters implement `ReportRunStart(totalElements)`, `ReportTestCaseResult(groupPath, testName, outcome,
duration, message)` and `ReportRunEnd(totalTests, passedTests, failedTests, skippedTests, duration)`.
There are no group start/end callbacks. Test names are now wide strings; long `ERROR_MESSAGE` parameters remain
`VAR_IN_OUT CONSTANT`. Previous source, reporter and binary interfaces require migration.
The constructor name and reporter testName inputs now use WSTRING (80 characters), matching INamed.
Custom reporter overrides must use exactly the same input signature and be rebuilt.

Custom elements extending `TestElement` must replace old `OnReset` overrides with
`Reset(reporter : ITestReporter)` overrides and explicitly call `SUPER^.Reset(reporter := reporter)`.
The base no longer calls OnReset. Define the state left by a failed override and allow explicit retry after abort;
Reset must not silently release user resources or retry the aborted Execute callback.

The regression suite is [TestRunnerTest](../TwinCAT.OpenFramework.Tests/Tests/Testing/TestRunnerTest.TcPOU).
Source review and editing do not establish compilation or runtime behavior. Build 4026 compilation, actual task
execution, ADS/JUnit consumption, online change and terminal-OOM verification remain owner checks.

## Source layout

- `TestElements`: shared element lifecycle, interfaces and state.
- `TestElements/Groups`: sequential group and its fixed child composition.
- `TestElements/Tests`: individual case lifecycle, interface/outcome and single/multi-cycle strategies.
- `Runner`: root scheduling and its phase enum.
- `Assertions`: fluent provider and generic comparison/diagnostic context.
- `Assertions/TypedContexts`: copied operands and concrete literal-friendly assertion signatures.
- `Reporting`: reporter interface and ADS/JUnit implementations.
- `Internal`: namespace metadata.
- `TestServices`: caught-exception formatting and stateless assertion reporting/floating helpers.
- `Version`: generated library version metadata.

Folder moves preserve type names, namespace and existing object/member IDs. Regression fixtures stay in the Tests
project and executable usage examples stay in HowTo. Tests and HowTo explicitly reference the Testing PLC project;
HowTo also directly references Core. Existing library resolutions are preserved.

This revision adds `CallbackMessage` and replaces assertion modifiers with typed entry points, call-local
floating tolerance and a chain-wide message argument. Migrate `WithMessage` to the That entry and
`WithTolerance` to each supported floating comparison. Generic That still accepts variables, with no tolerance.
Typed inputs deliberately use IEC conversion rules instead of heterogeneous ANY equality. After abort, Reset now invokes
element Reset callbacks immediately, so custom recovery callbacks must tolerate retry after a partial reset.
Rebuild consumers; source-folder reorganization does not by itself establish binary or online-change compatibility.

Both TestGroup<N> and TestRunner<N> are abstract. Replace direct instances with concrete descendants that own
their child instances and persistent arrays and override Children by reference. Use the inherited _ChildCount
for array bounds; do not redeclare VAR_GENERIC CONSTANT. Provide concrete ClassName, NamespaceName and SelfSize.
TestRunner.Configure and its copied root array have been removed; root replacement between runs is no longer supported.
Parent is assigned in FB_init; pass it at every construction site: zero for roots, THIS^ for group-owned children.
BindParent has been removed. Reset repeats the same composition. Rebuild all consumers after these source and layout changes.

Missing Children storage or a null fixed slot raises DataMemberNotSpecifiedException in both groups and runners.
Duplicate slots, a mismatched parent, a cyclic group parent chain or an active root raise StandardException.
Runner Execute catches startup failures and exposes IsFinished, ExitCode = -1 and copied CallbackMessage.
Group Reset and explicit runner abort-recovery Reset propagate failures. Reporters retain
ArgumentValueNotSupportedException for an actual nonterminal outcome enum value.
