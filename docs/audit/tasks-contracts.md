# Tasks і FileSystem: чинні рішення

Зведено 2026-10-16 з погоджених кроків після відкату. Великий план T00–T10
відкочений; старі API, 22-test suite та дозволи не відновлювати.
Це конспект рішень, не нова перевірка коду.

## Task і Timer

- Cancel один раз викликає OnCancelRequest після прийняття flag/reason.
  Safe wrapper журналює exception; TaskQueue одразу передає Cancel current child.
- Під час cancellation виконується OnCancelling(readyToStop), не OnRunning/acquire.
  Base ready=TRUE, exception wrapper дає FALSE. Queue просуває running child
  до завершення, тоді дозволяє release parent. CanStop видалений.
- Після прямого завершення cancellation є безумовний вихід, навіть якщо
  OnAfterStop змінив стан через Reset. Загальна reentrancy hooks цим не визначена.
- ResourceManager/ResourceAcquired getters без side effects/exceptions; не додавати
  catches лише для гіпотетичного порушення цього контракту. Підготовка підстану
  перед RUNNING збережена. Start/Execute resource phases — за Core контрактом.
- Release exception — terminal attempt: OriginalStopReason зберігається,
  Final стає FAILURE, автоматичного retry немає. Це не гарантія фізичного
  звільнення ресурсу. File close має окрему best-effort політику нижче.
- OnStopped/safeCallOnStopped видалені. Execute скидає StateChanged та просуває
  RUNNING. StateChanged живе до наступного Execute, не глобально один PLC cycle.
- Timer.Triggered derived із stopped/stateChanged/WorkDone/TON.Q, без власного flag.
  Додатний відлік починається в OnBeforeStart, а завершення виявляє Execute.
- Restart preparation: Cancel і один Execute, якщо ще RUNNING — FALSE; інакше Reset.
  SetIntervalAndRestart змінює interval лише після підготовки; якщо потім Start
  відмовить, interval уже змінений. Жодного blocking wait. Виклики з owner-коду,
  не рекурсивно з callbacks. Нащадки зберігають timer init/reset через SUPER.
- Zero interval завершується наступним Execute без Elapsed/Triggered.
  Компенсація періодичного дрейфу не додана.

## TaskQueue

- Результат child оцінюється за FinalStopReason. Відмова Start або неочікуваний
  READY current дає ERROR з повідомленням, не успішне вилучення.
- Reset після зупинки очищує список і current, не видаляє й не Reset-ить children.
  Для повтору caller сам готує та додає їх. READY Reset — no-op; RUNNING Reset
  відхиляється. Старе рішення «повторити залишок» скасоване.
- ClearWaitingTasks зберігає тільки фактичну current при RUNNING; без current
  або поза RUNNING очищує весь список/current. Зворотний цикл BY -1, DINT.
- Enqueue потребує READY child, без duplicates; caller забезпечує borrowed
  lifetime, queue керує lifecycle до вилучення. PendingTaskCount включає current.

## FileSystem

- FileContentManager володіє handle, children позичають його. Close best-effort:
  помилка журналюється, але не замінює результат основної операції на FAILURE.
- Сім file-content operations при cancellation просувають pending FB із
  bExecute=FALSE до NOT bBusy; не запускають новий I/O. Parent чекає child.
- FileContentManager також чекає pending open через FinishPendingAcquire.
  Пізній успішний handle позначається acquired і проходить release.
  Standalone caller manager сам забезпечує цей порядок.
  ADS timeout не гарантує фізичного скасування на сервері.
- SetFileHandleResource дозволяє призначити/замінити/очистити binding у READY.
  RUNNING/STOPPED відхиляються; STOPPED спочатку Reset. Caller має вилучити
  waiting child з попередньої queue, READY не є перевіркою membership.
- Open, child I/O та close використовують AmsNetId ресурсу. Child налаштування
  перезаписується перед I/O; manager config стала від Start до STOPPED.
  Remote→local reuse має перезаписати стару адресу.
- WriteBytes completion порівнює cbWrite і cbWriteLen. Short write без bError
  дає ERROR/FAILURE із двома розмірами; автоматичного дописування/rollback немає.
  Cancellation зберігає EXTERNAL_CANCEL, очікуючи завершення.
- Локальні builders перед Throw явно Clear(TRUE) після копіювання повідомлення.
  Для OpenMissingFileForReading та WriteToFileOpenedForReading власник підтвердив
  виправлення історичного витоку OF-008. Це не перевірка всіх throw paths.

Порядок ручного запуску чинних тестів: [task-tests](task-tests-2026-10-05.md).
Невирішені межі й перевірки: [findings](findings.md), [validation](validation.md).
