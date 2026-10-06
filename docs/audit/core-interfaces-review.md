# Core/Interfaces: оцінка дизайну, 2026-10-06

## Межі й підстави

Прочитано всі 13 TcIO у Core/Interfaces та підпапках. Зіставлено з вибраними
реалізаціями й callers у Core, Comparision, Collections, Tasks, Automation,
Devices.IO, FileSystem, Workflow і Tests. Це оцінка інтерфейсів, не повний
аудит усіх їхніх реалізацій. PLC-код не змінювався; перевірки не запускались.
Підстава висновків нижче — читання поточного коду (статичний аналіз), крім
явно зазначених уточнень власника. Відсутність тестів не є доказом дефекту.

Власник перед цим проходом повідомив, що перевірив попередні зміни Object,
memory/exceptions і вони працюють. Детального переліку виконаних сценаріїв
не надано: це не підтвердження всіх раніше запропонованих fault-injection cases.

## Оцінка всіх інтерфейсів

### IObject

Спільні метадані, діагностичне ім'я, identity та доступ до адреси/розміру.
Використовується memory/generics, logging і більшістю capability interfaces.
Поточні коментарі явно вимагають живого instance і не передають ownership.
SelfAddress повертає POINTER TO Object, тому абстракція прив'язана до конкретної
бази Object. Це свідомо можливий framework-компроміс, не незалежна універсальна
модель об'єкта. Не розділяти автоматично на багато дрібних interfaces.
Перевірки: metadata concrete descendant, identity і static/dynamic lifetime;
частина вже підготовлена в ObjectLifetimeTest. Попередню перевірку власника
не перетворювати на заяву про підтримку всіх target architectures.

### IExecutable

Execute без параметрів і результату — спільний крок виконання вже налаштованого
об'єкта. Реальні споживачі через ITask, IActivity, IWorkflow, ILogger та
IAutomationComponent; прямі реалізації також Stopwatch і LinearRamp.
Абстракція доречна: caller може просувати різні об'єкти без знання їхнього
налаштування. Вона не зобов'язана включати Start, Cancel чи стан завершення.
Контракт поки заданий лише сигнатурою. Потрібно погодити/описати bounded роботу
за виклик, відповідального за циклічний виклик, порядок IO, допустимість
повторного виклику в одному циклі та exception policy. Не приписувати всім
реалізаціям idempotence або гарантію «рівно один виклик за цикл» без погодження.
Перевірки: виконання через interface, idle state, кілька послідовних циклів;
повторні виклики в одному циклі — лише після визначення допустимості.

### INamed

Дає діагностичне/предметне ім'я незалежно від concrete type. Використовується
Object.GetName, Tasks, Automation, Workflow, action permissions і events.
Name : REFERENCE TO WSTRING повертає borrowed live storage, наприклад _Name
в AutomationComponent. Унікальність і стабільність імені не задані.
Невелика корисна абстракція. Reference зменшує копіювання, але не забезпечує
read-only доступу. Власник підтвердив: лише читання без копіювання. Запис через
reference порушує контракт; типова система його не забороняє. Не міняти
API на value-return без оцінки сумісності. Перевірки: empty name, зміна імені,
GetName fallback, lifetime збереженого reference.

### IErrorProvider

Надає HasError і live Error для діагностики AutomationComponent.
HasError обчислюється з _Error.HasError, тобто зараз це зручна похідна властивість,
а не окремий дубльований flag. Абстракція доречна, але Error повертає mutable
ERROR із Clear/SetSeverity: Get-only property не захищає внутрішній стан.
Сценарій: caller викликає provider.Error.Clear(), змінюючи повідомлення/HasError
без штатного lifecycle компонента. Власник підтвердив read-only контракт,
тому цей сценарій порушує правило використання, а не доводить дефект реалізації.
READ_ONLY_ERROR також має VAR_OUTPUT поля,
тому просте перейменування типу не гарантує незмінність.
Перевірки: HasError узгоджений з Error після встановлення/скидання, lifetime
reference; доступ на запис — відповідно до погодженого контракту.

### IIOBindable

Надає тільки BoundToIO, а не універсальну операцію Bind. У DigitalInput getter
перевіряє __ISVALIDREF(_RawValue); binding конкретних каналів залишається типізованим.
Це корисний мінімум: універсальна Bind потребувала б різнорідних IO-параметрів.
Потрібно пояснити, що binding не доводить справність обладнання або свіжість IO.
Ім'я трохи ширше за API; перейменування необов'язкове й ламає посилання.
Перевірки: до/після binding, кілька каналів із частковим binding у composite.

### ICloneable

