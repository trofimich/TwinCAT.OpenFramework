> Після відкату власник скасував виконання цього великого плану й обрав поступову
> спільну роботу. Документ збережено як історію попередньої спроби.
> Актуальний review: [Task після відкату](task-review-after-rollback.md).
# План розвитку контракту ITask

Дата: 2026-10-02. Статус: зміни T00–T10 підготовлено; compiler/runtime перевірки залишено власнику.

Мета: зберегти кооперативну модель Tasks і зробити завершення, композицію,
володіння та спостереження за виконанням передбачуваними. Кожний етап — окрема
задача з окремим diff та звітом. Власник явно доручив виконати всі етапи; потім дозволив продовження без автоматичної збірки/runtime з тестами у наявному Tests.

Актуальні результати: [журнал](itask-execution-journal.md), [контракт](itask-contract.md), [ручна перевірка](itask-manual-validation.md).

Нижче збережено початкові задачі та їх критерії. Згаданий blocker не забороняє реалізацію після останнього доручення власника, але не дозволяє називати її runtime-перевіреною.

## Вихідний стан і обмеження

- Поточне погоджене виправлення OF-004 уже внесено в Task і TaskQueue:
  OnCancelRequested передає child.Cancel, OnCancelling просуває child.Execute,
  CanStop відкладає release parent, а RETURN забороняє роботу після STOPPED.
  Воно перевірене статично; ST compilation і runtime regression не виконано.
- Публічні стани залишаються READY / RUNNING / STOPPED. Новий стан чи підстан
  для cancellation не вводимо; внутрішній прапорець відповідає задуму власника.
- FileContentManager володіє handle; FileContentTask його позичає. Best-effort
  close із журналюванням помилки залишається допустимим контрактом; STOPPED
  не є гарантією фізичного закриття за будь-якої системної помилки.
- OF-007 та загальний аудит allocator не входять у цей план.
- Зберігати поточні зміни власника, XML-структуру та IDs існуючих об'єктів.
  Не поєднувати зміни lifecycle з перебудовою public API в одному етапі.
- Попередній MSBuild запуск зупинився до ST compiler через відсутній
  tsproj.metaproj. Наявність XAE не означає перевірену збірку або runtime.

## Порядок виконання

| Етап | Окрема задача | Залежить від | Основний результат |
|---|---|---|---|
| T00 | Встановити перевірюваний baseline Tasks | — | Збірка поточних Tasks і тестовий target або точний запис blocker |
| T01 | Описати контракт lifecycle і результатів | T00 для актуального baseline | Специфікація переходів, відмов і пріоритету причин |
| T02 | Уточнити STOPPED та callbacks завершення | T01 | Однозначна гарантія завершення та callback matrix |
| T03 | Визначити власника виконання й lifetime задач | T01–T02 | Правила scheduler, черг і borrowed references |
| T04 | Визначити володіння та контракт resource manager | T01–T03 | Правила own/borrow і pending acquire/release |
| T05 | Об'єднати всі причини завершення | T01–T04 | Єдиний внутрішній протокол stop без нового стану |
| T06 | Додати спостереження за cancellation | T05 | Read-only CancellationRequested з точним lifetime |
| T07 | Відділити public status від конкретного Task | T01–T02, T05–T06 | ITask, який може реалізувати незалежний adapter |
| T08 | Відділити діагностику ресурсів від основного API | T07 | Мінімальний lifecycle API та окрема діагностика |
| T09 | Визначити прогрес, timeout і поведінку зависання | T04–T06 | Циклічний контракт і політика очікування cleanup |
| T10 | Перевірити інтеграції та приклади | T05–T09 | Перевірка Tasks, Timers, FileSystem, Loggers і callers |

Якщо T00 заблоковано інструментами, можна виконувати документаційні частини
T01–T04. Зміни коду не можна називати перевіреними компілятором або runtime
до усунення blocker. Кожний наступний етап спирається на фактичний статус
попереднього, а не лише на його наявність у таблиці.

## T00 — baseline та засоби перевірки

Звірити поточне дерево, версії бібліотек і resolutions. Встановити спосіб
збірки через доступний XAE та підтвердити, що Tests використовує актуальну
Tasks, а не попередній compiled export. Підготувати ізольований target для
тестів із fake tasks/resource managers без файлових та апаратних операцій.

Перевірити поточний OF-004: child із delayed release; child, що працює до
Cancel; parent із ресурсом і без; вкладення двох черг; Cancel перед першим
Execute; кілька pending children; повторний Cancel. Фіксувати порядок calls.

