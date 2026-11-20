# Building a dynamic workflow

This example builds a sequence containing a delay. The sequence owns the order of
execution. The workflow owns the memory of both dynamically allocated nodes.
The same order of operations applies when node types and parameters come from a recipe.

When a recipe supplies a qualified type name, call `Workflows.CreateElement`.
It accepts the owning workflow and an optional `IWorkflowElementFactory` for
application types. The returned interface borrows an already registered node.
Query the required activity or condition interface, configure it and attach it
to its parent. The sample controller uses this path for built-in nodes and
its custom movement activity. The explicit allocation sequence below shows the
same ownership handoff for callers constructing a concrete FB directly.

Use an empty workflow dedicated to this build attempt. Run construction once in
the owning task, outside TwinCAT lifecycle methods. Here, `workflow` is the live
`TOF_Workflow.Workflow` instance supplied by the caller. The pointer variables
are local to the construction method.

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

Register each new node immediately. If registration raises, discard the local
pointer. The registration path handles its own release attempt. After successful
registration, configure the node through the borrowed pointer. Add the child to
its parent once, then assign the finished root. The caller can now request a
start and drive the workflow from its cyclic execution path.

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

## Declaring a local value

`Workflow`, `Activity` and `Condition` implement `IDeclaredVariableContainer`.
During configuration, pass a typed variable containing the initial value. Its
storage can be local to the construction method.

```iecst
VAR
	initialRetryCount : UINT;
END_VAR
```

```iecst
sequence^.DeclareVariable(name := 'RetryCount', initialValue := initialRetryCount);
```

The sequence owns the current value and an independent copy of the initial value.
Use `TryGetVariable` to borrow the current value under the usual scope rules.
Each successful sequence reset restores it at the same address. A child reset
leaves the sequence's counter intact, so the counter can span loop iterations.
Condition declarations follow the reset of the activity to which they are attached.

For an existing PLC signal, use `BindPlcVariable` to bind its live storage.
Both operations share a local namespace. A duplicate name raises a configuration
error. Elementary numeric, bit-string, date/time and string variables are supported
for declarations, including `BOOL`. String storage retains the initial variable's
declared capacity.

## When to Use `Workflow` vs. `AutomationController`

Use `TOF_Automation.AutomationController` (with typed `ENUM` state machines and `TOF_Tasks.Task`) for fixed physical machine hardware and deterministic cyclic control. Use `TOF_Workflow.Workflow` when orchestrating dynamic, multi-step recipes or variable sequences configured at runtime (including scenarios loaded from JSON).

Built-in workflow elements in `TOF_Workflow`:
* **Activities**: `SequenceActivity`, `WhileActivity` (single `Body : IActivity`), `IfElseActivity`, `WaitAndPickActivity`, `ParallelActivity`, `TryCatchActivity` + `CatchActivity`, `DelayActivity`, `WaitConditionActivity`, `WaitVariableValueActivity`, `AssignVariableActivity`, `InvokeTaskActivity` (supports `ConfigureEmbeddedTask` for workflow-owned tasks and `ConfigureExternalTask` for key-resolved application tasks).
* **Conditions**: `TrueCondition`, `NotCondition`, `CompositeCondition`, `VariableHasValueCondition`, `CompareVariableCondition` (supports `ConfigureEmbeddedComparer` / `ConfigureExternalComparer`, or built-in `GENERIC_VALUE.CompareTo` ordering when no custom comparer is configured).

## Loading and Saving Workflow Configurations (JSON)

`TOF_Workflow` implements `TOF_Core.IConfigurationSerializable` independently of any serialization format, and `TOF_JSON` supplies JSON adapters (`JsonConfigurationReader` and `JsonConfigurationWriter`):

* **Saving**: pass a `TOF_Workflow.Workflow` and a `TOF_Core.JSON_DOCUMENT` to `JsonConfigurationWriter.Serialize(source := workflow, document := jsonDocument)`. Declared variables write their `initialValue` rather than transient runtime values.
* **Loading**: parse the document with `JsonConfigurationReader.Parse(document := jsonDocument)` to obtain a root `TOF_Core.CONFIGURATION_NODE`, then call `TOF_Workflow.WorkflowLoader.Load(reader := reader, root := rootNode, factory := ..., dependencyFactory := ..., resolver := ..., binder := ...)`.
  * `Load` constructs a separate dynamic `Workflow` instance owned by the caller (remember to release it via `TOF_Core.Memory.TryReleaseDynamicObject` when no longer needed).
  * Optional interfaces (`IWorkflowElementFactory`, `IWorkflowDependencyFactory`, `IWorkflowDependencyResolver`, `IWorkflowVariableBinder`) supply custom activity/condition types, embedded task/comparer types, key-resolved external dependencies, and external PLC variable bindings.
  * Required PLC variable bindings and embedded dependencies are validated before returning; on any failure, `Load` rolls back and disposes the partial graph automatically.

## Declaring and inspecting an array

`DeclareArray` takes a pointer to a contiguous sequence of IEC element descriptors
and its positive count. The sequence can be allocated at runtime. Each descriptor
must refer to live readable storage through the call. The scope copies all values.
For example, these variables describe two initial limits.

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

All elements must have the same IEC type and byte width, including string capacity.
`GetDeclaredElement` borrows a writable element by local name and zero-based index.
Arrays retain their shape even at length one. Ordinary variable lookup exposes the
whole array as aggregate storage. Use indexed access for typed element operations.

To inspect a node's declarations, start `position` at zero and call `NextDeclaration`
until it returns FALSE. It skips borrowed PLC bindings. `ElementType` preserves the
exact IEC category (for example, BYTE or USINT), `ElementSize` gives its byte width
and `IsArray` distinguishes a scalar from a singleton. For each index from zero
through `ElementCount - 1`, use `CopyInitialElement` with a descriptor for matching
writable storage. For a PLC variable, supply `Workflows.GetValueDescriptor(value := destination)`.
A format writer can also provide a descriptor for its own runtime-sized buffer.