Clone : IObject дає поліморфне копіювання. Використовується exceptions і
GenericValueFactory.FromParts. Сигнатура не визначає shallow/deep copy, тип
результату, null/failure policy, ownership чи lifetime. Це суттєва неоднозначність.
Конкретний конфлікт: GenericValueFactory.TcPOU:418 отримує Clone, а :426
позначає descriptor власником пам'яті. Exception clones мають AutoDisposeRegistrar
і погоджений виключний ownership DynamicMemoryManager. GENERIC_VALUE.Release
(:1503) може видалити той самий instance до cleanup реєстру.
Сценарій передачі exception у generic copying API несумісний із погодженим
ownership exception; загальний ICloneable не повідомляє caller про це.
Не називати це доказом дефекту за дозволеного використання, поки не визначено,
які Clone implementations допустимі для цього generic API.
Потрібно погодити єдине правило або явне обмеження споживача. Не вводити
автоматично нову ownership-ієрархію. Перевірки: independent identity, очікувана
глибина копії, рівно одне звільнення, життя після завершення циклу, OOM.

### IComparable

Задум — природний порядок, визначений самим об'єктом. Реалізацій і callers
у поточних ST sources пошуком не знайдено. Метод названо ComapreTo — очевидна
описка публічного API, не runtime-дефект. Параметр IComparable не гарантує
сумісності concrete types; потрібні правила для null, різних типів і порядку.
VAR_IN_OUT CONSTANT для невеликого interface handle не має встановленої
необхідності; заміна на VAR_INPUT була б зміною сигнатури.
Рекомендація: не розвивати без реального use case; окремо погодити виправлення
назви з урахуванням зовнішніх consumers. Перевірки: транзитивність, симетрія
знаку порівняння, null і несумісний тип у майбутній реалізації.

### IEquatable

Задум — рівність за змістом незалежно від IObject identity. Реалізацій і callers
у поточних ST sources пошуком не знайдено. Equals приймає IEquatable через
VAR_IN_OUT CONSTANT, тоді як IObject.Equals приймає IObject через VAR_INPUT.
Це дві несумісні сигнатури одного імені; їх сумісне застосування до Object
потребує окремого рішення, а не припущення про перевантаження TwinCAT.
Компіляторний сценарій у цьому проході не запускався, тому compiler defect
не заявляється. Крім того, IObject уже допускає override Equals, отже межа
двох абстракцій нечітка. Не розширювати до уточнення потреби й семантики.
Перевірки: рефлексивність, симетричність, транзитивність, null/інший тип,
узгодженість з Equals/CompareTo там, де вони описують ту саму рівність.

### IComparer

Зовнішня стратегія порядку, яку використовує List для search/sort. Це відмінна
від IComparable й виправдана відповідальність: порядок може залежати від caller.
AnyType дає універсальність через descriptor; типізація перевіряється не сигнатурою.
Наприклад IntComparer інтерпретує pValue як POINTER TO INT без перевірки
TypeClass/diSize. Це допустимо за передумови сумісних descriptor, але передумова
не записана в interface. Null у цьому comparer має визначений порядок.
Не додавати автоматично перевірки в кожен compare; спершу визначити межу
валідації. Перевірки: підтримані типи, null, знак/транзитивність, рівні значення;
для floating-point окремо визначити підтримку NaN.

### IPredicate

Check(AnyType) : BOOL — умова відбору; List.Find/RemoveAll отримують її як
залежність. Stateful predicate з еталонним значенням — нормальний дизайн.
Потрібен контракт підтриманих типів, lifetime descriptor/еталона і side effects.
Не припускати, що Check можна змінювати саму колекцію, яку зараз обходить caller.
SameDataPredicate перевіряє адресу й сумісність size/type, тому TRUE не завжди
означає однаковий зміст; це особливість конкретної стратегії, а не дефект IPredicate.
Перевірки: match/no match, налаштування еталона, термін його життя, допустимі типи.

### IEnumerable

Фабрика окремого cursor через CreateEnumerator : IEnumerator. Корисне
відокремлення collection від стану обходу. List.CreateEnumerator (:191) робить
NEW(ListEnumerator); сам ListEnumerator не містить AutoDisposeRegistrar.
Отже, припускати cycle auto-cleanup не можна. В interface не визначено owner
cursor, спосіб звільнення, failure policy, чи можливі незалежні cursors.
Контракт треба уточнити до заміни heap allocation іншою конструкцією.
Ціна поточного підходу — allocation на створення cursor; для циклічного PLC
це важливо, але не робить підхід автоматично неправильним.
Перевірки: два незалежні cursors, empty source, звільнення cursor, OOM.

### IEnumerator

MoveNext/Current/Reset — зрозуміла модель обходу. Reset явно обіцяє позицію
перед першим елементом. Current є reference до mutable GENERIC_VALUE,
а backing storage і його lifetime відрізняються між реалізаціями.
ListEnumerator повертає власний scratch descriptor, скопійований із List.Get;
StringSplittingEnumerator — descriptor буфера, який видаляється при MoveNext.
Збереження Current.Address через наступний MoveNext не є загальною гарантією.
Потрібно визначити Current до/після обходу, mutation source, право викликати
Current.Release і тривалість життя запозичених даних. Не вимагати fail-fast
version counter без потреби — заборона mutation може бути достатньою.

