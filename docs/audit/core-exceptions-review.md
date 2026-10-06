# Core exceptions — невелика група 2, 2026-10-06

Нижче збережено перший статичний прохід до виправлень. Актуальний статус
погоджених змін E01–E03 наведено в кінці документа.
Поточний checkout містить погоджені зміни першої групи Core; старі exports
не вважаються еквівалентом sources. ST compilation/runtime не виконано.

## Точний склад і межі

П'ять declarations: IReadOnlyException, IException, Exception, ExceptionManager,
SystemException. Останній необхідний у групі, бо manager безпосередньо містить
його instance; він EXTENDS Object, а не Exception. ICloneable, GeneralException,
AggregateException, ExceptionTest і Automation callbacks прочитані як dependencies
та callers. Повний аудит усіх concrete exception subclasses сюди не входить.

## Призначення, дизайн і фактичний контракт

### IReadOnlyException

Інтерфейс читання діагностики: message, source, timestamps, root, ToError.
Використовується споживачами діагностики та є базою IException. Поділ читання
і Clear доречний, але назва не гарантує immutable snapshot: source properties
повертають references до storage, GetRootException повертає mutable IException,
а Clone може виділяти пам'ять. Це компроміс API, не доказ дефекту.
Явно задано inheritance IObject/ICloneable, сигнатури й default display mode.
Lifetime і ownership Clone в інтерфейсі не задані; не переносимо автоматично
правила Exception на будь-яку незалежну реалізацію IException.
Мінімальне покращення після погодження — опис borrowed lifetime біля декларації,
без зміни типів return. Перевірки: незалежність snapshot лише там, де її обіцяє
конкретний Clone; поведінка references після Clear без доступу після delete.

### IException

Додає Clear до IReadOnlyException: дозволяє повторно конфігурувати статичні
instances і очищати діагностичний стан. Абстракція мала й виправдана.
Clear за implementations не означає delete і не продовжує lifetime borrowed
references. Що саме лишається після Clear, залежить від implementation:
SystemException скидає тільки code; Exception — source і timestamps.
Мінімально потрібен спільний опис Clear після погодження, без додаткових flags.
Перевірки: повторний Clear, Empty/GetMessage після Clear конкретних класів.

### Exception

Abstract base звичайних framework exceptions: зберігає source/timestamps,
дає formatting і ToError, вимагає concrete Clone/Empty/GetMessage/root.
AutoDisposeRegistrar включений у instance; dynamic descendants мають cycle
lifetime і виключного owner DynamicMemoryManager за підтвердженим контрактом.
Статичний instance не реєструється. FB_exit викликає Clear; descendants мають
зберігати no-exceptions і non-reentrant cleanup правила першої групи.
Поділ спільних metadata та specific payload доречний. Abstract Clone : IObject
потребує дисципліни нащадків: callers очікують IException після query.
Поточні helpers і source-length limits не перебудовуємо заради стилю.
Підтверджена статично помилка formatting E02 нижче.
Перевірки: відмінні local/UTC значення, HIDDEN/LOCAL/UTC, Clear і clone payload.

### ExceptionManager

Глобальний міст між native exception code та framework payload. Throw(null)
нічого не робить. Dynamic payload зберігає напряму; static клонує і query-cast
до IException. GetLastException для framework code повертає _Exception,
для інших кодів налаштовує спільний _SystemException. Cleanup лише скидає
_Exception; owner зареєстрованих objects — DynamicMemoryManager.
Runner викликає ExceptionManager.Cleanup перед DynamicMemoryManager.CleanupMemory.
GetLastException не споживає slot. Спільний SystemException змінюється при
наступному system catch; це borrowed view, а не стабільний snapshot.
Коментар про default EmptyException суперечить поточній реалізації.
Один global slot простий для одного послідовного PLC task, але не є stack
вкладених exceptions і не надає isolation між tasks. Підтримка multitask не
підтверджена власником. Не вводимо stack/locks без вимоги.
Перевірки: static/dynamic Throw, null, native після framework, nested catch,
повторний throw, cleanup ordering. E03 потребує уточнення контракту.