Вихід: команди/спосіб збірки, compiler diagnostics, результати виконаних тестів
і явно зазначені невиконані перевірки. Не змінювати lifecycle для налаштування
інструментів і не активувати наявний hardware target заради тестів.

## T01 — lifecycle та результати

Описати Start, Execute, Cancel, Reset для кожного стану: допустимість,
побічні дії, BOOL result і refuseReason. TRUE у Start/Cancel означає прийняття
запиту, а не завершення операції. Повторний запуск потребує Reset.

Визначити finite task та persistent task: остання може законно залишатися
RUNNING без pending work до зовнішнього завершення. Визначити момент, коли
OriginalStopReason та FinalStopReason мають зміст, і стабільність результату
після завершення до Reset. Окремо описати пріоритет external cancel, internal
abort, failure під час роботи/завершення та best-effort cleanup diagnostics.

Вихід: документ контракту й transition matrix. Політики, не визначені поточним
кодом або поясненнями власника, позначити як пропозиції; не впроваджувати їх
мовчки як виправлення дефектів. У цьому етапі код не змінювати.

## T02 — гарантія STOPPED і callbacks

Зафіксувати: STOPPED означає завершення роботи й передбаченого контрактом
cleanup; Execute більше не потрібен для завершення цієї задачі або її children.
Це гарантія lifecycle, з урахуванням погодженої політики resource manager.

Описати момент і кратність OnBeforeStart, OnRunning, OnCancelRequested,
OnCancelling, OnBeforeStop, OnAfterStop, OnStopped, OnReset та перевірки CanStop.
OnAfterStop — одноразове повідомлення про завершення; OnStopped — виклик
кожного Execute у STOPPED, потрібний, зокрема, поточному Timer. Визначити
правила винятків і допустимості повторного входу в lifecycle з callbacks.

Вихід: callback matrix для success/cancel/abort/exception. Якщо потрібна
корекція реалізації, внести її окремим diff цього етапу й перевірити кратність
callbacks та відсутність processing після STOPPED. Об'єднання stop paths — T05.

## T03 — власник виконання та lifetime

Закріпити одного власника керування lifecycle екземпляра. Для child у черзі
саме черга викликає Start/Execute/Cancel/Reset; зовнішній спостерігач читає
стан. Описати дозволену частоту Execute, прив'язку до PLC task, відсутність
гарантії thread safety і заборону неконтрольованого reentrant виконання.

Визначити duplicate enqueue, додавання running/stopped child, Clear активної
черги, Reset черги та зміну черги з callbacks. Borrowed child має існувати
до завершення всіх звернень до неї, включно із завершенням/reset композиції.

Вихід: таблиця ownership і дозволених queue operations. Додавати локальні
перевірки там, де порушення можна надійно виявити; не будувати global scheduler
або registry ownership у межах цієї задачі. Перевірити повторний enqueue,
Clear під час роботи та відмови child.Start/Reset за обраним контрактом.

## T04 — ресурс: володіння, borrowing та незавершені операції

Визначити, чи призначення ResourceManager передає задачі обов'язок release,
зокрема коли ресурс уже acquired до Start. Рекомендована проста модель:
ResourceManager представляє lifecycle ресурсу, яким керує задача, а borrowed
ресурс передається окремо, як у FileContentTask. Перевірити всі наявні callers
перед закріпленням цього правила.

Описати acquire pending, acquire failure, Cancel під час acquire, пізнє
завершення acquire та асинхронний release. ResourceAcquired=false саме по собі
не описує всі можливі pending operations; визначити, що має гарантувати
ReleaseResource при незавершеному AcquireResource. Не вводити новий API,
доки не встановлено, що наявного контракту недостатньо.

Вихід: resource protocol і порядок lifetime parent/child. Перевірки з fake
manager: pre-acquired resource, delayed acquire, cancel during acquire,
delayed release і release error. Best-effort file close зберегти.

## T05 — єдиний протокол завершення

У Task централізувати запит завершення, його причину, повідомлення і просування
cleanup. External cancel, internal abort, processing done/error та винятки
мають входити в узгоджений протокол. Нормальне завершення композиції не повинно
без потреби скасовувати вже завершені children.

Для композиції порядок: припинити запуск нових children; за потреби передати
запит завершення active child; виконувати child до завершення; після CanStop
почати власний release; встановити STOPPED. Причину обирати за T01.

Зберегти публічні стани, acquire/process/release та погоджений cancellation
flag approach. Переглянути роль OnCancelRequested/OnCancelling/CanStop для
узагальнення протоколу, зберігаючи їх cancellation semantics або надаючи
явний шлях міграції. Не змінювати public status types у цьому етапі.

