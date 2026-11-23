# Building a dynamic workflow

## Choosing the execution model

Use a workflow when a procedure needs named steps, branches, waits, or recovery that
can be composed or loaded from configuration. Use a `Task` for an individual cyclic
operation with start, cancellation and cleanup. An `InvokeTaskActivity` lets the
workflow drive that task. Keep that task alive and give the activity exclusive control
of its lifecycle during the run. For fixed per-scan control with a few local states,
keep the logic in the owning PLC task or automation component.

A catch activity copies an error and may run recovery. It does not undo earlier
physical writes, task effects, or callback changes. Design the recovery step around
the effects that may already have occurred. The owning task still advances execution
and provides the task-boundary exception cleanup.

This example creates a sequence containing one delay step. The sequence controls the
order in which its child steps run, and the `Workflow` owns and frees the memory of both
dynamically created blocks. You follow the same steps whether you create blocks in code
or load them from a recipe.

When creating steps from type names in a recipe (such as JSON), call
`Workflows.CreateElement`. Pass your `Workflow` and an optional
`IWorkflowElementFactory` (for your own custom step or condition types). It creates the
object, registers it in the workflow automatically, and returns an interface you can cast,
configure, and attach to a parent step (`SequenceActivity`, etc.). The code below shows
how to do the same thing directly with `__NEW`.

Start with an empty `Workflow` dedicated to this build. Run this setup code once from
the workflow's own PLC task, outside `FB_init`/`FB_exit`/`FB_reinit`. Below, `workflow`
is your `TOF_Workflow.Workflow` variable, and `sequence` / `delay` are local pointers.

```iecst
VAR
	sequence : POINTER TO TOF_Workflow.SequenceActivity;
	delay : POINTER TO TOF_Workflow.DelayActivity;
END_VAR
```

```iecst
sequence := __NEW(TOF_Workflow.SequenceActivity(workflow := workflow));

IF sequence = 0 THEN
	TOF_Core.DynamicMemoryManager.RaiseAllocationFailure();
END_IF

workflow.RegisterChild(child := sequence^);
delay := __NEW(TOF_Workflow.DelayActivity(workflow := workflow));

IF delay = 0 THEN
	TOF_Core.DynamicMemoryManager.RaiseAllocationFailure();
END_IF

workflow.RegisterChild(child := delay^);
delay^.Interval := T#1S;
sequence^.AddChildActivity(activity := delay^);
workflow.SetRootActivity(rootActivity := sequence^);
```

Call `RegisterChild` right after `__NEW` for every new step or condition. If
`RegisterChild` throws an error, throw away your local pointer (`RegisterChild` already
cleans up on failure). Once registered, configure the block through the pointer, attach
it to its parent (`AddChildActivity`), and finally set the root (`SetRootActivity`). After
that, you can start the workflow and run it cyclically.

## An interrupted build

If setup, adding a node, or initializing the root throws an error, any nodes
registered earlier still belong to the workflow. You can clean up this unfinished
build with `DisposeDynamicChildren()` and stop using any old pointers to it. Note
that `DisposeDynamicChildren()` clears the whole workflow — including its root and
variable bindings — so only call it when abandoning the entire workflow. If the PLC
runs out of dynamic memory during construction, the global out-of-memory flag is set
and `RaiseIfAllocationFailed()` at the end of the cycle will stop the task safely.

For a larger example with a custom activity and named variables, see
[DemoWorkflowController](../Sources/TwinCAT.OpenFramework.Samples/Workflow/Classes/DemoWorkflowController.TcPOU).

## Declaring a local variable in a workflow

`Workflow`, `Activity`, and `Condition` all implement `IDeclaredVariableContainer`.
During setup, pass a typed PLC variable holding the starting value (that local variable
only needs to exist during `DeclareVariable`, because its value is copied):

```iecst
VAR
	initialRetryCount : UINT;
END_VAR
```

```iecst
sequence^.DeclareVariable(name := 'RetryCount', initialValue := initialRetryCount);
```

The sequence stores both the current value and a separate copy of the starting value.
Use `TryGetVariable` to get a pointer/reference to the variable while it runs (inner steps
can see variables declared on enclosing steps). Every time `sequence` resets, the value
is reset back to its starting value at the same memory address; resetting a single child
step inside a loop leaves `sequence`'s counter intact across loop iterations. Variables
declared on a `Condition` reset together with the step that owns that condition.