### SystemException

Adapter native exception code до IException; manager тримає один static instance.
Configure зберігає code і catch point. GetMessage показує catch point навіть
без showSource, бо точне source native exception невідоме. Source getters
повертають unspecified storage; timestamps читають поточний системний час,
а не збережений час catch. Це окремі семантичні обмеження, не підтверджені баги.
Clone створює dynamic SystemException і копіює лише code: catch point губиться,
timestamps лишаються live. __NEW не перевіряється на 0. Registrar відсутній.
Окремий adapter без allocation для GetLastException доречний, але Clone не
узгоджений із фактичними callers (E01). Не потрібно міняти base class без
оцінки virtual methods і layout; можливий малий крок — registrar у цьому класі.
Перевірки: snapshot code/catch point, ownership clone, нульовий allocation.

## Знахідки і мінімальні наступні кроки

### E01 — SystemException clone втрачає owner

Підтверджена проблема за статичним аналізом допустимого caller path:
system catch → GetLastException повертає static SystemException →
AggregateException.AddInnerException клонує його → aggregate.Clear видаляє
тільки масив, а SystemException clone не зареєстрований і не видаляється.
Повторення в наступних циклах накопичує незвільнені allocations.
Runtime-відтворення не виконано. Відсутність тесту не є підставою висновку.

Код: System/SystemException.TcPOU, Clone; Aggregate/AggregateException.TcPOU,
AddInnerException/Clear; ExceptionManager.TcPOU, GetLastException.
Пропозиція до погодження: включити AutoDisposeRegistrar у SystemException,
щоб clone мав такий самий owner, як framework exceptions. Окремо погодити
копіювання catch point і allocation failure policy. Ціна: змінений instance
layout, тому потрібна перебудова залежних бібліотек. Не додавати ручне видалення
inner exceptions: це суперечило б ownership уже зареєстрованих descendants.

### E02 — UTC formatting використовує local timestamp

Exception.TcPOU, AppendTimestampDescription: UTC branch читає localTimestamp,
хоча caller передає окремий utcTimestamp. При різних значеннях показує local
час у UTC mode. Доданий UTC suffix далі проходить WLEFT(..., 22), тому не має
гарантії збереження. GeneralException.GetMessage і AggregateException.GetMessage
використовують helper. Статично підтверджено; runtime не виконано.
Мінімальна пропозиція: utcTimestamp у UTC branch, suffix після обрізання дати.
Сигнатура/layout не змінюються; зміниться очікуваний текст діагностики.
Погодження запитано. Тест: детерміновані різні timestamps та перевірка suffix.

### E03 — ReThrowLastException не знає поточний caught code

Manager вибирає _Exception, якщо він не null, інакше _SystemException.Code.
Leaf.Enable/Disable викликають його з __CATCH без GetLastException і caught code.
При native exception у OnEnable може повторно підняти старий framework code
або старий system code. Навіть після GetLastException(nativeCode) попередній
_Exception не очищається і має пріоритет у ReThrowLastException.
Поведінку доведено статично; власник підтвердив: повторно піднімається саме
поточний caught exception, включно із системним. Це підтверджує дефект
відносно задуманого контракту. Runtime не виконано.
Запропоновано передавати caught code явно; не вводити stack exceptions.
Повний пошук знайшов 14 callers: 4 Leaf/Branch, 6 Collections, 4 Workflow.
У трьох Workflow handlers OnFail виконується у вкладеному TRY/CATCH перед
rethrow. Він може замінити global framework payload. Самого caught code для
збереження початкового payload у цьому випадку недостатньо: потрібен також
збережений IException. У Workflow він уже є в локальній змінній exception.
Перед правкою потрібна сумісна стратегія API і перевірка native/framework
rethrow після вкладеного exception; лише заміна чотирьох callers неповна.

