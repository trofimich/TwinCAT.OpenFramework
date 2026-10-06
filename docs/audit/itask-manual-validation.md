# Ручна перевірка змін ITask

У поточній версії додано `Tests/TaskLifecycle/TaskLifecycleTest.TcPOU` до
наявного `TwinCAT_OpenFramework_Tests.plcproj`. Suite інстанційовано в
TestAutomationController; він уже використовує TcUnit.RUN(). Окремого нового
PLC-проєкту в solution немає. Нічого нижче ще не виконано як runtime перевірку.

## Збірка

1. Відкрити `Sources/TwinCAT.OpenFramework.sln` у XAE 4026.27. Звірити TcUnit 1.3.1.
2. Перебудувати залежності з поточних sources. Основний порядок:
   Core → Comparision → Collections → Tasks → Timers/FileSystem → Loggers → Tests.
   Перед Tests також перебудувати Automation → Devices.IO та їх dependencies.
   Інші Core consumers і Samples перевірити з тим самим комплектом бібліотек.
3. У Library Manager підтвердити effective resolutions на щойно зібрані версії.
   Wildcard `*` і наявність source project у solution не є підтвердженням цього.
   Не використовувати тимчасові exports 1.0.10.65000 як новий комплект.
4. За прийнятим release workflow обрати нові versions та оновити exports/resolutions
   після compiler review. Public API тут змінено; старі binaries змішувати з новими
   не слід. Versions у sources поки збережені, опублікованого release не створено.
5. Зберегти повний Build/General output і фактичні platform/compiler versions.
   Виправити всі compile errors перед запуском; XML check цього не заміняє.

## TcUnit

Нові fake tests не працюють із файлами чи IO. Existing Tests також містить
DirectoryTest, FileContentManagerTest і LoggerTest з реальними файловими paths;
перед запуском усієї Tests application звірити їхні paths із тестовим target.
Після запуску зберегти TcUnit report, failures і logs. 22 нові методи мають
завершитися; незавершений suite не означає success.

| Методи | Що перевіряють |
|---|---|
| TestCancellation1–7 | Cancel до Execute; indefinite child із delayed release; parent/child порядок і pending READY child; resource-free child; дві queue; normal success; cancel during acquire |
| TestLifecycleAndCallbacks | Start/Cancel/Reset відмови; OnBeforeStop/OnAfterStop раз на run; cyclic OnStopped; reuse |
| TestQueueGuards | Duplicate/self enqueue; Clear RUNNING; enqueue після stop request |
| TestStartAndResetRefusal | Відмова Start child зберігає child і дає failure; відмова Reset поширюється; recovery |
| TestCompositeDONE/ABORTED/ERROR/EXCEPTION | Всі internal stop paths чекають cleanup child перед release parent |
| TestCancellationVisibilityAndRecovery | Flag під час release, duplicate Cancel, STOPPED і Reset |
| TestResourceProtocol | Pre-acquired ownership; ResourceAcquired=false при pending cleanup недостатньо |
| TestReleaseFailureAndHangRecovery | Release exception, безмежне очікування, recovery; original cancel/final failure |
| TestProcessingAndCallbackFailures | Processing exception і callback exceptions; cleanup та результат |
| TestAdapterAndDiagnostics | Незалежний ITask у queue; live views, reset/cancel, optional diagnostics |
| TestProducerAndNonReadyEnqueue | Persistent queue приймає нову READY роботу; STOPPED child відхиляється |
| TestTimerIntegration | Cyclic TON completion, Triggered pulse, OnStopped, Restart і Cancel |
| TestChildCleanupFailurePropagation | Queue використовує FinalStopReason child і не приховує cleanup failure |

Fake tests виконують обмежену кількість явних scheduler steps; це моделювання
call order, не вимірювання часу PLC циклу. Timer test виконується циклічно і має
ліміт 500 Execute циклів. Повторний запуск suite робити з fresh PLC instances.

## Реальні інтеграції, які ще потрібні

- FileHandleResourceManager: запит open → Cancel поки bBusy → регулярний Execute
  до завершення open і close. Перевірити late hFile, open error, delayed close,
  і те, що повторний start/reset не використовує старий handle. Нове очікування
  pending open підтримує bExecute=TRUE до completion; реальні ADS FB outputs
  мають бути перевірені. Fake manager цього не підтверджує.
- FileContentManager: кілька borrowed file tasks на одному handle, persistent
  idle queue, cancellation перед стартом pending child. Child cleanup перед close.
- File close error: error log присутній, відповідальність manager завершується,
  результат виконаної операції не змінюється лише через best-effort close failure.
- SimpleTextFileLogger: queue production, rotation, reset/reuse WriteBytesTask;
  cancellation не додає запис до stopping queue. При child cleanup failure logger
  бачить failure через manager. Використати окремий тестовий каталог.
- Samples: скомпілювати Timer callers і workflow з новими interface views;
  апаратні сценарії виконувати лише на призначеному для них target.

## Міграція API

- `ITask.State` → `ITaskState`; `OriginalStopReason`/`FinalStopReason` →
  `ITaskStopReason`. Звичайні `.State.Running`, `.FinalStopReason.WorkDone`,
  `.Value` та `.Message` залишаються. Це live views, а не snapshots.
- Code з `REFERENCE TO TaskState/TaskStopReason` потребує interface variables
  та `:=` замість `REF=`. Для snapshot копіювати enum/message значення.
- `TaskState` constructor тепер приймає references до enum і changed BOOL;
  `TaskRunningSubstate` — reference до enum. Views та backing fields мають
  існувати довше за readers; їх не можна повертати з короткоживучих locals.
- `ResourceManager` і `RunningSubstate` залишені на concrete Task, а для generic
  ITask доступні через QueryInterface до ITaskResourceDiagnostics. RunningSubstate
  повертає ITaskRunningSubstate. Поточний concrete logger caller збережений.
- Composite descendants мають реалізувати `OnStopRequested`/`OnStopping`
  для усіх причин завершення; queue уже це робить. `OnCancelRequested` та
  `OnCancelling` збережені для external-cancel callbacks. Queue descendants,
  які override generic hooks, викликають SUPER^, якщо потребують queue cleanup.
- `Clear` RUNNING і неготові/duplicate/self children тепер відхиляються
  винятком. Спочатку Cancel → Execute до STOPPED; потім Clear/Reset/reuse.
- Release exception вимагає recovery: вона більше не завершує задачу автоматично.
  Forced stop не реалізовано; завдання не можна видаляти, поки cleanup pending.

Після ручної перевірки оновити itask-execution-journal.md конкретними
compiler/runtime results. До цього статус — реалізовано, перевірки неповні.
