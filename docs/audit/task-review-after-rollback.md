# Task: review після відкату

2026-10-02. Джерело висновків — поточні files, не попередня реалізація T00–T10.
Власник відкотив масові зміни й обрав поступові спільні покращення. PLC-код у цьому
review не змінювався. Збірка та runtime тести не запускалися; сценарії нижче —
статичні шляхи виконання, а не результати відтворення на PLC.

Детально прочитано Task, ITask, TaskQueue/StandardTaskQueue, три status wrappers,
IResourceManager, FileHandleResourceManager, FileContentManager/FileContentTask,
Timer, CounterTask, TaskSequenceTest; зіставлено directory-task callbacks і
callers logger. Решта descendants оглянута через declarations/callback searches.

## R1 — StateChanged reference не прив'язана

Упевненість: висока. [TaskState:44](../../Sources/TwinCAT.OpenFramework.Tasks/Task/SubObjects/TaskState.TcPOU#L44):

```iecst
_TaskState REF= taskState;
_TaskStateChanged := taskStateChanged;
```

Другий рядок копіює BOOL через reference, не прив'язує reference. Для нового
екземпляра `_TaskStateChanged` ще не прив'язана; це доступ через невалідну
reference вже у FB_Init. Точна runtime реакція залежить від перевірки pointers,
але reference assignment тут однозначно неправильний. Потрібно REF=.
Семантика звірена з [Beckhoff REFERENCE](https://infosys.beckhoff.com/content/1033/tc3_plc_intro/2529458827.html).

Малий наступний крок: один рядок; перевірка StateChanged після Start/Execute/Reset.
Саме відділення wrappers від concrete Task у поточній правці збережено коректно
для інших references; повертати interface redesign для цього не потрібно.

## R2 — OnRunning після STOPPED у тому самому Execute

Упевненість: висока. [Task:206](../../Sources/TwinCAT.OpenFramework.Tasks/Task/Task.TcPOU#L206)
встановлює STOPPED у cancellation без ресурсу. Після OnAfterStop немає RETURN;
виконання доходить до [Task:213](../../Sources/TwinCAT.OpenFramework.Tasks/Task/Task.TcPOU#L213)
і [Task:243](../../Sources/TwinCAT.OpenFramework.Tasks/Task/Task.TcPOU#L243), бо substate
лишився PROCESSING.

Сценарій на existing CounterTask: TargetValue=1 → Start → Cancel → Execute.
Після встановлення STOPPED ще виконується increment counter; DONE перезаписує
EXTERNAL_CANCEL на WORK_DONE і повторно викликає stop callbacks. Для queue,
скасованої до першого Execute, цей самий шлях може стартувати pending child
після зупинки parent.

Малий наступний крок: закрити fall-through; один regression scenario без ресурсів.

## R3 — Circular wait під час cancellation активної queue

Упевненість: висока для child, яка без Cancel не завершується.
[Task:193](../../Sources/TwinCAT.OpenFramework.Tasks/Task/Task.TcPOU#L193) викликає
OnBeforeStop тільки після CanStop=true. [TaskQueue:42](../../Sources/TwinCAT.OpenFramework.Tasks/TaskQueue/TaskQueue.TcPOU#L42)
дає FALSE, поки child RUNNING. А child.Cancel викликається тільки з
[TaskQueue.OnBeforeStop:93](../../Sources/TwinCAT.OpenFramework.Tasks/TaskQueue/TaskQueue.TcPOU#L93).

Parent.Cancel → child RUNNING → CanStop=false → OnBeforeStop не викликається →
child.Cancel не надходить. Parent продовжує звичайний OnRunning, child продовжує
роботу. Якщо child indefinite, cancellation не завершується. Якщо finite child
завершиться сама, parent поки чекає може запускати наступні pending children;
DONE/ABORTED/ERROR звичайного OnRunning може також замінити прийняту cancel reason.

Наступний крок після R2: окремо визначити передачу cancel і просування тільки
active child. Не поєднувати це зі зміною всього API або всіх stop paths.

## R4 — Reset queue пропускає збережену current child

Упевненість: висока за сценарію child failure/abort, коли queue зупинилась і
child лишилась у pending list. [TaskQueue.OnReset:105](../../Sources/TwinCAT.OpenFramework.Tasks/TaskQueue/TaskQueue.TcPOU#L105)
скидає children, але не скидає `_CurrentTask`.

Child ABORTED → queue STOPPED → queue.Reset: child READY, `_CurrentTask` усе ще
вказує на неї → queue.Start → OnRunning викликає child.Execute без Start
([120–126](../../Sources/TwinCAT.OpenFramework.Tasks/TaskQueue/TaskQueue.TcPOU#L120)) →
READY branch видаляє child ([134](../../Sources/TwinCAT.OpenFramework.Tasks/TaskQueue/TaskQueue.TcPOU#L134)).
Отже, після Reset робота пропускається. Окремо BOOL child.Reset ігнорується:
queue може прийняти Reset при відмові child.

Спочатку погодити бажаний зміст queue.Reset: повторити збережені tasks чи тільки
підготувати порожню queue. Потім локально узгодити list/current і refusal handling.

## R5 — Child.Start refusal виглядає як успішне вилучення

Упевненість: висока. [TaskQueue:126](../../Sources/TwinCAT.OpenFramework.Tasks/TaskQueue/TaskQueue.TcPOU#L126)
ігнорує BOOL Start. Якщо OnBeforeStart child кидає exception, Task.Start повертає
FALSE, child лишається READY; branch READY у рядку 134 вилучає її зі списку.
Причина відмови не поширюється. Finite queue з єдиною такою child згодом може
завершитися WORK_DONE, хоча child взагалі не починала роботу.

Малий наступний крок: один тест із child, яка відмовляє Start, і явна обробка FALSE.

## R6 — Clear розриває зв'язок list і current

Упевненість: висока для використання Clear з active/current child; допустимість
такого виклику потребує явного контракту. [TaskQueue:49](../../Sources/TwinCAT.OpenFramework.Tasks/TaskQueue/TaskQueue.TcPOU#L49)
очищає тільки list. `_CurrentTask` продовжує виконуватися.

Сценарій: A running → queue.Clear → enqueue B → A завершується →
[removeCurrentTask:161](../../Sources/TwinCAT.OpenFramework.Tasks/TaskQueue/TaskQueue.TcPOU#L161)
видаляє перший item нового list, тобто B, яка не починалася. Подібна неузгодженість
можлива після Clear зупиненої queue, що зберегла failed current child.

Наступний крок: визначити дозволені стани Clear і узгодити current/list. Не
додавати silent cancellation або видалення borrowed objects.

## Питання другого порядку — окреме обговорення

1. **Enqueue contract.** Перевіряється тільки null. Duplicate/self/non-ready child
   не відхиляються. Self enqueue може привести до recursive Execute; duplicate
   може бути вилучений без повторного Start. Це захист від неправильного usage;
   спершу визначити допустимий контракт, не впроваджувати всі guards автоматично.
2. **Callback exceptions.** Task safeCallOnBeforeStop (453–456) і
   safeCallOnAfterStop (424–427) мовчки ковтають exceptions. Відсутність
   діагностики підтверджена; чи міняти final result — окреме рішення. Мінімальний
   варіант: logging без зміни lifecycle.
3. **Release exception.** Task:296 встановлює STOPPED без підтвердження, що
   ресурс звільнено. Для generic throwing manager це потребує контракту; не
   стверджуємо, що FileHandleResourceManager має таку помилку. File close
   best-effort policy власника лишається допустимою.
4. **Original/Final у queue.** Queue:138–142 читає Original, не Final. Якщо child
   original=EXTERNAL_CANCEL, а release exception дала final=FAILURE, queue побачить
   abort і приховає failure як результат композиції. Умовний generic сценарій;
   actual file-close logging цього сценарію не створює.
5. **Cancel pending file open.** FileHandleResourceManager.ReleaseResource повертає
   при ResourceAcquired=false після скидання open.bExecute. Чи достатньо цього
   для pending ADS operation — ручна перевірка, не підтверджений витік. Новий
   resource interface для цього review не пропонуємо як обов'язкове виправлення.
6. **Timer contract.** Restart у RUNNING повертає FALSE через Reset/Start refusal.
   SetIntervalAndRestart (164–168) при цьому все одно змінює PT. Чи дозволена
   зміна interval при невдалому restart — окреме уточнення поведінки.

## Порядок маленьких змін

R1 → R2 → R3 → R4 → R5 → R6. Кожна зміна окремо, з одним зрозумілим regression
scenario і review власником перед наступною реалізацією. API/status interfaces,
global timeout, новий stop protocol і повернення попереднього T00–T10 scope
не є частиною поточного доручення.

## Окремий крок OnCancelRequest — 2026-10-04

За погодженням власника додано protected Task.OnCancelRequest, safe wrapper з
logging та один виклик у Cancel після прийняття flag/reason. TaskQueue override
передає cancel активній child одразу; existing OnBeforeStop збережено для інших
причин stop. Початкове circular wait R3 тепер має передачу cancel, але звичайний
OnRunning під час очікування, можливість запуску pending children і перезапис
parent reason ще потребують наступного окремого review. HandleRunning не змінено.
R2 та решта висновків не позначаються виправленими цим кроком.

Перевірено XML, унікальність нових IDs, збереження existing IDs/declarations і
existing method implementations: змінено тільки вставку callback у Cancel;
додано три методи. Compiler/runtime не запускалися. Ручні checks: accepted
Cancel викликає hook раз; repeated/refused Cancel не викликає hook; callback
exception логується і зберігає accepted request; queue передає Cancel current child.

## Окремий крок OnCancelling і Timer.Triggered — 2026-10-04

За уточненим запитом власника додано саме циклічний OnCancelling, а не
одноразовий OnCancelled. Task викликає protected hook через safe wrapper з
exception logging перед перевіркою CanStop. Якщо CanStop=false, Execute
повертається без OnRunning і без просування acquire/process. Коли CanStop=true,
залишається existing OnBeforeStop → release → OnAfterStop. Після STOPPED додано
RETURN, щоб у цьому самому Execute не викликався OnRunning.

TaskQueue.OnCancelling виконує тільки running current child; не запускає pending
children, не видаляє current і не переносить child stop reason у parent. Після
завершення child CanStop дозволяє release ресурсу parent у тому самому Execute.
Callback exception журналюється; після нього CanStop усе одно перевіряється.
Це не гарантія завершення cancellation при помилці в реалізації нащадка.

R2 і cancellation wait частина R3 виправлені за статичним аналізом поточного
коду. Інші шляхи завершення, Reset/current, відмова child.Start та інші findings
не включені в цю зміну. Public ITask і базовий OnStopped залишені без змін.

У Timer прибрано _Triggered, previousQ і override OnStopped. Triggered тепер
обчислюється як State.Stopped AND_THEN State.StateChanged AND_THEN
FinalStopReason.WorkDone AND_THEN _Timer.Q. Сигнал діє до наступного Execute;
читання не споживає його. Нульовий interval зберігає завершення без Triggered.

Перевірено XML parsing, унікальність IDs у Task/TaskQueue, збереження existing
IDs та незмінених методів; статично перевірено guards і відсутність Start/list
операцій у Queue.OnCancelling. Diff check Task/Timer пройшов; загальний check
Queue також показує попередній trailing whitespace у ClearWaitingTasks, який
не змінювався цим кроком. ST compilation і runtime НЕ виконано.

Ручна перевірка: cancel під час PROCESSING без resource не викликає OnRunning;
child із release на кілька циклів завершує cleanup до release parent; наступний
child не стартує; parent зберігає EXTERNAL_CANCEL; OnCancelling не викликається
після початку release; callback exception журналюється. Окремо для Timer:
Triggered=true після завершення, false після наступного Execute та Reset;
повторний запуск і нульовий interval.
## Спрощення OnCancelling.readyToStop — 2026-10-04

За погодженням власника окремі Task.CanStop і TaskQueue.CanStop видалено.
Task.OnCancelling та override TaskQueue.OnCancelling мають VAR_OUTPUT
readyToStop : BOOL. Базова реалізація встановлює TRUE; Queue виконує тільки
running current child і після Execute встановлює результат за її поточним станом.
FALSE означає очікування наступного Execute без OnRunning/acquire; TRUE означає
готовність викликати OnBeforeStop і почати release parent, а не стан STOPPED.

safeCallOnCancelling передає output у handleRunning. На початку wrapper і в
catch readyToStop явно встановлюється FALSE; exception журналюється та не
дозволяє release у цьому виклику. Це замінює попередню поведінку з незалежною
перевіркою CanStop після exception. При повторюваному exception очікування
може тривати без завершення; автоматичного обходу readiness немає.

Оновлено коментарі OnCancelling, OnBeforeStop і Queue.OnCancelRequest.
Existing IDs збережено, крім навмисно видалених CanStop properties/getters;
непов'язані методи та public ITask не змінено. XML, сигнатури, унікальність IDs,
відсутність CanStop у Tasks і readiness guards перевірено статично. Diff check
Task пройшов; попередній Queue whitespace залишається. ST compilation/runtime
не виконано. Ручні сценарії попереднього кроку актуальні; для exception тепер
очікується readyToStop=FALSE і відсутність parent release у цьому Execute.
## Логування stop callbacks — 2026-10-04

За окремим дорученням власника safeCallOnBeforeStop і safeCallOnAfterStop тепер
перехоплюють exceptionCode, отримують IException через ExceptionManager і
викликають LogManager.TryLogException із severity ERROR, ClassName та назвою
wrapper. Stop reasons і порядок завершення не змінено. Коментарі hooks оновлено.
Відсутність logging у цих двох wrappers виправлена за статичним review.
Перевірено XML, existing IDs, незмінність інших методів, наявність logging і
відсутність присвоєнь stop reasons у wrappers; diff check пройшов.
ST compilation і runtime НЕ виконано. Ручна перевірка: окремо кинути exception
з кожного hook, перевірити ERROR log і збереження очікуваного lifecycle/result.
## Збереження OriginalStopReason при release exception — 2026-10-04

Власник погодив розділення причин: Original описує причину початку завершення,
Final — результат після cleanup. Із catch гілки RESOURCE_RELEASING прибрано
перезапис OriginalStopReason=WORK_DONE на FAILURE та original message.
Final лишається FAILURE з повідомленням release exception. Без release exception
Final отримує Original. Best-effort file close policy не змінено.

Коментарі OriginalStopReason у Task та ITask актуалізовано. Acquire/processing,
TaskQueue й інші методи не змінено. Queue поки читає child.OriginalStopReason:
child Original=WORK_DONE, Final=FAILURE може бути сприйнята як успішна;
зміна оцінки child у Queue залишена для наступного окремого обговорення
відповідно до запропонованого обсягу цього кроку.

Перевірено XML, existing IDs, точні межі змін у release branch, незмінність
інших methods і наявність final FAILURE без присвоєнь original reason/message.
Diff check пройшов. ST compilation/runtime НЕ виконано.
Ручні сценарії: успішна робота + throwing release → WORK_DONE/FAILURE;
cancel + throwing release → EXTERNAL_CANCEL/FAILURE;
processing error + successful release → FAILURE/FAILURE; перевірити обидва
повідомлення й те, що best-effort file close не змінює результат операції.
## Уточнення власника: terminal release exception — 2026-10-04

Власник підтвердив початковий задум: exception із ReleaseResource завершує
спробу cleanup цієї Task; задача переходить у STOPPED із FinalStopReason=FAILURE,
без автоматичного повтору release. STOPPED означає завершення виконання, а не
гарантію фізичного звільнення ресурсу. Менеджер сам обробляє recoverable errors,
якщо cleanup має продовжуватися, і визначає recovery для resource, який лишився
захопленим після terminal exception. Best-effort file close лишається допустимим.

Питання 3 з останнього обговорення не є дефектом state machine за цим контрактом;
його закрито уточненням документації, а не runtime-відтворенням. Коментарі додано
до IResourceManager.ReleaseResource, Task.ResourceManager і FinalStopReason
у Task/ITask. Логіку не змінено. XML parsing, existing IDs, сигнатури без
коментарів та повну незмінність implementations перевірено. Diff check показав
наявні whitespace-only рядки у wrappers Task, збережені без змін у цьому кроці.
ST compilation/runtime НЕ виконано.
## Захист підготовки Start — 2026-10-04

За окремим погодженням setRunningState спочатку отримує ResourceManager один
раз у локальну змінну й визначає initialRunningSubstate за ResourceAcquired.
Лише після цих getters та existing transition logging ініціалізуються підстан
і stop reasons; RUNNING/StateChanged встановлюються останніми. Start явно починає
з FALSE, перехоплює exception із setRunningState і повертає його message через
refuseReason. Throwing manager lookup/ResourceAcquired лишає lifecycle READY.
OnBeforeStart і його wrapper залишено без змін; його side effects не rollback.

Коментарі Start у Task/ITask актуалізовано. Acquire/release, handleRunning,
TaskQueue та інші existing methods не змінено; existing object IDs збережено.
XML, порядок resource check перед state commit, один lookup manager і відсутність
нових resource operations перевірено статично. Diff check має тільки попередні
whitespace-only рядки у wrappers, не змінені цим кроком. ST compilation/runtime
НЕ виконано. Проблему 4 виправлено за статичним review в межах getter exceptions.

Ручні сценарії: throwing ResourceManager getter; throwing ResourceAcquired
getter — Start=FALSE, message встановлено, READY та попередні substate/reasons
збережено, Execute не запускає роботу. Null manager → PROCESSING; manager із
ResourceAcquired=FALSE → RESOURCE_ACQUIRING; TRUE → PROCESSING; Start=TRUE та
RUNNING тільки після успішної підготовки. Existing OnBeforeStart refusal лишає
READY; його callback side effects не відкочуються.
## Упорядкування Start без зайвого TRY/CATCH — 2026-10-04

За уточненням власника прибрано TRY/CATCH навколо setRunningState та локальні
exception variables у Start. Захист safeCallOnBeforeStart збережено: callback
може відмовити запуску через exception. ResourceManager отримується один раз,
initialRunningSubstate визначається перед зміною lifecycle; stop reasons і
підстан ініціалізуються до фінального встановлення RUNNING. Цей порядок лишено.

Коментарі Start у Task/ITask більше не обіцяють відмову через throwing resource
getters. Task.ResourceManager явно вимагає, щоб ResourceManager/ResourceAcquired
getters лише читали стан і не кидали exception. Попередні throwing-getter
сценарії описують порушення цього контракту, а не необхідність catch у Start.
Не додавали захист logging, не змінювали Core LogManager або resource operations.

XML parsing, existing IDs, незмінність setRunningState та інших methods і
відсутність TRY/CATCH у Start перевірено статично. ST compilation/runtime НЕ
виконано. Історичний запис про захищений Start вище описує попередню версію.
## Мінімальне прибирання Task і прямий вихід після stop — 2026-10-04

За погодженням власника у cancellation branch без resource release додано
RETURN одразу після setStoppedState/OnAfterStop. Навіть якщо OnAfterStop викличе
Reset або Reset/Start, старий Execute більше не продовжить OnRunning. Замість
колишнього IF State=STOPPED вихід визначається завершенням поточного run.
Це виправляє конкретний сценарій C2; загальну підтримку reentrant lifecycle
calls цим не заявлено.

Вилучено невикористані exceptionCode/exception з Cancel, Task.OnStopped і
safeCallOnStopped. Execute скидає StateChanged і виконує handleRunning лише в
RUNNING; виконання в READY/STOPPED не просуває роботу. StateChanged reset лишено,
зокрема для Timer.Triggered. Коментар OnAfterStop оновлено.

Перевірено XML, збереження IDs усіх інших objects, незмінність непов'язаних
методів, прямий RETURN у потрібній гілці й відсутність Task.OnStopped references.
Інший OnStopped у Automation належить незалежній моделі й не змінювався.
Diff check показує попередні whitespace-only рядки у wrappers, залишені як є.
ST compilation/runtime НЕ виконано. Ручні перевірки: cancellation без resource
із OnAfterStop.Reset не викликає OnRunning; звичайне завершення/cancel із resource
зберігають порядок cleanup; Execute у STOPPED скидає StateChanged/Timer.Triggered.
## Timer: запуск без очікування наступного Execute — 2026-10-05

Власник погодив мінімальні зміни, щоб не додавати затримку до початку відліку.
Timer.OnBeforeStart викликає TON(IN := TRUE) для додатного interval синхронно
під час Start. OnRunning надалі оновлює TON і визначає завершення.
Restart та SetIntervalAndRestart використовують приватний prepareRestart:
якщо RUNNING, викликати Cancel і один Execute; якщо досі RUNNING — FALSE;
інакше повернути результат Reset. Cancel може відмовити через вже розпочату
зупинку; вирішальним є стан після Execute. Циклів очікування немає.
Після успішної підготовки Restart викликає Start; SetIntervalAndRestart спершу
записує interval, потім Start. Якщо підготовка відмовила, interval незмінний.
Якщо наступний Start відмовить у нащадка, новий interval залишається налаштованим.
Викликати з owner-коду, не рекурсивно з callbacks задачі.

Після нового Start немає додаткового Execute: завершення фіксується наступним
циклічним Execute. Зокрема Restart із нульовим interval повертає RUNNING, а
наступний Execute завершує задачу без Elapsed/Triggered, як у zero-interval branch.
Triggered formula і OnRunning не змінені. Нащадки, які перевизначають
OnBeforeStart/OnReset, мають зберігати timer initialization/reset через SUPER.
Періодичну компенсацію дрейфу не впроваджено: новий відлік починається з нового
Start, а завершення виявляється під час Execute.

Статично перевірено XML Timer/ITimer, унікальність IDs у цих двох файлах,
Compile entries, порядок Cancel/Execute/Reset/Start, guard запису interval,
відсутність циклу очікування. При початковій правці збереження старих Timer IDs
та незмінність інших members перевірені. Правки оформлення власника збережено.
git diff --check для Timers повідомляє trailing whitespace на порожньому рядку
prepareRestart; це не результат ST compilation. ST/TcUnit/runtime НЕ запускалися.

Ручні перевірки, які залишаються:
- Start додатного interval, відкласти перший Execute: відлік іде від Start.
- Restart у READY, RUNNING, STOPPED і після вже прийнятого Cancel.
- SetIntervalAndRestart у RUNNING: новий повний interval від нового Start.
- Нащадок із затриманим cleanup: FALSE, interval незмінний; завершити cleanup
  через Execute й повторити запит. Перевірити також відмову OnReset.
- Нульовий interval, normal Elapsed, Triggered до наступного Execute/Reset.

Зміни samples не входили в цей крок. Workflow sample з повторним Start без Reset
залишається окремою проблемою використання.