Вихід: окремий diff Task/TaskQueue та regression tests. Основні сценарії:
exception у composite з active child, internal abort, success, cancel на
кожній фазі, кілька рівнів nesting, failure під час cleanup. Перевірити,
що parent не починає release раніше завершення children та callbacks не дублюються.

## T06 — видимість cancellation

Додати read-only CancellationRequested, доступну через ITask. Семантика:
ознака прийнятого зовнішнього запиту, а не будь-якого stop або pending work.
Визначити, коли вона скидається; рекомендовано зберігати TRUE протягом
очікування child і release parent, скидати при STOPPED або Reset.

Не прив'язувати public property до внутрішнього прапорця без перевірки:
поточний _CancelRequested скидається перед release, а T05 може узагальнити
його для всіх причин stop. Перевірити getter, repeated Cancel, release phase
і повторне використання після Reset. Новий enum state не додавати.

## T07 — незалежний public status

Відділити ITask від concrete wrappers TaskState, TaskRunningSubstate та
TaskStopReason. TaskState і TaskRunningSubstate прив'язані до concrete Task;
обрати enum/value properties або interfaces views для public contract.
Зберегти зручність State.Running та аналогічних викликів, якщо це виправдано
масштабом міграції. Оцінити зміну API перед вибором форми.

Вихід: окремий diff статусів та міграція всіх callers, яких він зачіпає;
старі helper wrappers можуть залишитися всередині Task. Перевірити через
ITask незалежний test adapter, який не успадковує Task, включно з виконанням
чергою. Перевірити snapshot/live-view semantics результатів і strings lifetime.

## T08 — lifecycle API та діагностика

Залишити у базовому ITask керування, загальний стан, результат, ім'я та
спостереження cancellation. Перенести ResourceManager і RunningSubstate
в окремий diagnostic interface або concrete Task, якщо caller analysis
підтвердить, що вони не потрібні для управління generic task.

Вихід: чітка межа public lifecycle/diagnostics та окремий diff міграції callers.
Перевірити resource-free adapter, resource-owning task і доступ діагностики
через QueryInterface там, де вона потрібна. Якщо користувачі реально потребують
цих properties у базовому контракті, зберегти їх і документувати причину;
не розділяти interfaces лише заради кількості abstractions.

## T09 — прогрес, timeout і зависання

Описати обмежений обсяг роботи одного Execute, потребу регулярних циклів
для acquire/processing/release та OnCancelling, відмінність тривалості
операції від часу одного виклику. Не обіцяти WCET без вимірювання.

Визначити, де задаються timeout операції та timeout завершення, як повідомляти
відсутність прогресу і що відбувається після timeout. Перевага — task-specific
або resource-manager-specific policy; не встановлювати довільний global timeout.
Timeout не повинен автоматично означати STOPPED або дозвіл release parent,
поки child все ще використовує ресурс. Forced stop потребує окремого контракту.

Вихід: документ політики та, за реальною потребою, окремий diff діагностики/
timeout. Перевірити manager, що не завершується, delayed completion і recovery;
відрізняти записаний timeout від фактично завершеного cleanup.

## T10 — інтеграційне завершення

Перевірити Tasks, Timers, FileSystem, Loggers, Tests та Samples після змін API
і lifecycle. Оновити library versions/resolutions за прийнятим workflow і
підтвердити source-to-library відповідність перед тестуванням.

Зокрема: Timer.Triggered/Restart, persistent FileContentManager, borrowed
file tasks, logger queues та rotation. File integration tests запускати лише
на ізольованих тестових paths. Оновити architecture.md, coverage.md, findings.md
і приклади використання за фактичною реалізацією.

Вихід: migration notes, compiler results, runtime results і перелік обмежень.
Повний план виконано лише коли завершені всі потрібні зміни та перевірки;
наявність написаних, але не запущених тестів не означає підтвердження поведінки.

## Порядок роботи над кожною задачею

1. Прочитати актуальний код, цей план і зміни попереднього етапу.
2. Зафіксувати конкретний контракт та межі поточного етапу.
3. Внести тільки його зміни, зберігши інші правки власника.
4. Виконати перевірки, відповідні зміні; записати commands/results/blockers.
5. Оновити статус етапу й коротко пояснити diff, сумісність і залишкові ризики.
6. За актуальним дорученням власника перейти до наступного етапу без підтвердження; явно фіксувати невиконані перевірки.

Статуси обліку: не розпочато; виконується; реалізовано, перевірки неповні;
завершено з потрібними перевірками. Якщо перевірка недоступна, записувати це
прямо і зберігати її як невиконану задачу.

Для запуску окремого етапу достатньо: «Виконай T05 із
docs/audit/itask-evolution-plan.md. Інші етапи не реалізовуй».


