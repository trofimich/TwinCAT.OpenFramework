# OpenFramework: контекст для наступних сесій

## Постійні правила власника — 2026-10-06

Ці правила застосовуються до всього проєкту, включно з тестами й прикладами.
Нижчі датовані записи описують історію; старі плани не є дозволом виконувати
їх знову. Нові прямі уточнення власника мають перевагу над попередніми домовленостями.

### Документація біля декларацій

- Кожен новий тип (FB/клас, interface, DUT: enum, struct, alias тощо)
  повинен мати змістовний DocGen-коментар біля декларації.
- При зміні наявного типу актуалізуй його DocGen-опис; якщо опису немає,
  додай його в межах цього типу. Так само документуй нові або змінені методи,
  властивості й функції відповідно до їхнього призначення та контракту.
- Формат: `(*! ... *)` або `//!`, теги `<summary>`, `<description>`, `<param>`.
  Не змішуй XML DocGen з Markdown/rST. Зразок і деталі:
  `docs/audit/docgen-migration.md`.
- Summary пояснює призначення своїми словами. Description описує суттєві
  передумови, результати, зміни стану, ownership/lifetime, помилки й обмеження
  успадкування/callbacks, коли це стосується типу. Не додавай порожніх секцій
  і переказу очевидного синтаксису. Непогоджені припущення не видавай за контракт.
- Пояснення алгоритму всередині implementation залишай звичайними ST-коментарями.
  Ліцензійний notice також звичайний коментар; актуальна ліцензія — MIT,
  джерело `LICENSE.txt`. Зберігай авторство.

### Стиль Structured Text

- Один оператор на рядок. IF/ELSIF/ELSE/END_IF, цикли, CASE і TRY/CATCH
  оформлюй багаторядково, навіть для одного RETURN або виклику.
- Приватні поля класів/FB починай з `_`. Це правило не переноситься автоматично
  на локальні змінні методів і параметри. Не перейменовуй сторонній API.
- Відділяй порожнім рядком логічно незалежні групи змінних та кроки алгоритму.
  Тісно пов'язані декларації й операції групуй разом; не вставляй механічно
  порожній рядок після кожної змінної чи оператора.
- Відступи, регістр і решту оформлення відтворюй за послідовними зразками
  власника в сусідньому коді. Стислі конструкції, раніше додані агентом,
  не вважай еталоном стилю.
- Якщо правило не описано і зразки не дають однозначної відповіді, запитай
  власника; не вводь власний стандарт без погодження.

Бажаний вигляд навіть для короткої умови:

```structuredtext
IF condition THEN
	CallMethod();
END_IF
```

### Простота та уточнення

- Обирай найпростіший зрозумілий людині код, який забезпечує погоджений контракт.
  Не додавай абстракцій, helpers, flags, fallback paths або TRY/CATCH лише
  «про всяк випадок». Кожне ускладнення повинно мати конкретну необхідність.
- Не приховуй реальних проблем заради меншої кількості рядків. Пояснюй
  необхідність складнішого рішення, його ціну та вплив на сумісність.
- У всіх випадках незрозумілого задуму, контракту, поведінки або стилю спочатку
  постав конкретне питання. Не вигадуй вимоги й не реалізуй непогоджене припущення.
  Залежну частину відклади до відповіді; незалежну погоджену роботу продовжуй.
- Не перепитуй вже погоджене. Працюй невеликими завершеними кроками; не розширюй
  локальний запит до масового рефакторингу чи форматування без доручення.
- Нові явно підтверджені загальні правила записуй сюди, а рішення щодо конкретних
  контрактів — біля декларацій і в робочому журналі. Не записуй власну здогадку
  як правило власника.

### Поточна домовленість про перевірки

Власник сам виконує перевірки. Без нового доручення не запускай compilation,
TcUnit/runtime, XML validation, check-скрипти або генерацію DocGen.
Читання й пошук, необхідні для розуміння та редагування, дозволені.
У звіті точно зазначай, що змінено і що ще не перевірено. Старі записи про
виконані перевірки не підтверджують нову редакцію коду.

## Початкове знайомство

Перед архітектурними змінами або аудитом прочитай `docs/audit/architecture.md`.
Для продовження аудиту також прочитай `docs/audit/coverage.md`, `docs/audit/plan.md`,
`docs/audit/findings.md` і `docs/audit/validation.md`. Це робочі матеріали дослідження,
а не остаточна специфікація. Звіряй їх із поточним кодом і поясненнями власника.

