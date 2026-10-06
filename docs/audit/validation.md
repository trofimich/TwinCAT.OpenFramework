# Збірка та перевірки

Дата: 2026-10-02. Це фактичні спостереження поточної сесії, не універсальна інструкція для всіх TwinCAT installations.

## Виконано

| Перевірка | Результат | Межа висновку |
|---|---|---|
| Git baseline/status перед роботою | Commit `330c73be6faab8bf9d1bda3c0afbe2bc59807b9e`; tracked changes відсутні | Не описує стан встановлених бібліотек |
| XML parsing | 597 файлів типів `.TcPOU`, `.TcIO`, `.TcDUT`, `.TcGVL`, `.TcTTO`, `.TcVIS`, `.plcproj`, `.tsproj`; 0 parse errors | XML well-formedness, не XSD validation та не ST compile |
| Compile include existence | 582 entries; 0 missing files | Не перевіряє resolve типів, contracts або libraries |
| Project inventory | 16 `.plcproj`; усі присутні у `.tsproj`; references/resolutions витягнуті | Library placeholders не дорівнюють source project dependencies під час реальної збірки |
| Test inventory | 21 POU успадковує TcUnit.FB_TestSuite; 106 рядків із синтаксичним `TEST(...)` | Не кількість реально виконаних тестів, не coverage measurement |
| Generic MSBuild solution build attempt | Failed, exit code 1, MSB4025 missing `.tsproj.metaproj` | Не дійшов до ST compiler; не свідчить про помилки ST-коду |
| Git status після документації | Зміни лише в `docs/audit/`, tracked source modifications відсутні | Не перевірка runtime |

Інвентаризацію можна повторити з кореня repository:

```powershell
& .\docs\audit\collect-inventory.ps1
```

Скрипт читає Sources, записує лише inventory.json/source-catalog.csv/compile-items.csv поруч із собою, не змінює PLC sources і не викликає compiler. Його успішний exit підтверджує збір metadata; parse/missing errors перевіряються окремими полями JSON.

## Доступні інструменти

- `dotnet.exe` доступний у PATH: `C:\Program Files\dotnet\dotnet.exe`. Це не TwinCAT ST compiler.
- MSBuild/devenv/TcXaeShell не знайдені через `Get-Command` у PATH, але за відомими installation paths знайдено:
  - `C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe` (і amd64 variant).
  - `C:\Program Files\Beckhoff\TcXaeShell\Common7\IDE\TcXaeShell.exe`, file/product version `17.0.0.0`.
- TwinCAT installed tree: `C:\Program Files (x86)\Beckhoff\TwinCAT\3.1`; є PLC component directories `Build_4026.20` … `Build_4026.27`, driver `TcRTime.sys`, XAE Beckhoff extensions. Наявність folders не доводить, яка версія compiler вибрана в XAE або ліцензована/придатна до execution.
- Служба `TcSysSrv` має status Running; `TcHmiSrv` Running, `TcAdsSerialCommServer` Stopped. Це не доказ, що саме OpenFramework PLC application запущений або runtime придатний для безпечного тесту.
- Tests явно посилається на TcUnit `1.3.1`, також має explicit PlaceholderResolution на цю версію. Встановлення/фактичне resolution TcUnit у XAE ще не перевірене.
- У `CompiledLibraries/` локально є `.library`, кілька historical exports і zip; серед них старий `AutomationEngine` поруч із `Automation`. Папка і compiler outputs ігноруються Git. Їхній вміст, checksums та відповідність current sources не перевірені.

## Спроба збірки

Фактично виконана команда з `D:\TwinCAT\OpenFramework`:

```powershell
& 'C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe' `
  'Sources\TwinCAT.OpenFramework.sln' /t:Build /p:Configuration=Debug `
  '/p:Platform=TwinCAT RT (x64)' /m:1 /v:minimal /nologo
```

Exit code: `1`. Отримана діагностика:

```text
D:\TwinCAT\OpenFramework\Sources\TwinCAT.OpenFramework.tsproj.metaproj : error MSB4025:
The project file could not be loaded. Could not find file
'D:\TwinCAT\OpenFramework\Sources\TwinCAT.OpenFramework.tsproj.metaproj'.
```