To link an existing external PLC signal instead of copying a value, use
`BindPlcVariable`. Declared variables and PLC bindings share the same name scope on that
step, so duplicate names throw an error. Basic numeric types, bit types, dates/times,
strings, and `BOOL` are supported (strings keep the declared max length of the initial
variable).

## When to Use `Workflow` vs. `AutomationController`

Use `TOF_Automation.AutomationController` (with typed `ENUM` state machines and `TOF_Tasks.Task`) for fixed physical machine hardware and cycle-by-cycle machine control. Use `TOF_Workflow.Workflow` when running flexible multi-step recipes or sequences built or loaded at runtime (for example, from JSON files).

Built-in workflow elements in `TOF_Workflow`:
* **Activities**: `SequenceActivity`, `WhileActivity` (single `Body : IActivity`), `IfElseActivity`, `WaitAndPickActivity`, `ParallelActivity`, `TryCatchActivity` + `CatchActivity`, `DelayActivity`, `WaitConditionActivity`, `WaitVariableValueActivity`, `AssignVariableActivity`, `InvokeTaskActivity` (supports `ConfigureEmbeddedTask` for tasks owned by the workflow and `ConfigureExternalTask` for existing tasks looked up by name).
* **Conditions**: `TrueCondition`, `NotCondition`, `CompositeCondition`, `VariableHasValueCondition`, `CompareVariableCondition` (supports `ConfigureEmbeddedComparer` / `ConfigureExternalComparer`, or compares numbers/strings/objects automatically with `GENERIC_VALUE.CompareTo` if no comparer is set).

## Loading and Saving Workflow Configurations (JSON)

`TOF_Workflow` implements `TOF_Core.IConfigurationSerializable` independently of file format, and `TOF_JSON` adds JSON support (`JsonConfigurationReader` and `JsonConfigurationWriter`):

* **Saving**: pass a `TOF_Workflow.Workflow` and a `TOF_Core.JSON_DOCUMENT` to `JsonConfigurationWriter.Serialize(source := workflow, document := jsonDocument)`. Variables save their starting `initialValue`, not temporary runtime values.
* **Loading**: parse the text with `JsonConfigurationReader.Parse(document := jsonDocument)` to get a root `TOF_Core.CONFIGURATION_NODE`, then call `TOF_Workflow.WorkflowLoader.Load(reader := reader, root := rootNode, factory := ..., dependencyFactory := ..., resolver := ..., binder := ...)`.
  * `Load` creates a new dynamic `Workflow` object that you own — remember to free it with `TOF_Core.Memory.TryReleaseDynamicObject` when you are done with it.
  * Optional helpers (`IWorkflowElementFactory`, `IWorkflowDependencyFactory`, `IWorkflowDependencyResolver`, `IWorkflowVariableBinder`) let you supply custom steps/conditions, embedded tasks/comparers, named external tasks/comparers, and external PLC variable bindings.
  * Required PLC variable bindings and embedded helpers are checked before returning; if anything fails, `Load` automatically frees the partially built workflow.

## Declaring and reading an array

`DeclareArray` takes a pointer to a table of `__SYSTEM.AnyType` descriptions (one per
array item) and the number of items (`elementCount > 0`). Make sure all referenced
variables stay alive during the `DeclareArray` call — the workflow copies all values
into its own storage.

```iecst
VAR
	firstLimit : UINT := 2;
	secondLimit : UINT := 5;
	elements : ARRAY [0..1] OF __SYSTEM.AnyType;
END_VAR
```

```iecst
elements[0] := TOF_Workflow.Workflows.GetValueDescriptor(value := firstLimit);
elements[1] := TOF_Workflow.Workflows.GetValueDescriptor(value := secondLimit);
sequence^.DeclareArray(name := 'RetryLimits', initialValues := ADR(elements[0]), elementCount := 2);
```

Every item in the array must have the same PLC type and byte size (including string max
length). Call `GetDeclaredElement` to get a writable reference to one array item by
name and zero-based index. Even a 1-item array keeps its array shape. Looking up the
variable by name without an index returns the whole array block, so use indexed access
for reading or writing single elements.

To inspect all declared variables on a step or condition, set `position := 0` and keep
calling `NextDeclaration` until it returns `FALSE` (this skips bound external PLC
signals). `ElementType` gives the exact TwinCAT type (for example `BYTE` vs `USINT`),
`ElementSize` gives its byte size, and `IsArray` distinguishes a single value from a
1-item array. To read each starting element from `0` to `ElementCount - 1`, pass a
matching destination variable wrapped with `Workflows.GetValueDescriptor(value := destination)`
to `CopyInitialElement`.
