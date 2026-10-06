# Повторний review актуального Task — 2026-10-04

Уточнення після цього review: за погодженням власника TRY/CATCH у Start
прибрано, порядок resource check перед RUNNING збережено. Ресурсні getters
мають non-throwing контракт; C1 є умовним сценарієм порушення цього контракту.
Нижче збережено snapshot review до цього уточнення.

Scope: поточне робоче дерево після поступових погоджених змін. Код не змінено.
Це статичне читання, не ST compilation і не runtime verification. Старі T00–T10
матеріали не використовуються як специфікація поточного Task.

Детально перечитано Task та ITask, TaskState/TaskRunningSubstate/TaskStopReason,
IResourceManager, TaskQueue cancellation/process/reset callbacks, Timer callbacks,
CounterTask.OnRunning, TaskSequenceTest.TestSequence, callbacks CheckDirectoryExists
і CreateDirectoryIfNotExists, FileContentTask.OnReset, LogManager.TryLogMessage та
TryLogException. Нащадки й overrides у Sources також знайдено через rg; це не
повний аудит всіх FileSystem/Loggers/Workflow implementations.

## Поточні звичайні шляхи

- Start перевіряє manager/getter до RUNNING і відмовляє при exception.
- Cancellation виконує OnCancelling до readyToStop, не запускаючи OnRunning.
- Parent queue чекає завершення running current child при зовнішньому cancel.
- Після прямого STOPPED cancellation branch має RETURN.
- Release exception зберігає Original і встановлює Final=FAILURE.
- Stop callbacks мають logging. Terminal release exception відповідає
  підтвердженому власником контракту, повторно дефектом не позначається.

Ці шляхи зіставлено статично; загальна коректність runtime не доведена.

## C1 — ResourceAcquired exception під час cancellation губить request

Упевненість: висока щодо control flow; сценарій умовний, потрібен throwing getter.
Поточний FileHandleResourceManager.ResourceAcquired читає BOOL; відтворення
цього сценарію на ньому не встановлено.

Task:203 скидає _CancelRequested перед Task:212 ReleaseResourceRequired.
Getter Task:443 повторно читає ResourceManager і ResourceAcquired; cancellation
branch не має __TRY навколо цього getter. Exception виходить із Execute, залишаючи
RUNNING/PROCESSING із flag=FALSE. Наступний Execute може викликати OnRunning
і замінити EXTERNAL_CANCEL результатом роботи. Прийнятий cancel втрачено.

Напрямок окремого виправлення: визначити політику для exception перевірки cleanup;
не скидати request до визначеного переходу, захистити getter. Саме переміщення
flag не вирішує питання повторюваного exception та final outcome.

Пов'язаний шлях: після OnRunning result=ABORTED Task:263 getter кидає exception;
catch не замінює Original=INTERNAL_ABORT. Якщо повторна перевірка Task:282 вже
поверне FALSE, Task:287 завершує з Final=INTERNAL_ABORT, а exception перевірки
не стає final FAILURE. Для DONE той самий getter exception також може спричинити
повторний OnBeforeStop через загальний catch. Це наслідки широкої області __TRY
і повторної перевірки в catch, не підтверджений дефект конкретного manager.

## C2 — Повторний lifecycle виклик із callback не має контракту

Упевненість: висока щодо умовного шляху; використання не знайдено в прочитаних
нащадках, допустимість має визначити власник.

При cancellation без resource OnAfterStop може викликати Reset тієї самої Task.
Reset законно бачить STOPPED і встановлює READY/PROCESSING. Task:222 перевіряє
тільки STOPPED, тому поточний handleRunning продовжить PROCESSING і викличе
OnRunning (Task:256), хоча стан уже READY. Виклик Start з OnBeforeStart або
Execute з OnRunning також може створити рекурсію до завершення outer call.

Напрямок: окремо визначити допустимість same-instance lifecycle calls із hooks
і синхронних listeners. Мінімально для першого сценарію потрібен RETURN після
завершення поточного run незалежно від змін, зроблених OnAfterStop; це не замінює
загального контракту reentrancy. Не вводити guards і заборони без обговорення.

## C3 — Exception діагностики може перервати safe wrapper

Упевненість: висока щодо відсутності захисту; throwing logger/filter — умовний
сценарій, runtime відтворення та дефект конкретного logger не встановлені.

Task wrappers викликають TryLogException усередині catch без додаткового захисту.
LogManager.TryLogException викликає Filter.ShouldLog та Logger.TryLogException
без __TRY; TryLogMessage аналогічно делегує filter/logger. Назва Try сама по
собі не перехоплює exception. Якщо діагностика кине exception, wrapper може
перервати cleanup; transition logging у setIdleState/setStoppedState також
може завадити переходу. Start захищає власний transition, але не решту lifecycle.

Напрямок: перевірити й закріпити non-throwing контракт TryLog або окремо захистити
діагностику. Це перетинається з Core logging, тому не змінювати його автоматично
під час малих правок Task.

## Спрощення без доказу behavioral defect

- Task.OnStopped більше не має override серед знайдених нащадків Task;
  Timer уже обходиться без нього. Можна обговорити вилучення hook і wrapper.
- safeCallOnStopped має BOOL result, який ніколи не встановлює і не використовує.
- Cancel містить невикористані tmpResourceManager, exceptionCode та exception.
- ResourceManager повторно читається в acquire/release/check. Stable manager
  уже передбачений контрактом; кешування на весь run — опціональне спрощення,
  а не вимога для коректного getter.
- Відсутність timeout при BUSY/readyToStop=FALSE/ResourceAcquired=TRUE — властивість
  кооперативної моделі, не самостійний дефект. Timeout не додавався.
- StateChanged — до наступного Execute, а не глобально один PLC cycle.
  Live views і terminal best-effort cleanup залишаються погодженими контрактами.

## Порядок наступних маленьких кроків

1. Обговорити C1 і конкретну політику exceptions у cleanup check; після погодження
   внести один локальний крок та перевірити throwing-getter сценарії вручну.
2. Визначити C2: дозволені виклики lifecycle з callbacks; не починати великий
   redesign stopping callbacks або повернення T00–T10.
3. Окремо узгодити C3 з контрактом logging.
4. За бажанням прибрати невикористані hooks/variables.

TaskQueue.Original/Final, child.Start refusal і Reset/current залишаються окремим
scope. Нове повідомлення findings не доводить runtime defect; кожен C1–C3 ще
потребує уточнення допустимого usage та ручного відтворення.
