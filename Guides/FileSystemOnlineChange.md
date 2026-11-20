# FileSystem: preparing for online change

Finish file operations and release their resources **before** online change.
Keeping an open file handle or a pending native operation across online change
is unsupported. The application and operator enforce this precondition; the
library does not intercept an IDE online-change request.

## Finish work while the application is still cycling

1. Stop producers from submitting new file work. Keep this restriction in place
   throughout preparation and online change, including background services.
2. For each running `FileContentManager`, set `StopWhenNoPendingTasks := TRUE`
   and continue calling its `Execute()` from its owner task. This lets queued
   work finish and then releases the file. If abandoning waiting work is
   acceptable, request `Cancel()` instead and continue `Execute()` until
   `State.Stopped`. Cancellation is a request, not synchronous cleanup or rollback.
3. Keep advancing standalone file and directory tasks until they stop. They may
   finish normally or accept cancellation according to the application's policy.
   Drive queued children through their manager; do not call them independently.
4. Keep configuration, task instances, resource owners and borrowed buffers alive
   throughout this process. Do not reset or destroy an active object to force
   completion. Do not replace cyclic execution with a blocking wait or a delay.

A running manager with an empty queue can still own an open file. A stopped
read/write child does not mean its manager has released that file. A never-started
READY task needs no artificial Start/Cancel cycle, but must remain prevented from
starting during preparation.

## Decide whether preparation is complete

All previously running tasks and managers must have finished their stopping and
release phases. There must be no pending open, read, write, directory operation,
enumeration, abort or close, and no retained open file resource.

Look at task results and error logs carefully. If a low-level close or directory-abort call fails, the library stops trying to clean up that resource right away, so `State.Stopped` or `ResourceAcquired = FALSE` does not guarantee TwinCAT actually released the OS file handle. Because log messages can also be dropped if logging fails, having no logged errors is not proof either. There is no single flag that guarantees physical file release after a low-level error.

If cleanup fails, gets stuck, or you are not sure it completed, fix the underlying file or server problem before running online change — the library does not retry automatically. Only perform online change once all file operations and handles are cleanly closed.

`FileHandleResourceManager.FB_exit` is a final best-effort fallback. It does not
wait for close completion and does not transfer an active handle to a copied
instance. Under the supported preparation procedure, normal release has already
completed before this callback runs.

## Resume explicitly

Keep producers paused until the application has prepared its tasks for reuse.
Save any results needed before resetting. Reset a stopped manager, restore its
configuration (including `FilePath`, which Reset clears), prepare its children
and enqueue them again before Start. Resetting the manager clears queue entries;
it does not reset its children. Restore `StopWhenNoPendingTasks` to the intended
operating policy before restarting.

Cancellation or failure can leave waiting entries retained until explicitly
cleared or reset. Removing an entry does not clear its borrowed resource binding.
A removed STOPPED child can Reset to clear that binding; Reset on a READY child
does nothing. Explicitly clear or replace a removed READY child's binding before
destroying its previous resource owner. Do not reuse cached native handles across
release or assume this procedure guarantees migration of arbitrary pointers.

## Components that hide a file manager

The same rule applies to loggers and other services owning a file manager.
Use their public shutdown contract, rather than accessing internal fields.

For `SimpleTextFileLogger`, call `Stop()` from its owner task and continue cyclic
`Execute()`. Stop immediately rejects new messages, while accepted messages finish
writing, including any required file rotations. The logger then enters `STOPPING`
for final release and `STOPPED` after release and buffer cleanup finish. Until
draining finishes, State can still report initialization or `LOGGING`; Busy remains
TRUE while the stop request is unfinished. Stop returns acceptance, not completion.

Check for `FAILED` too: if initialization or writing fails, the logger runs its
error cleanup and may drop queued messages that were not written yet — keep calling
`Execute()` until that cleanup finishes. Reaching `STOPPED` still shares the
manager's limitation: after a low-level close error, it does not guarantee the OS
file handle was released. Likewise, `Busy = FALSE` alone does not mean it is safe,
because a logger waiting without `Stop()` can still hold an open file.

After preparation and online change, `Start()` resumes a normally stopped logger.
It returns FALSE in every other state, including FAILED. Execute checks the
directory again, and the next accepted message opens the next generated file.
The file counter is retained, so resumption does not deliberately reopen the
previous file. The existing timestamp/counter naming policy is not exclusive
creation and does not guarantee uniqueness against other instances or previous
PLC runs. The initial instance still starts automatically without a Start call.

If a `QueuedLogger` wraps the backend, first stop all producers, then advance the
wrapper from its owner task until `PendingMessageCount = 0` after Execute returns.
Only then call the concrete backend's Stop from that same owner task. Continue
the wrapper's Execute to advance backend stopping; do not execute the backend
independently. Stopping the backend before the wrapper drains causes remaining
forwarded messages to be rejected. Inspect `FailedDeliveryCount` as well as the
backend state: draining the wrapper is not a guarantee of successful delivery.
Follow this order so files close cleanly before online change; note that it only
covers file shutdown, not migrating `QueuedLogger`'s internal synchronization state
across online change.

`SimpleTextFileLogger` routes its embedded task and file-resource diagnostics directly
to an owned `AdsLogger`. They bypass `LogManager` filters and counters, so servicing
this backend does not feed its own file-operation diagnostics back into the wrapper.
Standalone tasks retain normal `LogManager` routing unless their optional borrowed
`DiagnosticLogger` is configured. Keep an explicit destination alive and unchanged
through task stopping and reset; it must not return to the active logging chain.
