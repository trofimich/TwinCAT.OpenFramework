# Попередні знахідки

Baseline: `330c73be6faab8bf9d1bda3c0afbe2bc59807b9e`, 2026-10-02.

Усі записи нижче отримані статичним читанням; жоден сценарій не виконувався на TwinCAT runtime. «Висока впевненість» означає переконливий шлях у вихідному коді, а не підтверджений тестом дефект. Пріоритет P1 — потенційна неправильна робота/ресурси/runtime fault; P2 — локальна поведінка або діагностика. Запропоновані напрямки виправлення ще не реалізовані.

## Уточнення власника — 2026-10-02

Власник повідомив, що частина знахідок реальна, а частина не є помилками та виникла через неправильне розуміння логіки агентом. Конкретні записи поки не визначені. Формулювання й рівні впевненості нижче збережені як початкові висновки для подальшого розбору, а не як підтверджені факти. Статус усіх OF-001–OF-007: **очікує індивідуального уточнення та повторної перевірки**. Не можна приписувати власнику підтвердження або спростування конкретного запису.

Код після baseline уже має локальні зміни; перед повторною перевіркою слід прочитати поточні реалізації. Після уточнення кожного запису зберігати: підтверджено/спростовано/залишається відкритим, пояснення контракту й окремо статус runtime verification.

## Повторна перевірка після правок власника

Актуальні результати за робочим деревом 2026-10-02: [повторний review OF-001–OF-006](recheck-2026-10-02.md). Первинні описи нижче залишені як історія baseline; поточний статус визначається таблицею тут. ST compilation/runtime verification не виконані.

| ID | Поточний статус |
|---|---|
| OF-001 | Виправлено за статичним аналізом |
| OF-002 | Виправлено за статичним аналізом |
| OF-003 | Виправлено за статичним аналізом |
| OF-004 | Внесено погоджене виправлення: OnCancelRequested передає child.Cancel; OnCancelling виконує child до CanStop; RETURN після STOPPED. Статично перевірено; ST compilation/runtime regression не виконано. Деталі: [review прапорця](of-004-cancel-flag-review.md) |
| OF-005 | Виправлено за статичним аналізом |
| OF-006 | Закрито: error logging виправлено; власник підтвердив best-effort cleanup без зміни результату основної операції. Вимогу міняти FinalStopReason спростовано контрактом |
| OF-007 | Виключено з поточного review за запитом власника; окрема робота |

## OF-001 — INVALID runner перезаписується на RUNNING

Пріоритет: P1. Упевненість: висока, статичний дефект переходу стану. Задача: A03.

