# Перевірки та обмеження

Зведено 2026-10-16. Власник запускає перевірки сам. Під час цього прибирання
не запускали compilation, runtime/TcUnit, XML validation, check-скрипти чи DocGen.
Історичні structural PASS не означають ST compilation і не підтверджують нові edits.
Ранні MSBuild/XAE спроби не встановили успішної ST compilation; старі reports видалені.

## Потрібні сценарії для відповідних змін

- Resolution поточних sources у залежних бібліотеках; після перечитування IDE
  Core лишається Referenced Library (дужки відновлені у 13 projects).
- ObjectLifetimeTest: static release відхилений без FB_exit; dynamic descendant
  cleanup через Object pointer; null та різні interface addresses. Probe не є
  валідатором lifetime — не перевіряти його через небезпечний dangling call.
- Enumeration: повторні MoveNext/Reset, порожній Current, lifetime source/cursor,
  явне видалення cursor; long/multichar wide fragments у окремому review.
- ResourceManager: idle Execute, open/work/close, failure, cancellation до Execute
  і під час busy open, пізній handle, reuse після Reset, best-effort close failure.
- System: дві задачі різних періодів, незалежні readiness/intervals/timestamps;
  non-cyclic defaults, dynamic FB_init у task; milliseconds 0/5/50/99/100/999;
  error після невдалого/успішного GetTaskCycleTime, великий cycle time.
- Exceptions: Clone identity/тип/metadata/time, nested Throw/ReThrow, Aggregate
  empty/255/256, Clear/Clone lifetime, direct/indirect cycle rejection до mutation,
  shared read-only causes, ToError з агрегату.
- Multitask: task A payload не змінюється cleanup task B; wrappers незалежні;
  missed cleanup очищує лише попередній цикл своєї task та збільшує її counter
  один раз, counter насичується; releaseBuffer і shutdown без double delete.
  Task array bounds із generated _TaskInfo та FB_IecCriticalSection потрібні
  на фактичному target. Не заявляти online change перевіреним.
- Fatal allocation: ізольований target, latch до raise, повторний raise на boundary,
  без heap exception і без lock під час catch; після тесту переініціалізація.
  Це стосується також 256-го aggregate entry; не запускати як recoverable testcase.
- Strings/builders: порожній, exact-fit включно з terminator, >255, self-append,
  allocation failure зі збереженням старого buffer; message2000/truncation/ellipsis,
  value255/truncation; pointer hex width і підтримані ANY values.
- Actions: denial reason/empty fallback, перша відмова ancestors, success не
  очищує reason. Events: root/leaf по одному callback, Handled/stopPropagation,
  sibling branches, exceptions та disabled/stopped recipients.
- Logging: aggregate singleton/multiple, messageNumber/category/text/ellipsis;
  TRUE file logger означає enqueue, не запис на диск. Actual readback окремий.
- Tasks/Timer/FileSystem: [налаштування і сценарії тестів](task-tests-2026-10-05.md).
- DocGen output та MIT notices — перевірка власником у його конфігурації.

## Наявні підтвердження

Власник раніше підтверджував роботу Object/memory і конкретні OF-008 сценарії
OpenMissingFileForReading та WriteToFileOpenedForReading після Clear(TRUE).
Це історичні результати конкретних редакцій, не blanket PASS поточного дерева.
Native mismatch на 3.1.4026.27 повідомлений власником; нового відтворення немає.

Новий результат записувати тут коротко: дата, revision/local changes, TwinCAT і
library resolution, target/task periods, сценарій та фактичний результат.
