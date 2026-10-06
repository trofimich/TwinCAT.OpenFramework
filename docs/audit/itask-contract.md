# Контракт ITask: lifecycle, завершення та володіння

2026-10-02. Опис внесеної реалізації T01–T09. Звірено зі sources статично;
ST compilation та runtime verification після змін не виконано. Журнал:
[itask-execution-journal.md](itask-execution-journal.md).

## Lifecycle

ITask — кооперативна операція, яку просуває один власник через Execute.
Finite task завершується сама; persistent task може законно залишатися
RUNNING без pending work до запиту зупинки. Стани READY / RUNNING / STOPPED.

| Операція | READY | RUNNING | STOPPED |
|---|---|---|---|
| Start | OnBeforeStart; при успіху RUNNING і snapshot ResourceManager | FALSE з refuseReason | FALSE, потрібен Reset |
| Execute | Без роботи | Acquire/process або stop/cleanup крок | OnStopped |
| Cancel | FALSE | Перший запит TRUE; якщо вже StopRequested — FALSE | FALSE |
| Reset | TRUE без callbacks | FALSE | OnReset; при успіху READY |

TRUE Start/Cancel означає прийняття запиту. Start не просуває acquire/processing.
Після Cancel потрібні регулярні Execute до STOPPED. Reset не скасовує активну
задачу. Exception OnBeforeStart/OnReset означає відмову; стан не змінюється.
Відповідальність збереження lifetime усіх borrowed inputs належить caller.

## Єдиний stop protocol

Done, abort, processing/acquire exception і external cancel входять у requestStop.
Перший запит фіксує original reason/message і одноразово викликає OnStopRequested.
Нових OnRunning після запиту немає. OnStopping просуває завершення children;
CanStop відкладає власний cleanup. Після дозволу OnBeforeStop викликається один
раз, потім ResourceManager.ReleaseResource циклічно до completion. За відсутності
manager можна завершитися одразу. Встановлення STOPPED передує OnAfterStop.

| Подія | OriginalStopReason | FinalStopReason після STOPPED |
|---|---|---|
| Done | WORK_DONE | WORK_DONE |
| Abort | INTERNAL_ABORT | INTERNAL_ABORT |
| Accepted Cancel | EXTERNAL_CANCEL | EXTERNAL_CANCEL |
| Processing/acquire exception або ERROR | FAILURE | FAILURE |
| Exception завершення після stop request | Зберігається | FAILURE |
| Best-effort close error, manager не кидає exception | Зберігається | Зберігається; error у логах |

До запиту завершення initial WORK_DONE не означає завершеної роботи.
До STOPPED final result не є остаточним. Результат стабільний після завершення
OnAfterStop до Reset. Exception OnStopped журналюється без зміни результату.
Cleanup failure зберігається окремо; перша його exception журналюється, щоб
повторне очікування release не створювало однаковий запис кожний цикл.

Release exception сама по собі не доводить завершення cleanup: Task залишається
RUNNING і повторює release. Manager має відновитися або завершити відповідальність
за власною політикою. Queue читає FinalStopReason child; успішна основна робота
з failure завершення child не втрачається як нібито успішний queue item.

## STOPPED та callbacks

STOPPED означає: більше не потрібні Execute для роботи/cleanup цієї задачі чи
її children за їх контрактом. Це не гарантія фізичного close, відхиленого системою
при дозволеній best-effort політиці manager. Runtime підтвердження ще потрібне.

| Callback | Момент і кратність за run |
|---|---|
| OnBeforeStart | Один на спробу Start у READY |
| OnRunning | Циклічно у PROCESSING, доки stop не запитано |
| OnStopRequested | Раз для першого stop request будь-якої причини |
| OnCancelRequested | Раз для accepted external Cancel, після generic request callback |
| OnStopping | Циклічно під час очікування дозволу CanStop |
| OnCancelling | Base OnStopping викликає для external cancel; queue викликає base hook |
| CanStop | Повторна перевірка перед власним cleanup; без побічних дій |
| OnBeforeStop | Раз після CanStop=true, перед власним release |
| OnAfterStop | Раз після встановлення STOPPED |
| OnStopped | Кожний наступний Execute у STOPPED; потрібний Timer.Triggered |
| OnReset | Один на спробу Reset у STOPPED |

Винятки stop callbacks журналюються і записують cleanup failure. CanStop exception
не дозволяє обійти children: очікування триває. OnBeforeStop exception не заважає
спробі release. Reentrant Start/Execute/Cancel/Reset із callbacks тієї ж задачі
не підтримується; owner приймає та виконує lifecycle запити поза callback.