## Наявні тести і статус

Конкретна пропозиція E03 до погодження:

```structuredtext
METHOD ReThrowLastException
VAR_INPUT
    exceptionCode : __SYSTEM.ExceptionCode;
    exception : IException := 0;
END_VAR
```

Метод піднімає переданий code. Лише для framework code (включно з уже наявним
compatibility code 3902013441) ненульовий exception відновлює _Exception перед
raise. Для native code payload ігнорується. Callers без проміжних callbacks
передають code; Workflow передає code та локальний exception. Global slots
не перетворюються на stack. Legacy calls без code більше не відповідають
контракту; ST input omission не вважається runtime validation аргументу.

Мінімальні regression scenarios E03: native rethrow після framework throw
у тому самому циклі; framework rethrow зі збереженням identity; framework A,
вкладений caught B, потім rethrow A зі збереженим interface. В усіх тестах
assert caught flag поза catch, щоб відсутність exception не давала false pass.

ExceptionTest викликає SimpleException, StandardExceptions, AggregateException.
Це корисна regression основного framework path. У перевіреному suite немає
сценаріїв native rethrow, SystemException clone ownership та UTC formatting.
Наявні assertions здебільшого всередині catch: якщо очікуваний throw не стався,
деякі тести можуть дійти до TEST_FINISHED без перевірки caught flag. Це слабкість
тесту, не доказ дефекту production code. Посилення — окремий малий крок.

На завершення першого проходу exception code не редагувався. Питання E02 надіслано власнику;
контракт E03 підтверджено, scope виправлення уточнено до 14 callers.
E01 підготовлено для окремого рішення. XAE встановлений, але старі audit exports
не підтверджують current build. Збережено попередню домовленість про ручний
запуск власником; configuration/target не активовано.

## Робочий журнал виправлень — 2026-10-06

Після review власник доручив продовжити виправлення; окремо підтвердив
terminal allocation policy для SystemException.Clone. Виконано послідовно:

1. E02: UTC branch використовує utcTimestamp, suffix додається після WLEFT.
   LOCAL/HIDDEN і сигнатури не змінено.
2. E03: ReThrowLastException приймає caught code і optional saved IException.
   Піднімає саме переданий code; saved payload відновлює лише для framework
   codes. Оновлено всі 14 production callers. Чотири Workflow calls передають
   локальний exception; інші передають code, отриманий у їхньому __CATCH.
   Nested handlers, state transitions і release algorithms не перебудовано.
   GetLastException отримав опис shared borrowed system instance замість
   застарілої згадки EmptyException.
3. E01: SystemException містить AutoDisposeRegistrar; dynamic instances тепер
   належать DynamicMemoryManager. Clone копіює code та три catch-point fields.
   Live-clock timestamps збережено. Null __NEW перевіряється до dereference.
4. Allocation failure: новий INTERNAL DynamicMemoryManager.RaiseAllocationFailure
   встановлює existing latch і викликає RaiseIfAllocationFailed. Registry guard
   та SystemException.Clone використовують цей спільний шлях без heap exception,
   logging або cleanup. Runner boundary check з C02 не змінено. Інші __NEW у
   descendants цим не виправлено. Після latch normal resume не підтримується.

Сумісність: зовнішні ReThrowLastException callers мають передавати caught code;
omitted input не перевіряється спеціальним runtime guard. SystemException layout
змінився; потрібна перебудова залежних бібліотек. Dynamic SystemException більше
не можна видаляти вручну або передавати іншому owner. У перевірених sources
таких прямих delete/adoption paths не встановлено; зовнішні callers невідомі.

Додано чотири TcUnit methods до ExceptionTest (тепер 7 викликаних сценаріїв):