Підтверджена статичним аналізом невідповідність реалізації: StringSplittingEnumerator
(:183) і WideStringSplittingEnumerator (:187) у Reset копіюють байти через
MEMCPY(_CurrentString, SourceString, SourceStringSize) замість відновлення cursor.
Після проходу останнього елемента MoveNext встановлює _CurrentString := 0.
Дозволений сценарій: завершити обхід, Reset, MoveNext. Cursor лишається 0,
тому повторний обхід не починається. Після часткового обходу Reset додатково
втрачає адресу _CurrentEntry без звільнення. Runtime тут не запускався.
Мінімальне майбутнє виправлення: відновлення cursor і коректне звільнення
поточного буфера; public API не потрібно змінювати. Потрібне окреме погодження.
Існуючі StringHelperTest/WideStringHelperTest перевіряють forward splitting;
у прочитаних сценаріях немає повторного обходу після Reset. Додаткові сценарії:
Reset до першого MoveNext, посередині, після кінця, двічі; empty/end Current.

### IResourceManager

AcquireResource/ReleaseResource просувають операцію, ResourceAcquired повідомляє
стан, GetResource повертає предметний ресурс як IObject. Для Task асинхронний
acquire/release через повторні цикли виправданий, відсутність BOOL-результату
не є сама по собі недоліком. Release contract уже описує terminal exception
і погоджений best-effort cleanup; це зберегти.
Невизначені частини: один чи кілька clients, право чужого client на release,
GetResource до acquire, ownership/lifetime returned resource. FileHandleResourceManager
має один загальний стан, повертає власний _FileHandleResource і не використовує
client для арбітражу. Не вважати цей interface mutex чи multi-client manager.
Мінімум — контракт одного активного client, якщо власник підтвердить цей задум;
не додавати lock/token/queue наперед. Getters без side effects/exceptions уже
погоджені для використання Task. Перевірки: delayed acquire/release, exception,
повторні виклики, best-effort close, lifetime handle; shared clients — лише якщо дозволені.

## IStartable та ICancellable

Не існує вимоги виносити кожне дієслово в окремий interface. Потрібні конкретний
поліморфний consumer та однаковий поведінковий контракт, а не лише однакове ім'я.
У цьому коді ITask.Start (:137) повертає BOOL/refuseReason, LinearRamp.Start
(:163) приймає startValue/endValue/transitionTime/targetVariable, Stopwatch.Start
не має параметрів, IActivity.RequestStart також має окремий lifecycle.
ITask.Cancel повертає прийняття запиту; IActivity.RequestCancel приймає reason.
Тому універсальні Core IStartable/ICancellable наразі не обґрунтовані.

Для об'єктів із предметними параметрами типізований Start(position, velocity)
є нормальним API. Для TaskQueue підготовка до запуску може бути окремою
ConfigureMove(position, velocity), після якої стандартний ITask.Start запускає
підготовлену команду. Це альтернативи за потребами caller, не обов'язкова міграція.
Configure+Start потребує визначити snapshot параметрів, відмову без підготовки
і право змінювати їх під час RUNNING. Не запроваджувати ANY або dictionary параметрів
лише заради спільного Start. Command object також не потрібен без реальної потреби.

ICancellable легше уніфікувати за параметрами, але не за змістом: запит чи
негайне завершення, чи допускається відмова, повторення, Execute для завершення,
стан/результат після cleanup. TaskQueue уже використовує ITask і потребує
більше ніж Cancel; виділення окремого interface не спростить її автоматично.
Рекомендація — поки зберегти поточний поділ і повернутися до малих interfaces,
коли з'явиться consumer, якому справді потрібна лише ця одна можливість.

## Питання власнику і наступні кроки

Власник підтвердив: Name/Error повертають references лише для читання без копії.
Це дозволяє залишити сигнатури й описати заборону запису; технічного const-захисту
вони не дають. Власник також пояснив: Clone лише створює копію і сам не повинен
знати про ownership. Це не означає, що будь-який consumer автоматично отримує
право видалення. Потрібне окреме рішення щодо припущення GenericValueFactory
про ownership результату, без обов'язкового додавання ownership flags до Clone.
Окремо надалі
потрібні owner/lifetime enumerator та допустимість кількох resource clients.
Перший пріоритет обговорення — Clone ownership, потім enumerator lifecycle/Reset.
Рекомендації не є дозволом змінювати код.

Технічна підстава для REFERENCE TO: Beckhoff описує, що з build 4022 присвоєння
значення reference property використовує Get accessor; Get-only не є const.
https://infosys.beckhoff.com/content/1033/tc3_plc_intro/2530335371.html
