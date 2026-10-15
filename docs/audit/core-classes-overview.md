# Статус цього попереднього огляду — 2026-10-16

Збережено для кандидатів поза погодженим Objects scope. Це snapshot 2026-10-07,
не поточний список дефектів. CC-01 (Event), CC-03 (builders) та CC-05 (Clone)
пізніше опрацьовані; interfaces, memory, System, Actions/Events та Exceptions
мають нові рішення в core-contracts.md і exceptions-status.md. Старі counts,
назви видалених типів і file/line references не використовувати без звірення.
CC-02/04/06/07 та інші питання потребують актуального окремого review.
Наведений нижче старий порядок діалогів не є дозволом на зміни.

# Core: огляд класів перед поштучним обговоренням

Дата: 2026-10-07. Поточний HEAD під кінець читання: a7fe757.

## Межі та підстави

Інвентаризація поточних TcPOU: 51 FUNCTION_BLOCK і 36 PROGRAM.
Класами в цьому огляді вважаємо FUNCTION_BLOCK, включно з abstract/internal.
PROGRAM — окремі службові об'єкти: прочитано пов'язані з класами шляхи у
GenericValueFactory, Strings/WideStrings, LogManager, System та Random;
це не повний аудит усіх 36 utilities або всіх числових конвертацій.
Для великих класів читання зосереджено на lifecycle, ownership, основних
операціях і знайдених проблемах; вичерпна перевірка кожної гілки не заявляється.
Object, memory і exceptions зіставлено з попередніми погодженнями; їхній
попередній runtime результат власника не поширюємо на нові сценарії.
Код, контракти біля декларацій і тести цього разу не змінювалися.
Compilation, runtime, XML validation та check-скрипти не запускалися.
Усі нові висновки — статичний аналіз. Нових підтверджень задуму від власника немає.

## Загальна оцінка

Основні абстракції доречні. Потреби в перебудові Core або новій ієрархії не видно.
Найбільша практична небезпека — локальні помилки одиниць розміру, граничних
значень, типу Clone і непрописані правила користування borrowed/owned даними.
Динамічні builders зручні для діагностики, але allocation і копіювання мають
змінну ціну в PLC-циклі; це компроміс, а не доказ непридатності концепції.

| Класи | Задум і дизайн | Результат першого проходу / предмет діалогу |
|---|---|---|
| Object | Спільна identity, metadata і доступ для framework memory API | Доречна база; зберігаємо погоджені lifetime правила, не повторюємо рефакторинг |
| AutoDisposeRegistrar, MemoryCleanupHelper | Прив'язка dynamic exceptions до cycle cleanup і cleanup при завершенні | Допоміжні типи виправдані погодженою моделлю; загальне auto-ownership не розширювати |
| Event | Джерело події й позначка обробки | CC-01; уточнити одноразовість instance, lifetime SourceObject і значення Handled |
| SimpleEvent | Іменована подія без окремого payload-класу | Корисний мінімум; успадковує CC-01, окрема перебудова не потрібна |
| SimpleActionDescriptor | Іменований descriptor для permission checks | Чітка відповідальність; уточнити identity vs однакові імена, borrowed lifetime |
| AllowAllActionsPermissionsPolicy, DenyAllActionsPermissionsPolicy | Взаємозамінні стратегії дозволу | Проста виправдана реалізація; правила null arguments і rejectReason описати |
| IgnoreExceptionHandlingPolicy, SetErrorAndContinueExceptionHandlingPolicy, SetErrorAndStopExceptionHandlingPolicy | Обирають реакцію на exception | Доречні stateless стратегії; повертають enum, самі не зупиняють компонент і не записують ERROR |
| Exception, GeneralException, AggregateException, EmptyException, SystemException | Ієрархія діагностичних подій і native wrapper | Зберігаємо попередні погодження про цикл, clones, timestamps, 255 entries; залежність форматування від builders лишається суттєвою |
| Конкретні GeneralException descendants | Типізовані причини помилки і формування повідомлення | Не прибирати типи лише через схожість коду; CC-05 в одному Clone |
| READ_ONLY_ERROR, ERROR | Знімок помилки, який може пережити цикл | Доречне відокремлення стану від exception; READ_ONLY — дисципліна API, VAR_OUTPUT не робить дані immutable; HasError зараз визначений повідомленням |
| GENERIC_VALUE | Descriptor type/address/size/ownership, доступ і копіювання | Потрібний для generic containers; передача descriptor не дорівнює незалежній копії ресурсу; Reset відкидає descriptor, Release спочатку звільняє owned memory |
| GenericValueValidator | Перевірка дозволеного GENERIC_TYPE_CLASS | Чіткий вузький обов'язок; не перевіряє lifetime/address/size, не називати повним валідатором пам'яті |
| StringBuilder, WideStringBuilder | Накопичення різнотипних значень у динамічному рядку | Задум доречний; CC-03/04; також обговорити 255-character проміжний буфер кожного Append |
| StringSplittingEnumerator, WideStringSplittingEnumerator | Послідовне отримання фрагментів borrowed source | Погоджений Reset збережено; CC-02/04; уточнити empty/trailing separator/maxCount, не повертатися автоматично до відхиленої оптимізації буфера |
| LinearRamp | Циклічний перехід від початкового до кінцевого значення | Зручний Start + Execute; CC-06, lifetime target reference і поведінка при пропущених Execute потребують опису |
| Stopwatch | Накопичений час із Start/Stop/Reset, напрямком і persistence | Корисна abstraction; визначити момент вимірювання Stop, persistence під час активного відліку, перемикання режимів |
| DeadbandHysteresis | Порогове перемикання зі збереженням стану | Простий доречний клас; негативний deadband, equality та NaN потребують контракту; новий enum станів не потрібен |
| AdsLogger | Адаптер ILogger до ADS log | Доречний тонкий adapter; CC-07 щодо номера; довгі/Unicode повідомлення обмежені перетворенням у STRING(255) |
| NamespaceExtractor | Отримання namespace через compiler attribute | Мінімальний технічний helper, перебудова не потрібна |