Доказ: [AutomationRunner.TcPOU:95](../../Sources/TwinCAT.OpenFramework.Automation/AutomationRunner/AutomationRunner.TcPOU#L95), рядки 95–118. Перед циклом `initialized := TRUE`. При null component (99–102) або OperationalState.INVALID (107–110) runner встановлює INVALID і робить EXIT, але не скидає initialized. Після циклу `IF initialized THEN _State := RUNNING`.

Сценарій: SystemDataValid=true, runner INITIALIZING, один component=null. Після Execute очікується INVALID; за цим шляхом виходить RUNNING. Наступний цикл намагається викликати null component.Execute. Аналогічно для першого component, що стає INVALID, якщо перед ним не було pending initialization.

Перевірка: tests для null першого/останнього component, INVALID першого/останнього та попереднього INITIALIZING. Перевірити state й InitializationErrorMessage після кожного циклу. Напрямок: RUNNING можливий лише якщо весь обхід завершено без помилки й всі components ініціалізовані.

## OF-002 — читання ClassName після видалення instance

Пріоритет: P1. Упевненість: висока щодо lifetime reference, вплив у runtime потребує перевірки. Задача: A02.

Доказ: [Memory.TcPOU:95](../../Sources/TwinCAT.OpenFramework.Core/Utilities/Memory/Memory.TcPOU#L95), рядки 95–101. `objectClassName REF= objectPointer^.ClassName`, далі `__DELETE(objectPointer)`, а потім `TO_WSTRING(...objectClassName...)` для logging. Наприклад, [List.ClassName:133](../../Sources/TwinCAT.OpenFramework.Collections/List/List.TcPOU#L133) повертає reference до instance-поля `_ClassName`.

Сценарій: видалити динамічний instance із ClassName у його власній пам'яті. Reference залишається адресою в звільненому instance. `__ISVALIDREF` не використовується в коді як ownership/lifetime tracking; навіть якщо адреса ще читається, вона більше не належить об'єкту. Можливі некоректна діагностика чи доступ до перевикористаної пам'яті.

Перевірка: простий динамічний IObject, disposal logging і повторна алокація того ж розміру; runtime diagnostics у контрольованому середовищі. Напрямок: скопіювати ClassName у локальний STRING до __DELETE, а не зберігати reference.

## OF-003 — outer catch у Branch.Execute не отримує exception code

Пріоритет: P2. Упевненість: висока. Задача: A03/A07.

Доказ: [BranchAutomationComponent.TcPOU:356](../../Sources/TwinCAT.OpenFramework.Automation/AutomationComponent/Branches/BranchAutomationComponent.TcPOU#L356), також 378. `Execute` оголошує `exceptionCode`, але обидва catches написані як `__CATCH`, без `(exceptionCode)`. Усередині викликається `GetLastException(exceptionCode, ...)`. У [ExceptionManager.GetLastException](../../Sources/TwinCAT.OpenFramework.Core/Objects/Exceptions/ExceptionManager.TcPOU) framework exception повертається тільки для потрібного exception code; інакше конфігурується SystemException.

Сценарій: exception виходить із OnBeforeExecute/OnAfterExecute у зовнішній catch. Код фактичного винятку не передається; GetLastException може повернути SystemException із default code замість вихідного exception та його контексту. У AutomationController частина помилок уже ловиться внутрішніми catches, тому дефект стосується тих, які досягають зовнішньої межі.

Перевірка: test descendant Branch, який кидає власний exception із callback, і assert вихідного типу/message/code у OnHandleException. Напрямок: явно приймати код catch; звірити всі подібні місця, не змінюючи свідомі catches без подальшого використання code.

## OF-004 — cancel черги може залишити дочірню task у RESOURCE_RELEASING

Пріоритет: P1. Упевненість: середньо-висока; умовний сценарій із асинхронним resource manager. Задача: A06.

Доказ: [TaskQueue.OnBeforeStop:81](../../Sources/TwinCAT.OpenFramework.Tasks/TaskQueue/TaskQueue.TcPOU#L81) лише викликає `_CurrentTask.Cancel()`. Child Execute викликається в `OnRunning` (112). [Task.Cancel](../../Sources/TwinCAT.OpenFramework.Tasks/Task/Task.TcPOU) у processing з acquired resource переводить child до RESOURCE_RELEASING; закінчення ReleaseResource відбувається наступними Execute. StandardTaskQueue не має власного ResourceManager; базовий OnStopped порожній, TaskQueue його не перевизначає.

Сценарій: StandardTaskQueue виконує child із acquired resource і release, який потребує кількох циклів. Cancel parent викликає child.Cancel, але parent без resource сам переходить у STOPPED. Подальші parent.Execute не викликають OnRunning, отже child.Execute більше не просуває release. Результат: незавершена child/task або незвільнений resource, якщо child окремо ніхто не виконує.

Перевірка: fake IResourceManager із release за 2–3 Execute; запустити child через queue, cancel queue, продовжувати лише queue.Execute, перевірити child state і число release calls. Повторити для cancellation під час acquire та failure. Напрямок: контракт зупинки parent має чекати фактичного завершення child cleanup.

## OF-005 — кнопка TurnOff у sample перевіряє TurnOn.Value

Пріоритет: P2. Упевненість: висока, локальна логічна помилка. Задача: A12 або окрема коротка regression task.

Доказ: [IntersectionController.TcPOU:327](../../Sources/TwinCAT.OpenFramework.Samples/Intersection/IntersectionController/IntersectionController.TcPOU#L327): `ELSIF TurnOffButton.Changed AND_THEN _TurnOnButton.Value THEN TurnOff()`. TurnOn і TurnOff — різні instances і різні inputs: bindIO прив'язує їх до DI_1.Ch2 та DI_1.Ch3.

Сценарій: TurnOn.Value=false, змінити TurnOff input із false на true. Очікується TurnOff; умова його відхиляє. За TurnOn.Value=true можливе спрацювання й на відпускання TurnOff, оскільки Changed не розрізняє фронт і спад.

Перевірка: таблиця чотирьох комбінацій on/off input плюс натискання/відпускання. Напрямок: condition має використовувати значення самої TurnOffButton відповідно до задуманої edge semantics. Кратність ProcessInput також перевіряється A07.

## OF-006 — close error може трактуватися як успішне звільнення file handle

Пріоритет: P1. Упевненість: середня; семантику системного FB слід підтвердити для build 4026.27. Задача: A09.

Доказ: [FileHandleResourceManager.ReleaseResource](../../Sources/TwinCAT.OpenFramework.FileSystem/Tasks/File/FileContent/FileHandleResourceManager.TcPOU) викликає FB_FileClose, але не перевіряє `_FileClose.bError`/`nErrId`. За `NOT _FileClose.bBusy OR_ELSE _FileOpen.hFile=0` встановлює `_FileHandleAcquired := FALSE` і журналює «closed». AcquireResource, навпаки, перевіряє bError.

Сценарій: FB_FileClose завершує операцію з bBusy=false та bError=true. Framework позначає resource released і може залишити успішний stop reason, приховавши failure. Чи лишається фактичний handle відкритим, залежить від причини помилки; це не стверджується без виконання.

Перевірка: контрольована помилка close/invalid handle, assert error propagation і final stop reason. Напрямок: явний контракт release failure та відповідний стан; окремо перевірити FB_exit, де один виклик asynchronous close не доводить його завершення.

## OF-007 — allocations використовуються без перевірки результату

Пріоритет: P1. Упевненість: середня щодо відтворення exhaustion; відсутність перевірок підтверджена. Задача: A02/A05.

Докази: [List.AllocateMemory](../../Sources/TwinCAT.OpenFramework.Collections/List/List.TcPOU) робить __NEW, копіює/видаляє старий buffer і присвоює новий без перевірки newMemory. [DynamicMemoryManager:136](../../Sources/TwinCAT.OpenFramework.Core/Utilities/Memory/DynamicMemoryManager.TcPOU#L136) не перевіряє pointer перед MEMCPY/індексуванням. [GenericValueFactory:432](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Generic/GenericValueFactory.TcPOU#L432) одразу робить MEMCPY після __NEW; StandardException.Clone одразу розіменовує exceptionClone.

Сценарій: недостатньо dynamic memory. Якщо allocation API повертає null у цьому режимі, наступні memory operations використовують null; при growth старі дані можуть бути втрачені. Точний спосіб відмови allocator і можливість safely catch помилку ще не перевірено.

Перевірка: documented/runtime allocation-failure behavior у локальному simulator із контрольованим memory limit, перевірка атомарності growth і збереження old buffer. Напрямок: не змінювати ownership/capacity до успішної allocation та copy; не допускати рекурсивного створення heap exception при exhaustion.

## OF-008 — ймовірний витік локального WideStringBuilder при Throw

Власник повідомив про runtime warning після перезапуску Tests із
OpenMissingFileForReading: незвільнений dynamic block розміром 162 байти.
Сам warning підтверджений повідомленням власника; конкретний allocation site
ще не підтверджено debugger/runtime trace. Впевненість у наведеній причині висока.

FileHandleResourceManager.AcquireResource оголошує messageBuilder у VAR методу
(рядок 45), будує повідомлення у гілці _FileOpen.bError (61–65) і викликає
openFileException.Throw (67) без попереднього Clear(TRUE).
WideStringBuilder.InternalAppend при першому короткому append встановлює
capacity=80 і виділяє 2 + 80*2 = 162 байти (255–258). Поточний error text із
шляхом C:\OpenFramework_Missing_Test_Missing_File.txt має 70 символів, отже
вміщується саме в цей початковий allocation. AssignToString копіює текст,
але не звільняє buffer (167–169). Звільнення виконує Clear(TRUE) з FB_exit (232).
Builder не реєструє свій raw buffer у DynamicMemoryManager.

Робоча гіпотеза: F_RaiseException переводить виконання в зовнішній catch Task,
оминаючи нормальний epilogue/FB_exit локального builder; pointer на буфер
втрачається. Збіг allocation size і error path є сильним доказом, але сам по
собі не встановлює адресу allocation і поведінку unwinding конкретного runtime.
Документація Beckhoff підтверджує FB_exit для stack instances у сучасних compiler
versions (C0394), але знайдені матеріали не підтверджують його виклик під час
цього exception unwind: https://infosys.beckhoff.com/content/1033/tc3_plc_intro/5535754251.html

Мінімальний запропонований крок: messageBuilder.Clear(releaseMemory := TRUE)
після AssignToString(message), перед Throw. Перевірка: breakpoint перед Throw,
зіставлення messageBuilder._String із leak address та повторний запуск/перезапуск
із явним Clear. Production-код у межах цього дослідження не змінено.
Схожий шлях є у WriteString255ToFile.OnRunning (124–130); це кандидат для
аналогічної перевірки, а не окремо відтворений витік. ST/runtime тут не запускалися.

Після явного погодження власника внесено мінімальне виправлення в обидва місця:
AcquireResource викликає messageBuilder.Clear(releaseMemory := TRUE), а
WriteString255ToFile.OnRunning — errorMessageBuilder.Clear(releaseMemory := TRUE)
після копіювання повідомлення та перед Throw. XML/IDs і git diff --check перевірено.
Потрібно повторити OpenMissingFileForReading та WriteToFileOpenedForReading із
оновленою бібліотекою FileSystem і перезапустити PLC. Відсутність витоку після
виправлення ще не підтверджена runtime; запис не вважається остаточно закритим.

Уточнення власника: виправлення підтверджено ручною перевіркою лише для
OpenMissingFileForReading. WriteToFileOpenedForReading після виправлення ще
не перевірено. Попереднє трактування агентом обох місць як підтверджених було
помилковим. OF-008 частково підтверджено: AcquireResource — виправлення
підтверджене власником; WriteString255ToFile.OnRunning — правку внесено,
runtime-перевірка очікується. Агент runtime не запускав. Це підтвердження
не поширюється на інші місця використання локальних builders перед Throw.

Наступне повідомлення власника «Працює» після уточнення про неперевірений
WriteToFileOpenedForReading підтверджує і цей сценарій. Обидві локальні правки
OF-008 тепер підтверджено ручною перевіркою власника; інші throw paths цим
не перевірені.

## Відомі обмеження та питання, які не оголошуються багами

- `TO_DO.txt`: exception handling для parallel PLC tasks ще в планах. Single exception slot/cycle cleanup роблять це високопріоритетним контрактом A02/A13, але не новим дефектом, якщо parallel use офіційно не підтриманий.
- `JSON/ReadMe.txt`: не використовувати dynamically created source/target structure. Це відоме обмеження, яке має бути перевірене/чітко задокументоване.
- Документація містить старі назви `CompositeDevice`, `INITIALIZATION_FAILED`, `SystemDateTimeManager`, а поточний код — CompositeAutomationComponent, INVALID, System. Guide також поміняв input/output описи DI_1/DO_2 та назвав runner instance controller. Це documentation drift, окрема A14.
- IO input/output проходить через controller/composite hooks і leaf.Execute; відтак можлива повторна обробка. Без контракту кратності та end-to-end trace це лише ризик, а не доведений функціональний дефект.
- GENERIC_VALUE copy/adoption, клонування OBJECT через MEMCPY і lifetime enumerators потребують повного аналізу; одна наявність цих механізмів не доводить double-free.
- Unlimited nesting та deterministic execution з концептуальної документації потребують перевірки stack depth, allocations і worst-case cycle time; це не підтверджені властивості всього runtime.

## Доповнення після T00–T10

OF-004: static implementation тепер використовує однакове очікування child для
cancel/done/abort/error/exception. 22 тести підготовлено у Tests; виконання відкладено
власнику. Не підвищувати статус до runtime reproduced/verified без TcUnit report.
OF-006: best-effort close policy збережена. OF-007 і allocator audit не виконувалися.
Pending ADS open/close — окрема ручна перевірка T04/T10, не підтверджена тут нова
знахідка витоку. Див. itask-manual-validation.md та itask-execution-journal.md.

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
## Уточнення scope ResourceManager у ITask — 2026-10-04

Власник підтвердив, що ResourceManager навмисно входить у публічний ITask для
роботи з файлами, з'єднаннями та іншими ресурсами. Його наявність не вважається
дефектом інтерфейсу. Погоджено зберегти поточну структуру ITask й уточнити
коментарями ownership ресурсу, правила Start/Cancel/Reset/Execute та live views.
Коментарі внесено; перевірено XML, незмінність декларацій без коментарів та IDs.
Це уточнення контракту, не runtime verification.
## Timer timing/restart — уточнення власника та виправлення 2026-10-05

Власник підтвердив: запуск таймера не повинен чекати наступного Execute.
Додано Timer.OnBeforeStart з TON start; Restart підтримує RUNNING через один
крок cancellation, Reset і Start. SetIntervalAndRestart більше не змінює interval
при невдалій підготовці. Статичні докази попереднього стану: Reset/Start
відмовляли в RUNNING; запис PT між ними виконувався незалежно від відмови.
Погоджені правки внесено; XML/control-flow checks виконано, runtime відтворення
та ST compilation не виконані. Старі висновки про Restart у RUNNING більше
не описують поточну реалізацію. Деталі: task-review-after-rollback.md.

## FSQ-1 — cancellation файлових children, 2026-10-05

За погодженням власника додано OnCancelling у сім file-content tasks. Під час
скасування вже busy FB просувається з bExecute=FALSE до NOT bBusy, і лише тоді
readyToStop дозволяє STOPPED та закриття parent handle. Початкові transition
докази та ручні сценарії: filecontent-review-2026-10-05.md. XML/IDs/change scope
і diff whitespace checks пройдено; ST compilation/runtime не виконані.
FSQ-2 (pending open) цим не виправлено. Це не фізичне скасування ADS operation.

## FSQ-2 — очікування open під час cancellation, 2026-10-05

Внесено FileContentManager.OnCancelling і FileHandleResourceManager.FinishPendingAcquire.
Cancellation чекає вже busy open; успішно отриманий handle позначається acquired
і закривається existing release path. ResourceAcquired semantic не змінено.
Статичні XML/IDs/scope/diff checks пройдено, ST/runtime не виконано; фізичний
витік до правки та його усунення runtime-тестом не підтверджувалися.
Деталі й межі гарантії: filecontent-review-2026-10-05.md.

## FSQ-3 — повторна прив'язка READY file task, 2026-10-05

За погодженням власника SetFileHandleResource дозволяє заміну/скидання reference
в READY; в інших станах кидає exception до зміни reference. Після вилучення
waiting task звичайний повторний Enqueue більше не відхиляється через стару
прив'язку. Caller відповідає за попереднє вилучення з черги. Task.Reset не змінено.
XML/IDs/scope/diff checks виконано; ST/runtime не виконано.
Деталі: filecontent-review-2026-10-05.md, FSQ-3.

## FSQ-5 — target дочірніх файлових операцій, 2026-10-05

Внесено FileHandleResource.AmsNetId та копіювання target з ресурсу в сім
файлових FB перед першим запитом, поруч із hFile. Окреме налаштування child
перезаписується адресою ресурсу. Manager.AmsNetId стабільний від Start до STOPPED
за контрактом. Remote logger wiring статично виправлено; runtime не підтверджено.
XML/IDs/scope/diff checks пройдено. Деталі: filecontent-review-2026-10-05.md.
FSQ-4 залишається пропозицією, без реалізованої перевірки partial write.

## FSQ-4 — short write тепер дає FAILURE, 2026-10-05

Погоджену перевірку cbWrite<>cbWriteLen внесено в WriteBytesToFile.OnRunning
після завершення FB. Нерівність повертає ERROR з expected/actual counts;
Task/TaskQueue передають FAILURE. Попередній статус «лише пропозиція» замінено
на «реалізовано, статично перевірено». XML/IDs/scope/diff перевірено;
ST compilation і runtime не виконано. Деталі: filecontent-review-2026-10-05.md.

## Core memory — уточнення власника 2026-10-06

Власник підтвердив виключний ownership DynamicMemoryManager для успішно
зареєстрованих auto-disposed objects. Ручне видалення й передача ownership
порушують цей контракт; відсутність unregister не є дефектом.
Також підтверджено cleanup без exceptions у FB_exit нащадків Object і disposal
logger/filter. Відсутність catch у Memory.TryRelease… не є дефектом за цим
контрактом. Обидві неоднозначності закрито уточненням власника, не runtime-тестом.

Незахищений allocation у DynamicMemoryManager повторно встановлено за поточним
кодом у першій групі Core. Це локальна частина історичного OF-007, без висновків
про виправлення решти allocator sites. Власник визначив allocation failure
критичною помилкою із зупинкою контролера й погодив flag із повторним підняттям
системного exception у runner. C02 реалізовано: guard перед використанням
allocation, commit capacity після успіху, latched failure та перевірка runner
до cleanup поза callback handlers. Відсутність зовнішнього swallow-catch навколо
Runner.Execute є передумовою зупинки. XML/IDs/scope перевірено статично;
ST compilation, runtime exhaustion і фактична зупинка не перевірені.
Контракти й статус поточного кроку: [core-memory-journal.md](core-memory-journal.md).

Objects.IsMemoryValid: власник уточнив задум як перевірку існування об'єкта
після можливого видалення. Поточний query цього не гарантує: повторне
використання адреси іншим IObject не відрізняється від початкового instance.
Це статично встановлена невідповідність задуманій гарантії; runtime немає,
callers у Sources не знайдено. Приклад ekvip із memory-area/alignment checks
також не вирішує identity/lifetime. Власник погодив видалення методу;
API видалено, XML і відсутність references у Sources перевірено статично.
Деталі та підготовлені, але не виконані FB_exit тести: журнал C04–C05.

Core cleanup reentrancy, 2026-10-06: власник заборонив реєструвати нові
auto-disposed objects і повторно викликати CleanupMemory із callbacks під час
cleanup. Звільнення власних resources дозволене. Умовні сценарії втрати нової
реєстрації/повторного видалення порушують цей уточнений контракт; дефектом
допустимого використання не вважаються. Додано коментарі, без runtime guards.
Підстава — підтвердження власника та статичний аналіз; див. журнал C07.

## Core exceptions — друга мала група, 2026-10-06

Поточний статичний review п'яти базових declarations:
[core-exceptions-review.md](core-exceptions-review.md).
E01: SystemException.Clone не реєструє allocation; AggregateException клонує
static system exception, але Clear звільняє тільки масив references. Встановлено
шлях втрати owner, runtime не виконано. E02: UTC helper Exception використовує
localTimestamp; виправлення запропоновано. E03: власник підтвердив rethrow саме
поточного caught exception; global-slot вибір не гарантує цього. Знайдено
14 callers, у Workflow також потрібне збереження payload після nested OnFail.
Після доручення продовжити E01/E02/E03 виправлено статично: SystemException
реєструється і зберігає catch point у Clone; UTC branch читає utcTimestamp;
ReThrowLastException передає caught code та saved payload із Workflow.
Усі 14 callers оновлено. За окремим підтвердженням власника null allocation
SystemException.Clone використовує existing fatal latch через спільний helper.
Додано 4 TcUnit scenarios, але ST compilation/runtime не виконано.
Ці findings не означають аудит
усієї ієрархії exceptions, Collections або Workflow.

Продовження clone paths: додано fatal null guards у решті 22 concrete Clone.
ArgumentTypeNotSupportedException.Clone створював інший concrete type,
ArgumentTypeClassNotSupportedException; allocation/pointer виправлено, додано
тест збереження початкового interface. Підстава — читання поточного коду,
не виконаний тест. Старі 3 ExceptionTest сценарії посилено caught assertions.
За інструкцією власника нові правки не перевірялися check-скриптами/compiler/runtime.
Контракт aggregate self/cycles/capacity залишається відкритим питанням.

Наступне уточнення власника закрило це питання: self-add і cyclic graphs
заборонені, максимум 255 entries. Guard місткості використовує existing fatal
OUT_OF_MEMORY latch до підготовки нового inner; public count UINT збережено.
Три loop bounds переведено на явне TO_DINT(count)-1; CopyFields вимагає empty
destination. Empty semantics погоджено. Перевірок цієї редакції не виконано.

2026-10-06: runtime власника (TwinCAT 3.1.4026.27) показав підміну 28 на
3902013441 при первинному F_RaiseException, ще до ReThrowLastException.
Власник погодив передавати далі SystemException як framework payload.
Внесено зміни manager, metadata callers і snapshot shared system instance
у Workflow до callbacks. Це workaround для propagation отриманої причини;
вже втрачений первинний код він не відновлює. Трактування 3902013441 як
framework compatibility code залишається неоднозначним для сторонніх прямих
F_RaiseException. Fatal OOM залишається окремим latched шляхом. Перевірок нових
змін не виконано. Деталі: core-exceptions-review.md.

2026-10-06: оглянуто 13 interfaces у Core/Interfaces. Результат і конкретні
references: core-interfaces-review.md. Статично встановлено невідповідність
Reset у StringSplittingEnumerator/WideStringSplittingEnumerator: після кінця
обходу cursor лишається нульовим; повторний MoveNext не починає обхід заново.
Runtime не відтворювався, виправлення не внесено. Clone ownership у generic
consumer потребує уточнення; автоматичне володіння exception clone суперечить
погодженому ownership DynamicMemoryManager. Власник уточнив: Clone лише робить
копію, не керує ownership; рішення щодо generic consumer ще не погоджене.
Name/Error references за підтвердженням власника призначені лише для читання
без копіювання; зовнішній запис є порушенням контракту. Відсутність Core
IStartable/ICancellable не визнано дефектом дизайну.

2026-10-06: за прямим погодженням власника виправлено Reset обох string
splitting enumerators: поточний fragment звільняється, cursor відновлюється
присвоєнням SourceString замість MEMCPY. Allocation strategy залишено поточною.
Статус: виправлення внесено; compilation/runtime та check-скрипти не запускалися.
Контракт і ручні сценарії: core-interfaces-review.md, розділ Reset.