Причина на рівні механізму MSBuild solution/project integration; конкретне налаштування XAE для CLI build ще не визначено. Відсутній `.metaproj` не створювався вручну, sources/configuration не змінювалися для обходу. Native XAE build, Automation Interface build і compiler diagnostics по кожній бібліотеці не запускалися. Наявність XAE дає шлях для наступної задачі A01, але не змінює статус цієї спроби на успішний.

## Тестова модель, знайдена в коді

Tests MAIN викликає AutomationRunner з TestAutomationController. Його `OnBeforeChildrenWorking` викликає `TcUnit.RUN()`. Controller декларація містить 21 suite instance. TestTask період 10 мс, priority 1. Приклад TaskSequenceTest вимагає кількох cyclic calls і використовує VAR_INST/testFinished для одноразового завершення; запуск одного методу поза PLC loop не відтворює весь test lifecycle.

Suite inventory включає exceptions/random, static/dynamic collections, STRING/WSTRING builders/helpers, analog range converter, task sequence, directory/file content/logger. Tests не має прямих placeholders для Workflow, Timers, JSON чи окремої EventLogger library; це свідчить про відсутність прямого standalone suite wiring для цих бібліотек у поточному project metadata, а не доводить повну відсутність будь-якого непрямого покриття.

Частина suites працює з файловою системою/logging. Перед runtime запуском A01 має визначити ізольований target і тестові paths. Поточна сесія не активувала TwinCAT configuration, не завантажувала PLC application і не змінювала стан target.

## Не виконано

Успішна ST compilation, source-to-library resolution verification, запуск TcUnit, execution sample scenarios, regression tests preliminary findings, allocator exhaustion, WCET/stack/memory profiling, online change/restart, cross-platform builds. Відповідні висновки лишаються неперевіреними; наступні кроки визначені в [plan](plan.md).

## Поточне доповнення T00–T10

Первинні результати вище історичні. Нові sources після evolution не компілювалися
і не виконувалися. Власник доручив додати тести до наявного Tests для ручного запуску.
22 TcUnit method instances описані в itask-manual-validation.md.

Фактично виконано `docs/audit/check-itask-static.ps1`: 16 PLC projects,
608 parsed XML files, 593 Compile entries; помилок XML/includes/IDs у перевіреному
scope/registration немає. Звіт: itask-static-validation.json. `git diff --check`
не виявив проблем. Це static structure checks, не перевірка assertions або ST.

XAE baseline exports, fixture resolution failure і встановлення/зупинка UM Runtime
описані в itask-execution-journal.md з посиланнями на actual reports. Порожній старий
ErrorList не підтверджує zero diagnostics. Старі exports не відповідають новим sources.

## Нові тести поточної реалізації — 2026-10-05

Виконано `check-task-tests.ps1`: 45 XML files Tests, 407 unique object IDs,
Compile paths/registration, виклики та завершення 53 нових test methods,
controller instances і Timers placeholder перевірено структурно.
`git diff --check` без зауважень. ST compilation і TcUnit/runtime не виконано.
Для manual run, optional remote/short-write cases і трактування watchdog/bBusy
failures див. task-tests-2026-10-05.md. Цей результат не підтверджує історичні
T00–T10 тести та не гарантує resolution placeholders на поточні бібліотеки.

## Поточні п'ять тестів FileContentManager — поступове впровадження

Поточний FileContentManagerTest викликає CreateTextFile,
OpenMissingFileForReading, WriteToFileOpenedForReading, CancelDuringFileWrite
і ReuseAfterReset. Історичний великий набір із 53 сценаріїв не описує поточні
файли Tests. Власник підтвердив роботу OpenMissingFileForReading і
WriteToFileOpenedForReading після явного звільнення builders перед Throw,
а також роботу CancelDuringFileWrite.

ReuseAfterReset додано наступним окремим кроком. Перший запис завершується,
після чого менеджер скасовується з однією невиконаною задачею в черзі. Reset
має очистити чергу/шлях і повернути READY, не скидаючи дочірні задачі. Caller
окремо скидає write task, задає інший файл і перевіряє новий write/seek/read
через той самий manager. Старий waiting task не має запускатися. Є timeout
20 секунд. XML, object IDs, виклик із suite та git diff --check перевірено;
компіляція і runtime нового тесту агентом не виконувалися, результат ручного
запуску ReuseAfterReset ще очікується.