- RethrowSavedFrameworkException: A, nested caught B, rethrow saved A, identity
  перевіряється після outer catch; caught flag виключає pass без exception.
- RethrowNativeAfterFramework: old framework slot, synthetic native OUT_OF_MEMORY,
  rethrow з перевіркою code і caught flag. Це не memory exhaustion і не latch test.
- TimestampFormatting: static ExceptionTimestampProbe відкриває protected helper;
  задано різні local/UTC literals, перевіряються HIDDEN, LOCAL, UTC і suffix.
- SystemExceptionClone: code/catch-point snapshot зберігається після зміни shared
  system instance. Clone не видаляється вручну. Цей тест сам не доводить cleanup.

Перевірено статично: XML усіх змінених sources, збереження existing IDs
(крім погодженого раніше видалення IsMemoryValid), унікальність test IDs,
наявність Compile paths, виклик/TEST_FINISHED нових методів, 14 оновлених
production callers і відсутність старих ReThrowLastException() calls.
git diff --check пройдено після очищення trailing whitespace на змінених рядках.
ST compilation, actual placeholder resolution і TcUnit/runtime НЕ виконано.

Ручні сценарії, що залишаються: SystemException clone у aggregate видаляється
рівно раз наприкінці циклу; не повертається memory growth у циклі clone/cleanup.
Для null-allocation path використовувати тимчасову заміну саме __NEW на 0,
а не обнулення успішного allocation. Перевірити latch, native code та runner
re-raise на ізольованому target; після тесту повернути source і переініціалізувати.
Library rebuild: Core, залежні Collections/Automation/Workflow і Tests з resolution
на нові sources. Жодного target/configuration activation агент не виконував.

## Послідовний план, пункт 1 — завершено статично, 2026-10-06

Власник визначив timestamps як час створення exception, не час читання;
для native окремо погодив час GetLastException (native Throw time недоступний).
SystemException.Configure тепер фіксує local/UTC fields, getters читають fields,
Clone копіює їх без зміни, Clear скидає до MIN_VALUE. Це замінює попередній
live-clock контракт у журналі вище. SystemExceptionClone перевіряє timestamps.
IReadOnlyException/IException, Exception/ExceptionManager/SystemException
отримали описи borrowed storage, Clear без delete, clone ownership і cleanup.
XML перевірено статично; compilation/runtime ще не виконано. Далі пункт 2.

## Виправлення тесту після запуску власником — 2026-10-06

Власник повідомив runtime failure RethrowNativeAfterFramework: перевірка
`outerCode = RTSEXCPT_OUT_OF_MEMORY` після ENDTRY дала FALSE. Сам факт
отримання exception пройшов відповідний assertion; фактичний код у повідомленні
не відображався. Це не є доказом дефекту ReThrowLastException.

