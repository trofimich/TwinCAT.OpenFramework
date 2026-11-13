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

If configuration, attachment or root initialization raises, earlier successful
registrations still belong to the workflow. The owner can abandon this unstarted
build with `DisposeDynamicChildren()` and discard all aliases into the graph.
That operation clears the entire workflow, including its root and variable
bindings. Using it on a workflow containing an earlier scenario would discard
that scenario too. Terminal allocation failure follows the application-wide
fatal latch and task-boundary contract.

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
elements[0] := TOF_Workflow.Workflows.DescribeElement(value := firstLimit);
elements[1] := TOF_Workflow.Workflows.DescribeElement(value := secondLimit);
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
writable storage. For a PLC variable, supply `Workflows.DescribeElement(value := destination)`.
A format writer can also provide a descriptor for its own runtime-sized buffer.
