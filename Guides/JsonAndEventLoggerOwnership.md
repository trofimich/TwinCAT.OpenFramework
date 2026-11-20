# JSON and EventLogger: task ownership

`TOF_JSON.AutomaticJsonSerializer`, `TOF_JSON.JsonConfigurationReader`,
`TOF_JSON.JsonConfigurationWriter`, and `TOF_Core.EventLoggerMessage` must each be
used by **one PLC task only**. Every method call, property read/write, initialization,
and cleanup on one instance must happen in that same task, one call at a time.

These classes have no built-in thread locks or cross-task checks, and you must not call
an instance again from inside its own callback. `Try` methods catch normal runtime errors
and return `FALSE`, but they cannot make cross-task access or recursive callbacks on the
same instance safe.

Assign each program below to its matching PLC task. Every task must also run
end-of-cycle exception cleanup (`ExceptionManager.Cleanup()`,
`DynamicMemoryManager.CleanupMemory()`) and call
`DynamicMemoryManager.RaiseIfAllocationFailed()` outside `__TRY`/`__CATCH` recovery
blocks (`AutomationRunner` handles this automatically if you use it).

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

In the code above, both `PRG_ControlJson` and `PRG_DiagnosticsJson` use the same local
variable names, but they are completely separate instances in separate tasks. Only read
the output JSON when `jsonValid` is `TRUE` (`jsonSize` includes the trailing null byte).
If `TrySerialize` returns `FALSE`, the output buffer may be half-written and must not be
used.

Having separate serializers does not automatically protect shared PLC data. If the
diagnostics task needs data from the control task, copy a safe snapshot between tasks
first using proper task synchronization — assigning a struct while another task is
still writing to it can mix old and new fields. Likewise, synchronize sharing the finished
JSON text with another task. While deserializing into a variable, make sure no other
task reads it half-updated.

## Extender callbacks and nested conversion

`WritePrefix` and `WriteSuffix` run inside the serializer's own PLC task. The callback
may only use the supplied writer while that callback is running — do not store it or
pass it to another task.

For example, while `outerSerializer` is inside `WritePrefix`:

| Callback action | Contract |
| --- | --- |
| Write the prefix through the supplied SAX writer | Supported |
| Call Serialize/TrySerialize or Deserialize/TryDeserialize on `outerSerializer` | Not allowed (the same serializer is already busy) |
| Read or change `outerSerializer.DecimalPlaces` | Not allowed while serialization is running |
| Convert an independent structure with `nestedSerializer` and a separate buffer | Supported if that serializer is idle and belongs to this task |

Keep the outer input data and output buffer unchanged and untouched by other code
during the callback, and do not write a nested conversion into those same buffers. If
your extender stores state across calls, keep it dedicated to one task or synchronize it
yourself. Make sure callbacks never loop back and call a serializer that is already
running.

## Separate EventLogger message instances

`EventLoggerMessage` is abstract, so create your own subclass with its `EventEntry`,
`ClassName`, and `NamespaceName` properties, plus a `TrySend` method such as:

```iecst
(*!
<summary>Attempts to send this event with an owner-task JSON payload.</summary>
<description>Call only from the message's owner task, and never recursively from inside its own callback. Keep jsonData valid while the call runs.
Returns the native send outcome through InternalTrySend; failure does not undo prior side effects.</description>
<param name="jsonData">Stable JSON text for this event.</param>
*)
METHOD TrySend : BOOL
VAR_IN_OUT CONSTANT
    jsonData : STRING(1000);
END_VAR

TrySend := InternalTrySend(jsonData := jsonData);
```

With that subclass defined, declare separate instances for separate tasks:

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

Set each instance's source settings in its own PLC task before sending. Never call the
same message's send method recursively from an overridden property or callback. If
`TrySend` returns `FALSE`, nothing retries automatically — decide in your application
what to do next. Having separate instances also does not automatically give them
different event IDs or source names; configure those in your application as needed.

## If a shared service is needed later

If multiple tasks need to log events, you could build an application wrapper that takes
requests through a thread-safe queue and calls TwinCAT's event logger from one dedicated
task. Such a service should clearly define queue size, what happens when full, ordering,
and how callers check delivery results. Store full copies of event text inside queue
items rather than pointers to temporary buffers, writers, or task-local exceptions.

This queued service is just an idea for how your application could extend it — not
a built-in `EventLogger` API. Wrapping one shared instance in a mutex does not make
multi-task access supported, because TwinCAT system blocks underneath can also expect
all calls to stay in one task.
