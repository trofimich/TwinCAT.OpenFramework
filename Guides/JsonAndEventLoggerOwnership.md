# JSON and EventLogger: task ownership

`TOF_JSON.AutomaticJsonSerializer`, `TOF_JSON.JsonConfigurationReader`,
`TOF_JSON.JsonConfigurationWriter`, and `TOF_Core.EventLoggerMessage`
have **one owner task per instance**. All application method calls and property
access, including configuration, belong to that task. A call must finish before
another operation starts on the same instance. Initialization and destruction
must not overlap application operations.

These classes have no internal locks or cross-task checks, and you must not call an instance again from inside its own callback. `Try` methods catch normal runtime errors and return `FALSE`, but they cannot make cross-task access or nested callbacks on the same instance safe.

Each program in the fragments below should be assigned to its matching task. Every PLC task must also run end-of-cycle exception cleanup (`ExceptionManager.Cleanup()`, `DynamicMemoryManager.CleanupMemory()`) and call `DynamicMemoryManager.RaiseIfAllocationFailed()` outside recovery handlers (`AutomationRunner` handles this automatically if you use it).

## Separate JSON instances

Define a static structure type with native type information available to the
JSON library:

```iecst
(*! <summary>Holds an owner task's position and readiness snapshot for JSON output.</summary> *)
TYPE ST_JsonSnapshot :
STRUCT
    Position : LREAL;
    Ready : BOOL;
END_STRUCT
END_TYPE
```

Assign `PRG_ControlJson` to `Task_Control`. The owner task updates `snapshot`
and sets `serializeRequested` when output is needed:

```iecst
(*! <summary>Serializes a snapshot owned exclusively by Task_Control.</summary> *)
PROGRAM PRG_ControlJson
VAR
    serializer : TOF_JSON.AutomaticJsonSerializer;
    snapshot : ST_JsonSnapshot;
    json : TOF_Core.JSON_DOCUMENT;
    jsonSize : UDINT;
    jsonValid : BOOL;
    serializeRequested : BOOL;
END_VAR

IF serializeRequested THEN
    serializeRequested := FALSE;
    jsonValid := serializer.TrySerialize(
        sourceStructure := snapshot,
        extender := 0,
        targetJson := json,
        jsonSize => jsonSize);
END_IF
```

Assign a second program to `Task_Diagnostics`, with its own storage:

```iecst
(*! <summary>Serializes a snapshot owned exclusively by Task_Diagnostics.</summary> *)
PROGRAM PRG_DiagnosticsJson
VAR
    serializer : TOF_JSON.AutomaticJsonSerializer;
    snapshot : ST_JsonSnapshot;
    json : TOF_Core.JSON_DOCUMENT;
    jsonSize : UDINT;
    jsonValid : BOOL;
    serializeRequested : BOOL;
END_VAR

IF serializeRequested THEN
    serializeRequested := FALSE;
    jsonValid := serializer.TrySerialize(
        sourceStructure := snapshot,
        extender := 0,
        targetJson := json,
        jsonSize => jsonSize);
END_IF
```

The identically named local variables are different instances. Neither program
calls or reads the other's serializer. Consume the latest conversion output
only when `jsonValid` is `TRUE`; `jsonSize` includes the terminator. On failure,
output may be partial and must not be treated as a valid new document.

Separate serializers do not protect shared data. If diagnostics needs data from
the control task, transfer an owned snapshot using an application synchronization
mechanism before serialization. An ordinary structure assignment from a buffer
being modified concurrently is not a synchronized snapshot. Likewise, publishing
the JSON to another task requires synchronized transfer of its content and status.
During deserialization, the owner must have exclusive access to the destination;
other tasks must not read a partially updated structure.

## Extender callbacks and nested conversion

`WritePrefix` and `WriteSuffix` run synchronously in the serializer's owner
task. Each callback borrows the writer only until that callback returns. It must
not retain the writer or hand it to another task.

For example, while `outerSerializer` is inside `WritePrefix`:

| Callback action | Contract |
| --- | --- |
| Write the prefix through the supplied SAX writer | Supported |
| Call Serialize/TrySerialize or Deserialize/TryDeserialize on `outerSerializer` | Not allowed (the same serializer is already busy) |
| Read or change `outerSerializer.DecimalPlaces` | Not allowed while serialization is running |
| Convert an independent structure with `nestedSerializer` and a separate buffer | Supported if that serializer is idle and belongs to this task |

Keep the outer source stable and its destination exclusive throughout callbacks.
Nested conversion must not modify or alias those buffers. A stateful extender
also needs a single owner or its own explicit synchronization; two independent
serializers do not make one shared extender safe. Make sure callbacks do not loop back
and call a serializer that is already running.

## Separate EventLogger message instances

`EventLoggerMessage` is abstract. An application descendant must provide its
event definition and concrete metadata. For example, a descendant named
`FB_MachineEvent` can expose this method, in addition to its `EventEntry`,
`ClassName` and `NamespaceName` implementations:

```iecst
(*!
<summary>Attempts to send this event with an owner-task JSON payload.</summary>
<description>Call only from the message's owner task, and never recursively from inside its own callback. Borrows stable JSON for the call.
Returns the native send outcome through InternalTrySend; failure does not roll back prior native effects.</description>
<param name="jsonData">Stable JSON text for this event.</param>
*)
METHOD TrySend : BOOL
VAR_IN_OUT CONSTANT
    jsonData : STRING(1000);
END_VAR

TrySend := InternalTrySend(jsonData := jsonData);
```

With that application-specific descendant defined, use independent instances:

```iecst
(*! <summary>Sends events exclusively from Task_Control.</summary> *)
PROGRAM PRG_ControlEvents
VAR
    message : FB_MachineEvent;
    payload : STRING(1000) := '{"ready":true}';
    sendRequested : BOOL;
    sent : BOOL;
END_VAR

IF sendRequested THEN
    sendRequested := FALSE;
    sent := message.TrySend(jsonData := payload);
END_IF
```

```iecst
(*! <summary>Sends events exclusively from Task_Diagnostics.</summary> *)
PROGRAM PRG_DiagnosticsEvents
VAR
    message : FB_MachineEvent;
    payload : STRING(1000) := '{"diagnostics":true}';
    sendRequested : BOOL;
    sent : BOOL;
END_VAR

IF sendRequested THEN
    sendRequested := FALSE;
    sent := message.TrySend(jsonData := payload);
END_IF
```

Configure each instance's source information in its owner task before sending.
The descendant must not use an overridden property or callback to send through
the same message recursively. A `FALSE` send result does not schedule a retry;
the application decides what to do next. Event definitions and source identity
remain application choices: separate instances do not automatically create
distinct event IDs or source identities.

## If a shared service is needed later

A future service can accept requests through a synchronized queue and perform
all native message operations in one owner task. Such a service must explicitly
define queue capacity, behavior when full, ordering and how producers observe
acceptance versus actual sending. Queue entries must own their payload copies;
do not enqueue references to a producer's temporary or reusable buffer, borrowed
writers or task-local exception objects.

This queued service is just an idea for how your application could extend it — not
a built-in `EventLogger` API. Wrapping one shared instance in a mutex does not make
multi-task access supported, because TwinCAT system blocks underneath can also expect
all calls to stay in one task.