## Конкретні знахідки

### CC-01 — Event.SourceObject не повертає збережене джерело

Статично підтверджена помилка реалізації.
[Event](../../Sources/TwinCAT.OpenFramework.Core/Objects/Events/Event.TcPOU):
FB_init записує _SourceObject (рядок 37), але getter SourceObject порожній (64).
Сценарій: створити SimpleEvent із чинним ненульовим sourceObject і прочитати
SourceObject. Getter не повертає передане джерело. FINAL не дозволяє нащадку
виправити getter override. Прямих споживачів SourceObject у Sources пошуком
не знайдено, але це допустимий public API сценарій; поточний impact на програму
користувача не заявляється. Мінімально — повернути _SourceObject після погодження.
Перевірка: null/non-null source, identity, незалежність від SetHandled.
Окреме питання контракту: Handled не скидається; чи кожний instance одноразовий?
В Automation stopPropagation передається окремо — не ототожнювати ці ознаки.

### CC-02 — WideStringSplittingEnumerator: символи використані як байти

Статично підтверджена помилка розміру останнього фрагмента.
[MoveNext](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Strings/WideStringSplittingEnumerator.TcPOU):151:
у гілці без separator size і MEMCPY дорівнюють _CurrentStringLength + 2.
Довжина отримана через WLEN2 і вимірюється символами. Для "ABCD" без separator
виділяється й копіюється 6 байтів замість 10. Копія не містить усього рядка
та його terminator; наступне читання як WSTRING може вийти за виділений фрагмент.
Та сама помилка в SourceStringSize при Initialize, хоча це поле не керує цією
алокацією. Мінімум — узгодити формули (length + 1) * CharSize, без зміни алгоритму.
Підстава: код та офіційні WLEN2/WSTRING docs:
https://infosys.beckhoff.com/content/1033/tcplclib_tc2_utilities/3483045003.html
https://infosys.beckhoff.com/content/1033/tc3_plc_intro/2529437323.html
Наявний WideStringHelperTest.Split закінчує приклад односимвольним "0";
це не покриває довільний багатосимвольний хвіст. Перевірити "ABCD", "A,BCDE",
багатосимвольний separator, trim і повторний Reset. Наявність тесту не означає,
що його виконували в цьому проході.

### CC-03 — builders двічі враховують terminator у AssignToString

Статично підтверджена помилка граничної місткості.
[StringBuilder](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Strings/StringBuilder.TcPOU):151,323
і [WideStringBuilder](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Strings/WideStringBuilder.TcPOU):151,322.
StringRealSize вже містить terminator, але перевірка додає ще STRING_CHAR_SIZE;
після копіювання цього розміру записує ще один terminator.
Сценарій: AppendString255('A') та AssignToString у STRING(1). Два байти достатні,
але метод вимагає три і кидає exception. Аналогічно WSTRING(1): достатньо 4,
метод вимагає 6. Це зайве відхилення, а не доведений buffer overflow: поточна
перевірка якраз резервує місце для зайвого запису.
Мінімум — одна узгоджена формула й один terminator. Окремо обробити builder
без алокації, щоб не покладатися на MEMCPY з null source.
Є StringBuilderTest/WideStringBuilderTest: normal, empty, wrong type, short target.
Додати exact fit, на один символ менше, порожній після Clear(TRUE/FALSE).

### CC-04 — неперевірені allocations у builders/splitters і generic factory

Статично підтверджений незахищений failure path, runtime не відтворювався.
Builders InternalAppend одразу використовують newString після NEW, потім можуть
видалити старий буфер і записати позитивну capacity при null pointer.
Обидва splitting enumerators використовують новий fragment у MEMCPY/MEMSET/
Trim без guard. GenericValueFactory.FromParts:430–431 також копіює в результат
NEW без guard. При вичерпанні heap це обходить погоджений fatal allocation latch.
Мінімум — існуючий RaiseAllocationFailure до будь-якого використання результату,
зі збереженням старого стану до успішного allocation. Погоджувати окремо для
кожного класу; не вносити масовий patch автоматично.
Потрібні fault-injection сценарії; відсутність тестів не є підставою цього висновку.