Причина помилкової перевірки встановлена за кодом тесту та документацією
[Beckhoff TRY/CATCH](https://infosys.beckhoff.com/content/1033/tc3_plc_intro/2529187211.html):
змінна CATCH повертається до RTSEXCPT_NOEXCEPTION після обробки. Тест тепер
зберігає outerCode в savedOuterCode всередині CATCH і перевіряє збережене значення
після ENDTRY. AssertEquals_UDINT показуватиме числові expected/actual коди
замість BOOL. Production implementation не змінено. Повторний запуск власником
ще потрібен; агент compilation/runtime або check-скриптів не запускав.

Наступний запуск власником: expected 28 (OUT_OF_MEMORY), actual 3902013441.
Збереження outerCode не усунуло failure: попереднє пояснення про reset catch
не є повним поясненням спостережуваного результату. Код 3902013441 уже обробляється
ExceptionManager як framework code із історичною приміткою про 3.1.4026.19;
сам збіг не доводить ні версію target, ні причину підміни.

Тест доповнено збереженням коду першого catch. Окремі assertions вимагають
OUT_OF_MEMORY від первинного F_RaiseException і тотожності кодів inner/outer
catch під час rethrow. Вимогу отримати 28 не послаблено. Це діагностична зміна,
а не заявлене виправлення production: потрібен результат власника й версії
Runtime/Tc2_System. Якщо первинний raise вже дає workaround code, native-сценарій
не відтворюється і його не можна позначати перевіреним. Також тоді потребуватиме
розгляду розпізнавання native помилок після framework payload у GetLastException.
Агент перевірок не запускав.

Результат наступного запуску власника на TwinCAT 3.1.4026.27:
`Initial F_RaiseException must deliver OUT_OF_MEMORY before rethrow`,
expected 28, actual 3902013441. Отже, відхилення спостерігається вже в першому
CATCH, до виклику ReThrowLastException. Версію resolved Tc2_System власник
ще не надав. Це runtime-доказ підміни коду на первинному raise/catch шляху
в цьому оточенні; конкретний внутрішній дефект TwinCAT або бібліотеки не
встановлений. Нового повідомлення про невідповідність inner/outer кодів
не надано, але native rethrow із початковим кодом 28 залишається неперевіреним.

Тест не послаблюємо прийняттям 3902013441 як OUT_OF_MEMORY: цей самий код
використовує framework compatibility path, тому така заміна приховала б
неоднозначність. GetLastException за поточним кодом може повернути попередній
framework payload, якщо отримує цей код і _Exception ненульовий; для
спостережуваного synthetic raise це тепер конкретний допустимий сценарій.
Fatal allocation latch окремо зберігає факт нестачі пам'яті, але точне
доставлення native OUT_OF_MEMORY через F_RaiseException тут не підтверджено.
Наступний потрібний контекст — фактична resolved версія Tc2_System; зміни
production exception transport без з'ясування причини не внесено.

## Погоджена передача SystemException як обгортки — 2026-10-06

Власник явно погодив пропагувати системну помилку як SystemException через
framework transport замість повторного native raise. Це замінює попередню
вимогу збереження сирого native коду в наступному CATCH. Зберігаються причина
в обгортці, первинний catch point і timestamps.

ReThrowLastException бере переданий IException незалежно від типу коду;
якщо payload не передано, отримує його через GetLastException. Далі викликає
Throw: статична обгортка клонується, динамічна зберігає identity.
Три нові необов'язкові inputs описують catch point; десять callers у
Collections/Automation передають їх. Попередні перші два inputs збережено.
Для зовнішніх callers без metadata місце catch залишається порожнім.

Чотири Workflow catch зберігають клон статичного SystemException перед
SetNewState/OnFail, щоб наступний системний catch у callback не змінив причину.
Динамічні framework exceptions не клонуються. Клони мають звичайний cycle
lifetime під ownership DynamicMemoryManager. Ціна — allocation обгортки.

ReThrowLastException, Throw перед клонуванням і SystemException.Clone перед
NEW викликають RaiseIfAllocationFailed. Latched fatal OOM не обгортається
на цих шляхах і не потребує нового heap exception. Latch та boundary re-raise
не змінені. Точний native код при terminal raise може залишатися спотвореним
runtime; зупинку контролера після boundary raise ця зміна не перевіряла.

Тест RethrowNativeAfterFramework замінено на RethrowSystemExceptionAfterFramework
зі збереженням object ID. Відомий ARRAYBOUNDS передається адаптеру напряму.
Перевіряються повідомлення (причина/catch point), timestamps, dynamic instance,
незалежність від shared storage, повторна передача збереженого payload після
іншого framework exception і шлях без явно переданого payload.
Це тест нового контракту обгортки, не перевірка первинного native raise.
Попередній runtime результат expected 28 / actual 3902013441 залишається
чинним обмеженням. Втрачений стороннім F_RaiseException код не відновлюється.

Контракти біля декларацій оновлено у форматі DocGen. За вказівкою власника
перевірки, compilation, генератор документації та runtime не запускалися.