## Execution і queue ownership

Один екземпляр має одного власника lifecycle: scheduler або parent queue.
Доступ з кількох PLC tasks і thread safety не гарантуються. Execute викликають
один раз за цикл owner; test scheduler може явно виконувати дискретні кроки.
StateChanged скидається на початку Execute, не автоматично на глобальній межі scan.

Queue зберігає borrowed references, не клонує й не видаляє child. Child і її buffers
мають існувати до завершення всіх звернень, включно з cleanup/Reset pending list.
Після успішного вилучення child повторний enqueue потребує її Reset самим caller.

| Queue operation | Реалізований контракт |
|---|---|
| Enqueue null/self/duplicate | Виняток; duplicate порівнюється за SelfAddress |
| Enqueue RUNNING/STOPPED child | Виняток; потрібна READY child |
| Enqueue у READY/normal RUNNING queue | Дозволено |
| Enqueue у stopping/STOPPED queue | Виняток; після STOPPED потрібен Reset |
| Clear RUNNING | Виняток; спочатку завершити lifecycle |
| Clear READY/STOPPED | Очищає borrowed list і current reference |
| Child.Start refusal | Failure queue; child лишається у списку |
| Reset | Child.Reset refusal поширюється; queue лишається STOPPED |
| Child.FinalStopReason != WORK_DONE | Відповідний queue stop; failed child лишається для review/reset |

Reset списку не є транзакцією: попередні успішні child.Reset не відкатуються
при відмові наступної child; повторна спроба дозволена. Одна child у різних
queues і непрямі цикли композиції — заборонене ownership порушення; global
registry не створювався, локальна перевірка не виявляє всіх таких сценаріїв.

## Resource ownership і pending operations

ResourceManager означає, що задача керує lifecycle ресурсу, включно з pre-acquired
resource. На Start захоплюється reference manager; під час run його не підміняють.
Borrowed ресурс передається окремо, як file handle для FileContentTask.
Manager/backing fields мають стабільний lifetime до завершення звернень/reset.

AcquireResource просувається до ResourceAcquired=true; до цього processing немає.
Stop під час acquire також викликає ReleaseResource, навіть якщо ресурс ще не
acquired. Це дозволяє завершити/нейтралізувати pending operation.

Optional TOF_Core.IResourceCleanupStatus.CleanupComplete описує завершення
pending роботи manager. Task перевіряє одночасно NOT ResourceAcquired і
CleanupComplete, якщо цей interface підтримується. Legacy manager без interface
мусить гарантувати, що ResourceAcquired=false після release означає відсутність
pending операції, здатної створити ресурс або потребувати подальших calls.

FileHandleResourceManager відстежує pending open, просуває вже розпочатий FB_FileOpen
із bExecute=TRUE до completion; якщо отримано handle, починає close. Звичайне close
зберігає best-effort policy власника. Реальні ADS outputs, late open і recovery
мають бути перевірені вручну — fake tests не підтверджують поведінку системного FB.

Queue утримує parent resource до виходу current child із RUNNING, для усіх причин
stop. Pending READY children під час завершення не стартують. Якщо child не
завершується, parent resource не звільняється лише через elapsed timeout.

## Public observation

CancellationRequested — accepted external cancel протягом очікування child і
release. FALSE при STOPPED та Reset; internal stop не встановлює ознаку.
ITaskState і ITaskStopReason — read-only live views, незалежні від concrete Task.
Reader може скопіювати enum/message для snapshot. Views/backing fields мають
існувати довше за читача; reference до Message не є власною копією рядка.

ITaskResourceDiagnostics відділяє ResourceManager та ITaskRunningSubstate від
мінімального ITask. Concrete Task зберігає ці getters; independent adapter
може не мати ресурсів і не реалізовувати diagnostic interface.

## T09: прогрес, timeout і recovery

Execute та всі hooks мають робити обмежений обсяг роботи й повертатися owner.
Тривалість операції у багатьох циклах не дорівнює часу одного Execute. WCET не
вимірювався й не гарантується; розмір pending list впливає на Enqueue/Reset.

Timeout обирає конкретна задача/resource manager. File manager уже має Timeout
для системних FB. Спостерігач може фіксувати зависання за elapsed time, фазою та
симптомами конкретної операції; Task не має універсального progress percentage.
Глобальний довільний timeout чи forced stop не додані. Запис timeout не дозволяє
встановити STOPPED/звільнити parent, поки child використовує resource. Recovery
передбачає продовження Execute і відновлення manager або явний спеціалізований
контракт аварійного завершення. Fake hang/recovery test написано, не виконано.