### CC-05 — DataMemberTypeNotSupportedException.Clone змінює тип

Статично підтверджена помилка реалізації.
[Clone](../../Sources/TwinCAT.OpenFramework.Core/Objects/Exceptions/General/DataMember/TypeNotSupported/DataMemberTypeNotSupportedException.TcPOU):30–36
декларує pointer і створює DataMemberTypeClassNotSupportedException.
Сценарій: Clone чинного DataMemberTypeNotSupportedException; отриманий об'єкт
має інший ClassName і інший спеціалізований interface. Відбір handler через
IDataMemberTypeNotSupportedException перестає відповідати початковому типу.
Загальні поля копіюються, але це не виправляє підміну типу. Мінімум — правильний
pointer/NEW type. Це нова знахідка поза раніше підтвердженими runtime сценаріями.
Перевірка: clone identity відрізняється, concrete type/interface і metadata збережені.

### CC-06 — LinearRamp: завершення та RemainingTime

Статичні неузгодженості lifecycle/output; точний контракт слід погодити.
[Execute](../../Sources/TwinCAT.OpenFramework.Core/Utilities/Ramp/LinearRamp.TcPOU):107–125
обнуляє RemainingTime лише при overshoot, але не при точному досягненні target.
Сценарій: крок 10 ms, 0→2 за 20 ms. Після двох результативних ticks значення 2,
Done=TRUE, але RemainingTime=10 ms. Мінімум — єдина finalization при досягненні
або перетині target. Start із transitionTime=0 записує target, але не скидає/
завершує timer; на свіжому instance Done лишається FALSE, на повторному старті
результат залежить від старого timer state. Це потребує явного правила zero-time.
Також обговорити start=end, повторний Start під час Busy, пропущені цикли,
запис у targetVariable ззовні та lifetime reference. Не вводити складний scheduler.
Перевірки: точне досягнення, overshoot, обидва напрями, zero time і restart.

### CC-07 — AdsLogger: номер губиться для одноелементного aggregate

Статично видно: гілка InnerExceptionCount=1 у TryLogException не передає
messageNumber у TryLogMessage, хоча звичайна і багатоелементна гілки передають.
Наслідок — номер, наданий LogManager, відсутній лише для такого aggregate.
Узгодити, чи це навмисний формат; якщо ні — додати аргумент, без нової абстракції.
Перевірка: numbered logs для звичайного, порожнього, одного й кількох entries.
Статус — неузгодженість для уточнення контракту форматування, не runtime доказ.

## Питання контрактів, які не називаємо дефектами

- GENERIC_VALUE: plain assignment копіює ownership flag і адресу; потрібні правила
  aliasing/передачі ownership. Reset і Release мають різні призначення. Не вводити
  RAII або automatic deep copy без погодження. Старий OF-007 не перевідкривати
  автоматично; raw cloning FB потребує окремої дозволеної роботи.
- READ_ONLY_ERROR: fields VAR_OUTPUT; read-only — правило користування, не захист
  типом. HasError залежить від TopMessage, не від Severity. Це може бути доречним.
- Builders: Append будь-якого значення проходить через STRING/WSTRING(255),
  тому динамічний загальний буфер не означає довільну довжину одного фрагмента.
- Splitters: trailing empty entry зараз не повертається; MaxCount зупиняє обхід,
  а не обов'язково повертає залишок останнім фрагментом. Спочатку уточнити задум.
- Stopwatch: Stop читає вже наявний ET, сам перед цим timer не оновлює; persistence
  saved time оновлюється при Stop, не при кожному Execute. Чи це бажана точність
  і поведінка при втраті живлення — питання контракту, не доведений дефект.
- DeadbandHysteresis: немає перевірки negative deadband/NaN; дозволений діапазон
  визначити перед додаванням guard. Equality на порозі також записати явно.
- Глобальні службові PROGRAM: потрібно визначити дозволений task/thread model;
  відсутність locks сама по собі не доводить дефект при single-task використанні.

## Порядок наступних діалогів

Event → SimpleEvent → SimpleActionDescriptor → permission policies →
READ_ONLY_ERROR → ERROR → GenericValueValidator → GENERIC_VALUE з factory →
StringBuilder → WideStringBuilder → StringSplittingEnumerator →
WideStringSplittingEnumerator → LinearRamp → Stopwatch → DeadbandHysteresis →
AdsLogger → exception policies → конкретні exception descendants (почати з CC-05).
Object і memory helpers не перебудовувати; при їхньому повторному обговоренні
лише звірити погоджений контракт. Повний аудит службових PROGRAM — окрема група.
Кожен діалог: призначення, контрактні питання, мінімальна правка за погодженням,
DocGen і короткий запис рішення/статусу перевірок.