Первинне дослідження виконано 2026-10-02 для commit
`330c73be6faab8bf9d1bda3c0afbe2bc59807b9e`. Код після нього міг змінитися;
перед використанням старих file/line references перевіряй актуальні реалізації
та Git status. Зберігай наявні зміни користувача.

## Коротка карта

- TwinCAT Structured Text у XML: декларації та реалізації POU/method/property
  зберігаються переважно в CDATA. Зберігай XML-структуру й object IDs.
- Solution: `Sources/TwinCAT.OpenFramework.sln`; system project містить 16
  PLC-проєктів. Залежності бібліотек задекларовані через placeholders;
  їх фактичне resolution не можна ототожнювати з поточними sources.
- Core: Object/IObject, generics, memory, exceptions, system, logging facade
  і базові interfaces. Comparision і Collections будуються на Core.
- Automation: MAIN → AutomationRunner → controllers/branch/leaf components;
  explicit initialization, cyclic execution, policies, events, permissions,
  plugins та IO processing. IO.Models відділені від Devices.IO.
- Tasks: кооперативні state machines із acquire/process/release і queues.
  Timers і FileSystem використовують Tasks; Loggers використовує FileSystem.
- Workflow: окреме дерево activities із variables та dynamic-child registry;
  не є scheduler бібліотеки Tasks. JSON та EventLogger — окремі adapters.
- Tests: TcUnit suites через TestAutomationController і runner. Samples:
  intersection та workflow demo. Temporary: legacy для міграції, окремий scope.
- GENERIC_VALUE містить type/address/size/ownership. Не ототожнюй borrowing,
  cloning та adoption. Автоочищення зареєстрованих objects має cycle lifetime;
  не припускай, що всі dynamic objects автоматично реєструються.

## Уточнення власника та робота зі знахідками

2026-10-02 власник повідомив: частина preliminary findings реальна, частина
не є помилками й виникла через неправильне розуміння логіки агентом.
Після наступних правок виконано статичний review OF-001–OF-006:
OF-001/002/003/005 виправлені; OF-004 залишається умовним сценарієм для child
із власним асинхронним resource. Власник уточнив OF-006: закриття file handle
є best-effort cleanup; close failure журналюється і не змінює результат
основної файлової операції. Не вимагай FAILURE у FinalStopReason лише через
невдалий close. OF-006 закрито: відсутнє error logging виправлено, а вимогу
міняти stop reason спростовано контрактом власника. Звичайні FileContentTask
позичають handle у FileContentManager, який сам володіє resource.
Деталі: `docs/audit/recheck-2026-10-02.md`. OF-007 виключено з цього review
за запитом власника. Runtime перевірки не виконано. Не вважай старі позначки
«висока впевненість» підтвердженням від власника або runtime verification.
Не вгадуй, які саме записи підтверджено чи спростовано.

Власник обрав cancellation через внутрішній flag без нового підстану.
План наступних змін ITask: `docs/audit/itask-evolution-plan.md`, етапи T00–T10.
Власник спочатку просив впроваджувати кожну зміну окремо, а згодом явно
доручив виконати T00–T10 послідовно без додаткового підтвердження. Завершуй
перевірку й документацію поточного етапу перед переходом до залежного;
не називай невиконані перевірки успішними. Незалежну роботу продовжуй при blocker.
Після review Task.CancelRequested/TaskQueue.CanStop внесено погоджене виправлення:
Task.Cancel одноразово викликає OnCancelRequested; TaskQueue передає child.Cancel.
Під час cancellation Task.handleRunning викликає OnCancelling замість OnRunning;
TaskQueue виконує тільки current child, а CanStop чекає її виходу з RUNNING.
Після зупинки child починається release parent; після STOPPED є RETURN.
Нові callbacks мають safe wrappers із logging exceptions. OF-004 виправлено
за статичним review; ST compilation і runtime regression ще не виконано.
Історичні докази та поточний статус: `docs/audit/of-004-cancel-flag-review.md`.

Перед висновком про дефект перевіряй контракт, callers, descendants, lifecycle,
особливості TwinCAT і допустимий сценарій використання. Відокремлюй:
підозру, статичний доказ, підтвердження власника та відтворення тестом.
Коли власник уточнює задуману логіку, збережи пояснення та статус конкретного
запису в findings.md; архітектурне уточнення внеси в architecture.md.
Виправлення коду виконуй у межах поточного запиту, не автоматично на підставі
попереднього аудиту.