Власник підтвердив роботу ReuseAfterReset («все працює»), після чого попросив
спростити assertions. У FileContentManagerTest залишено ті самі 5 сценаріїв,
кількість Assert call sites скорочено з 61 до 46 (включно з setup failures і
timeouts). Прибрано повторні перевірки станів/порожньої черги на успішному
завершенні, повторну перевірку waiting child під час cancellation та другорядні
перевірки загального lifecycle у reuse case. Непорожнє повідомлення write error
окремо більше не перевіряється; збережено передачу повідомлення child→manager.
Після Reset окремо більше не перевіряється незмінність стану completed child;
перевіряються очищення queue/path і фактичне повторне використання. Видалено
зайвий busyWriteObserved: успішний cancelRequested встановлюється тільки при
WriteBusy=TRUE. Assertions згруповано, етапи ReuseAfterReset підписано.
XML/IDs, виклики всіх 5 методів, TEST_FINISHED і git diff --check перевірено.
Саме спрощену редакцію після цих правок у runtime ще не запускали.

## Core memory / exceptions — 2026-10-06

Поточні зміни: core-memory-journal.md, core-exceptions-review.md.
Статично перевірено XML змінених sources, збереження existing IDs (виняток —
погоджено видалений Objects.IsMemoryValid), унікальність test IDs, Compile paths,
виклики й TEST_FINISHED чотирьох нових ExceptionTest methods і чотирьох
ObjectLifetimeTest methods. Усі 14 production ReThrowLastException callers
передають caught code; Workflow також передає saved payload. Старих calls без
аргументів у Sources немає. git diff --check пройдено.
ST compilation, source-to-library resolution, TcUnit, cleanup counts та fatal
allocation injection не виконано. Виявлена інсталяція XAE не є результатом
збірки. Попередню домовленість залишити build/runtime власнику збережено.

Подальша спроба XAE для snapshot завершилася без результату: CreateDTE 0x80080005
у sandbox; повторна — null-valued expression на фазі CheckAllObjects:Core,
Checks порожній. Див. core-current-check*.json. Успіх compilation не встановлено.
Власник припинив автоматичні перевірки. Після додавання guards решти Clone,
виправлення concrete clone type й caught assertions жодні check-скрипти,
XML validation, compilation або runtime не запускались. Перевірки виконує власник.

2026-10-06: власник надав чотири діагностики ST compiler: C0241 для
GetAddressFromInterface, C0066 для RefuseStaticObjectRelease і дві C0186
для AggregateCloneLifetime. Це підтверджені компілятором помилки попередніх
змін. Внесено адресні виправлення: receiver __QUERYPOINTER має тип
POINTER TO BYTE замість PVOID; тест відмови release порівнює два IObject;
результати GetInnerException перед порівнянням збережено в локальні IException.
Контракти й призначення assertions збережено. Повторна compilation та інші
перевірки агентом не виконувалися за вказівкою власника; успіх збірки не заявлено.

2026-10-06: власник відтворив отримання 3902013441 замість 28 вже при первинному
F_RaiseException на TwinCAT 3.1.4026.27. Після погодження змінено propagation
на framework SystemException payload. Підготовлено тест
RethrowSystemExceptionAfterFramework замість попереднього native сценарію;
відомий native код передається адаптеру напряму. Нові зміни не перевірялися.
Власнику належить перевірити compilation, новий тест, чинний
RethrowSavedFrameworkException і Workflow OnFail із вкладеним системним catch.
Окремо залишається runtime перевірка fatal OOM latch без повторних allocations
і зупинки на boundary; тест обгортки цього не доводить.

2026-10-06: перед аудитом Core/Interfaces власник повідомив: «я все перевірив
і воно працює» щодо попередніх змін Object/memory/exceptions. Статус —
підтвердження власника про успішну перевірку у його середовищі. Детальний
перелік сценаріїв і logs не надано; не приписуємо цьому виконання всіх OOM,
boundary-stop або platform cases. Новий огляд interfaces — лише статичний.
