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

Inspect task results and cleanup diagnostics. Native close and enumeration-abort
errors end the current best-effort cleanup attempt; they do not certify that the
server released the resource. Consequently, `State.Stopped` and
`ResourceAcquired = FALSE` are not independent proof of successful physical
cleanup. Log delivery can also be rejected, so an absence of error messages is
not such proof. The current API has no single readiness result that certifies
physical release after a native failure.

If cleanup fails, cannot finish, or its outcome is uncertain, preparation has
not been established. Resolve the native-resource problem before proceeding;
this library provides no automatic recovery or retry guarantee for that case.
Only perform online change once the application has met the precondition.

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

Check for `FAILED` as well: a write or initialization failure still uses the
existing terminal failure cleanup and can discard unwritten messages. Continue
Execute until that cleanup finishes. `STOPPED` retains the underlying manager's
best-effort close limitation; it does not certify physical release after a native
close error. `Busy = FALSE` by itself remains insufficient because a logger that
has not received Stop can be waiting with an open file.

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
This ordering covers file shutdown; it does not establish migration of the
wrapper's synchronization objects across online change.

This guide records the supported usage contract. It is not a report of a
successful compilation, runtime test or online-change experiment.
