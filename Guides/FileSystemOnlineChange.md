# FileSystem: preparing for online change

Finish all file operations and close their files **before** triggering TwinCAT online
change. Keeping a file open or a file operation running during online change is not
supported. Your application (and the person running online change) must make sure files
are closed first — the library does not pause or intercept TwinCAT's online-change dialog.

## Finish work while the PLC is still running

1. Stop all code (including background tasks) from starting new file operations, and
   keep them paused until online change finishes.
2. For each running `FileContentManager`, set `StopWhenNoPendingTasks := TRUE` and
   keep calling its `Execute()` every PLC cycle from its owning task. This lets already
   queued operations finish and then closes the file. If it is okay to drop waiting
   operations, call `Cancel()` instead and keep calling `Execute()` until
   `State.Stopped`. Remember: `Cancel()` only requests a stop — it does not finish or
   undo partial work right away.
3. Keep calling `Execute()` on standalone file and directory tasks until they stop
   (either normally or after `Cancel()`). For child tasks queued inside
   `FileContentManager`, let the manager drive them — do **not** call their `Execute()`
   separately.
4. Keep all settings, task instances, managers, and read/write data buffers alive
   until everything finishes. Never reset or destroy an active task to force it to stop,
   and never replace normal PLC cycles with a delay or blocking `WHILE` loop.

Even when a `FileContentManager`'s queue is empty, it can still hold an open file. A
child read/write task reaching `STOPPED` also does not mean the manager closed the file.
A `READY` task that never started does not need to be started and cancelled — just make
sure nothing starts it during preparation.

## Check that everything really closed

Before running online change, every active file task and manager must finish stopping
and closing: there should be no pending open, read, write, directory listing, or close
call, and no open file handle left behind.

Look at task results and error logs carefully. If a low-level close or directory-abort
call fails, the library stops trying to clean up that resource right away, so
`State.Stopped` or `ResourceAcquired = FALSE` does not guarantee TwinCAT actually
released the OS file handle. Because log messages can also be dropped if logging fails,
having no logged errors is not proof either. There is no single flag that guarantees the
file was closed physically after a low-level error.

If cleanup fails, gets stuck, or you are not sure it completed, fix the underlying file
or server problem before running online change — the library does not retry automatically.
Only perform online change once all file operations and handles are cleanly closed.

`FileHandleResourceManager.FB_exit` is only a last-resort fallback. It cannot wait for
TwinCAT's async close to finish and cannot move an open handle to a new copy during
online change. If you follow the steps above, files are already closed long before
`FB_exit` runs.

## Resume safely after online change

Keep new file requests paused until your tasks are ready again. Save any results you
still need before resetting. Reset a stopped `FileContentManager`, restore its settings
(including `FilePath`, which `Reset()` clears), prepare its child tasks, and add them
back to the queue before calling `Start()`. Note that resetting the manager clears the
queue — it does **not** reset the child tasks themselves. Set `StopWhenNoPendingTasks`
back to your normal operating value before restarting.

Cancelling or failing a task can leave waiting entries in the queue until you remove
them or reset the manager. Removing a child from the queue does not clear the data
buffer pointer it is holding: call `Reset()` on a `STOPPED` child to clear that
reference (`Reset()` on a `READY` child does nothing, so clear or replace a removed
`READY` child's buffer reference manually before freeing the old buffer). Do not keep
old raw TwinCAT file handles after closing.

## Loggers and other wrappers that own a file manager

Follow the same steps for loggers or components that manage files internally — always
use their public stop/close methods instead of touching internal fields.

For `SimpleTextFileLogger`, call `Stop()` from its owning task and keep calling
`Execute()`. After `Stop()`, new log messages are rejected right away, while messages
already accepted finish writing (including rotating files if needed). Once writing
finishes, the logger enters `STOPPING` to close the file, then `STOPPED` after buffers
are cleaned up. Until queued messages finish writing, `State` may still say
initializing or `LOGGING`, and `Busy` stays `TRUE`. Notice that `Stop()` only starts
stopping — it does not mean the file is closed yet.

Check for `FAILED` too: if initialization or writing fails, the logger runs its
error cleanup and may drop queued messages that were not written yet — keep calling
`Execute()` until that cleanup finishes. Reaching `STOPPED` still shares the
manager's limitation: after a low-level close error, it does not guarantee the OS
file handle was released. Likewise, `Busy = FALSE` alone does not mean it is safe,
because a logger waiting without `Stop()` can still hold an open file.

After online change, call `Start()` to resume a normally stopped logger (it returns
`FALSE` in any other state, including `FAILED`). `Execute()` checks the folder again and
creates the next log file when the next message arrives. The file counter is preserved
so it moves on to the next number instead of reopening the old file (timestamp/counter
names are not guaranteed to be unique if another run or instance writes to the same
folder). At PLC startup, a fresh logger still starts automatically without `Start()`.

If `SimpleTextFileLogger` is wrapped inside `QueuedLogger`:
1. Stop all code that sends log messages, then keep calling `QueuedLogger.Execute()` from
   its owning task until `PendingMessageCount = 0`.
2. Only then call `Stop()` on the inner `SimpleTextFileLogger` from that same task.
3. Keep calling `QueuedLogger.Execute()` so the inner logger finishes closing — do
   **not** call `Execute()` on the inner logger directly. Stopping the inner logger
   early causes remaining queued messages to be rejected. Also check
   `FailedDeliveryCount` in addition to the logger state, since an empty queue alone
   does not prove every message succeeded. Remember that this shuts down file handles;
   do not expect `QueuedLogger`'s cross-task synchronization state to carry over
   unchanged across online change.

Inside `SimpleTextFileLogger`, its internal file tasks send their own status logs directly
to a private `AdsLogger` instead of going through `LogManager`, so logging its own file
work cannot loop back into the same file logger. Any standalone `Task` normally sends
status logs through `LogManager` unless you assign its optional `DiagnosticLogger` to
bypass `LogManager` — if you do, keep that target logger alive and untouched until after
the task stops and resets, and never point it back into `LogManager`.