## Перевірки

XML parsing/file existence не означають успішну ST compilation. Попередній
generic MSBuild attempt не дійшов до ST compiler через missing tsproj.metaproj;
TcUnit/runtime tests тоді не виконувалися. Актуальний стан перевіряй заново.
Не позначай невиконані тести або збірку успішними. Не активуй target чи
hardware configuration лише для читання та статичного аудиту.

## Актуальне продовження ITask після відкату

Власник відкотив масові T00–T10 зміни як надто складні й доручив поступову спільну
роботу. Попередня авторизація виконати всі етапи більше не актуальна. Поточний
запит — аналіз коду Task без внесення виправлень. Старі itask-contract/journal,
architecture supplements і statuses OF-004 описують попередні версії, не поточний
код. Актуальний review: docs/audit/task-review-after-rollback.md.
У поточному коді wrappers використовують references до enum/BOOL замість Task,
але _TaskStateChanged := taskStateChanged не прив'язує reference. Cancellation
знову використовує CanStop перед OnBeforeStop; OnCancelRequested/OnCancelling
відсутні. Немає нового public API або 22-test suite попередньої спроби.
Зберігати зміни власника. Кожне наступне виправлення спочатку обговорити окремо;
не починати автоматично старий великий план. Runtime після відкату не перевірявся.

2026-10-04: після окремого погодження додано Task.OnCancelRequest (PROTECTED,
порожній base hook), safeCallOnCancelRequest з exception logging, один виклик
у прийнятому Cancel після flag/reason. TaskQueue override одразу передає Cancel
active child. Старий OnBeforeStop збережено для інших stop paths. HandleRunning,
CanStop і public ITask не змінювали. Це частковий крок; cancellation wait ще
використовує звичайний OnRunning, повне виправлення не заявлено. XML/IDs і межі
зміни перевірено статично; ST compilation/runtime не виконано.

2026-10-04: окремо погоджено й додано Task.OnCancelling із safe wrapper та logging.
Під час cancellation він викликається перед CanStop; при false Execute повертається
без OnRunning/acquire. TaskQueue override виконує тільки running current child.
Після STOPPED додано RETURN. Public ITask та базовий OnStopped не змінювали.
Timer.Triggered тепер derived з stopped/stateChanged/final WorkDone/TON.Q;
Timer.OnStopped і локальний _Triggered прибрано. Сигнал до наступного Execute.
XML/IDs та межі правок перевірено статично; compiler/runtime не виконано.
Деталі й ручні сценарії: docs/audit/task-review-after-rollback.md.
2026-10-04: за окремим погодженням CanStop видалено з Task і TaskQueue.
OnCancelling тепер повертає VAR_OUTPUT readyToStop : BOOL; TRUE дозволяє
OnBeforeStop/release, FALSE продовжує cancellation wait. Base=TRUE;
Queue перевіряє child після Execute. Wrapper exception логується й явно дає
FALSE (попередню перевірку CanStop після exception більше не застосовувати).
Коментарі актуалізовано; XML/IDs/scope перевірено, ST/runtime не запускалися.
2026-10-04: Start preparation захищено від exception у ResourceManager і його
ResourceAcquired getter. setRunningState визначає підстан через локальний manager
до зміни lifecycle; RUNNING встановлюється після initialization. Start catch
повертає FALSE/refuseReason, READY зберігається при getter exception.
OnBeforeStart side effects не відкочуються. XML/scope перевірено статично;
ST compilation/runtime не запускалися. Деталі: task-review-after-rollback.md.
2026-10-04: наступне уточнення власника — не додавати TRY/CATCH для теоретичних
exception у простих ресурсних getters. Catch навколо setRunningState у Start
прибрано; порядок check/init перед RUNNING залишено. Контракт Task.ResourceManager:
ResourceManager та ResourceAcquired getters без side effects і без exceptions.
Safe wrapper OnBeforeStart збережено. Throwing-getter findings потребують
порушення цього контракту. Статичні checks виконано; ST/runtime не запускалися.
2026-10-04: погоджено мінімальне прибирання Task. OnStopped/safeCallOnStopped
вилучено; Execute лише скидає StateChanged та виконує RUNNING. Cancellation
без release повертається безумовно одразу після OnAfterStop (навіть якщо callback
зробив Reset); старий умовний STOPPED guard прибрано. Cancel unused locals
прибрано. Статичні XML/scope checks виконано, ST/runtime не запускалися.
