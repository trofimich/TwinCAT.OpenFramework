# Core/Primitives: первинний статичний огляд

2026-10-16. Прочитано декларації й реалізації всіх 53 об'єктів каталогу:
30 POU (22 PROGRAM, 8 FUNCTION_BLOCK), 22 DUT та 1 interface.
Зіставлено основні зв'язки Collections/List, Workflow variables, exception formatting,
Automation HMI та String/WideString Helper/Builder tests. Це не вичерпний аудит
кожного зовнішнього caller чи всіх платформних конверсій. Код не змінено.
Compilation, runtime, XML validation і check-скрипти не запускалися.

Підстава всіх нових знахідок нижче — статичний аналіз. Де потрібна семантика
Beckhoff, наведено документацію. Немає нових підтверджень задуму від власника.
Попередній огляд CC не використано як доказ поточного дефекту.

## Оцінка задуму й складу

Загалом задум доречний: зібрати маленькі типи й операції, яких бракує стандартному
ST API, та адаптувати ANY до контейнерів. PROGRAM як namespace helpers доречний;
не потрібні нові service objects, interfaces або універсальний conversion engine.
Найважливіші проблеми — локальні помилки типів/розмірів і нечіткі межі ownership,
а не невдала архітектура. Primitives містить і низькорівневі операції, і formatting,
але переміщення файлів саме по собі користі зараз не дасть.

| Об'єкти | Призначення й оцінка |
|---|---|
| Bits | Виділення діапазону бітів. Корисний маленький helper, алгоритм потребує P01. |
| Bytes | Пошук, byte-order swap, зсув буфера. Swap2/4/8 прості й доречні; SearchByte потребує контракту count/address, TrimBytesLeft — P08. |
| SignedByte, SignedInt16, SignedInt32, SignedInt64 | Межі signed integers; SignedInt32 також 24-bit. Константи узгоджені з розрядністю; окремі PROGRAM — допустимий стиль бібліотеки, перебудова не потрібна. |
| UnsignedByte, UnsignedInt16, UnsignedInt32, UnsignedInt64 | Межі unsigned integers. Значення доречні; BYTE у UnsignedByte — representation choice, не самостійна помилка. |
| Times | Людинозрозуміле створення TIME з одиниць часу; P02. Межі negative/NaN/overflow не визначені. |
| LongTimes | Аналог для LTIME, множники відповідають ns; precision LREAL і діапазон входу потребують опису. |
| DateAndTimes | Форматування DT зі своїми separators. Доречний вузький helper; пустий separator змінює довжину й наступні позиції, потрібна передумова рівно одного символу або інший алгоритм. |
| LongDateAndTimes | Те саме для LDT; P12, звірити формат результату на target. |
| Reals, LongReals | Константи діапазону/Infinity/NaN. Корисні, але LOG(-1) для NaN — небажана залежність від compiler/FPU; див. Q6. |
| REAL_UNION, LREAL_UNION | Перегляд IEEE representation. Прості й доречні; не confused numeric conversion із reinterpretation. |
| UNIVERSAL_POINTER | Типізовані views однієї адреси. Доречний внутрішній інструмент, не валідатор адреси/типу/розміру. |
| SystemAnyTypes | Borrowed runtime descriptor ANY ↔ generic. Корисний adapter, не копіює payload; ULINT Size звужується до DINT, потрібна межа. |
| GenericTypeClassConvertor | System type → generic category; доречна централізація. Enum/subrange sign policy Q3; нерелевантний DocGen P14. |
| SystemTypeClassConvertor | Зворотне відображення; enum/object identity не відновлює. Try-метод ловить exception throwing-методу — зайва heap/transport робота для звичайної відмови. |
| GENERIC_VALUE | Descriptor плюс typed views/conversion/mutation/release. Потрібний контейнерам, але value-like assignment копіює ownership flag, не ресурс. P03/P06/P13 і Q1–Q3. |
| GenericValueFactory | Явні borrow/clone/adopt factories. Задум правильний; P04/P10 і небезпечний fallback object copying Q1. |
| GENERIC_MEMORY_MANAGEMENT_BEHAVIOR | Три явні режими ownership. Залишити; описати transfer і відповідальність caller, не додавати ще flags. |
| GENERIC_KEY_VALUE_PAIR | Пара descriptors для Dictionary. Доречний struct, самостійного автоматичного cleanup немає; assignment не deep clone. |
| IGenericValueValidator, GenericValueValidator | Перевірка конкретного TypeClass для контейнерів. Вузька відповідальність доречна; не перевіряє address/size/lifetime. Поточний порядок actual/expected у Throw правильний — старий CC-07 не підтверджується. |
| Strings, WideStrings | Formatting, append/find/replace/join/trim/split і лексичні predicates. Корисний API; P05–P09/P11, неоднозначності Q4. Різниця STRING/WSTRING потребує двох реалізацій, не обов'язково нового шару узагальнення. |
| StringBuilder, WideStringBuilder | Mutable owned buffers для накопичення тексту. Попередні exact-fit/self-append/довгі same-encoding fragments враховані. Нова перебудова не потрібна; Q5 про copy/lifetime, optional clear/growth. |
| StringSplittingEnumerator | Borrowed source, owned current fragment. Концепція придатна, allocation на MoveNext — компроміс; P10 і Q4/Q5. |
| WideStringSplittingEnumerator | Та сама модель, але P07 у розмірі хвоста. Reset уже звільняє current і повертає cursor до початку. |
| READ_ONLY_ERROR, ERROR | Read-only за домовленістю snapshot помилки та mutable операції Clear/Fill/SetSeverity. Відокремлення стану від exception правильне. VAR_OUTPUT не enforced immutable — уже погоджений компроміс. ToString P11; HasError залежить від TopMessage. |
| ERROR_MESSAGE, JSON_DOCUMENT | Централізовані місткості WSTRING(2000)/STRING(25000). Корисні aliases; особливо JSON_DOCUMENT не варто копіювати на стек без потреби. |
| INT_INDEX, DINT_INDEX, INT_LENGTH, DINT_LENGTH | Невід'ємні indices/lengths; maximum index на 1 менше maximum length — послідовно. Не гарантують фактичних меж конкретного буфера. |
| COMPARISION_RESULT, DIRECTION_TYPE | Signed тристанні результати; доречні. Історичну назву COMPARISION не перейменовувати лише косметично. |
| ERROR_SEVERITY, ERROR_SOURCE_DISPLAY_MODE, TIMESTAMP_DISPLAY_MODE | Політика severity і форматування; прості enums без потреби в ієрархіях. |
| GENERIC_TYPE_CLASS, POINTER_TYPE | Класи representation та pointer types. Доречні як metadata; самі не доводять сумісність пам'яті. |
| LOAD_STATE, SEARCH_DIRECTION, SORT_DIRECTION, TRIM_MODE | Маленькі явні переліки станів/режимів; нових локальних дефектів у деклараціях не встановлено. |

## Конкретні проблеми реалізації

### P01 — Bits: байти замість бітів і неправильне виділення діапазону

[Bits:54](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Bits.TcPOU#L54),
аналогічно всі чотири методи. SIZEOF(BYTE)=1, тому дозволений сигнатурою index=7
відхиляється. Для GetBitsFromByte(16#FF, 0, 0) обидва shifts нульові й повертається
весь FF, а не окремий bit. Самої заміни SIZEOF на SIZEOF*8 недостатньо:
потрібно узгодити mask/shift. Мінімальна правка — правильна bit width і маска,
але спершу вирішити, чи fragment зсувається до bit0, чи лишається на своєму місці.
Це виправить поведінку, API сигнатури можна зберегти.

### P02 — Times.FromNanoseconds: неправильний дільник

[Times:90](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Times/Times.TcPOU#L90)
ділить на 1_000_1000, тобто 10 001 000 замість 1 000 000. Вхід 1 000 000 000 ns
має дати 1 s, але перед TO_TIME виходить приблизно 99.99 ms.
Мінімальна правка — один literal; без нового helper чи абстракції.

### P03 — GENERIC_VALUE.AsReal читає LREAL як LWORD

[GENERIC_VALUE:732](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Generic/GENERIC_VALUE.TcPOU#L732).
FromLRealReference для 1.5 → AsReal(TRUE): бітовий шаблон double переводиться
в REAL як велике ціле, а не 1.5. Потрібен AsLReal^ замість AsLWord^.
Сигнатура й ownership не змінюються.

### P04 — чотири long date/time reference factories гублять тип

[Factory:238](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Generic/GenericValueFactory.TcPOU#L238),
також 256, 310, 328: FromLDateAndTimeReference/FromLDateReference/
FromLTimeOfDayReference/FromLTimeReference задають UINT_64. Value-варианти через
FromAny зберігають правильні temporal categories. Наслідок: той самий LTIME
reference форматується як число та відхиляється validator для TIME_64.
Мінімум — правильні чотири tags; bytes й ownership не змінювати.

### P05 — Strings.Find і WideStrings.Find читають не той аргумент

[Strings:278](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Strings/Strings.TcPOU#L278),
[WideStrings:271](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Strings/WideStrings.TcPOU#L271).
Передано ADR(stringToFindLength), тобто адресу локального UDINT, замість
ADR(stringToFind). Для Find('abc','b') довжина needle виходить 0, не 1;
MEMCMP із n=0 повертає 0xFF, тому звичайний збіг не знаходиться.
Мінімальна правка — правильний аргумент і видалення непотрібних locals.
Підстава: код і [MEMCMP](https://infosys.beckhoff.com/content/1033/tcplclib_tc2_system/31039627.html).

### P06 — проміжні string views/buffers мають 80, а не 255 символів

[GENERIC_VALUE:862](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Generic/GENERIC_VALUE.TcPOU#L862)
і 1317 читають через UNIVERSAL_POINTER.AsString/AsWString, оголошені без (255).
[Strings:566](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Strings/Strings.TcPOU#L566)
і [WideStrings:567](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Strings/WideStrings.TcPOU#L567)
мають local string255 : STRING/WSTRING, теж стандартного розміру.
Сценарій: current із текстом 100 символів → Join у достатній target. Гілка
Size<255 проходить через короткий local і втрачає хвіст. AsString255/AsWString255
теж не повинні залежати від короткого типізованого view.
Мінімум: explicit 255 для справді короткого local, bounded pointer copy для
raw strings, або прямий append string reference за TypeClass. Не збільшувати
всі pointers до 255 навмання: коротка source allocation потребує bounded read.
[STRING default](https://infosys.beckhoff.com/content/1033/tc3_plc_intro/2529410443.html).

### P07 — WideStringSplittingEnumerator: занадто малий останній fragment

[MoveNext:151](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Strings/WideStringSplittingEnumerator.TcPOU#L151).
Для WSTRING "ABCD" без separator length=4, виділяється/копіюється 6 bytes
замість 10; це "ABC" без terminator. Подальший WSTRING reader може вийти за
allocation. Та сама формула неправильна в SourceStringSize при Initialize.
Мінімум: (length+1)*CharSize для обох розмірів і відповідного copy, без redesign.

### P08 — перекривні ділянки копіюються MEMCPY

[Bytes:135](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Bytes.TcPOU#L135),
[Strings:1110](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Strings/Strings.TcPOU#L1110),
[WideStrings:1099](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Strings/WideStrings.TcPOU#L1099).
TrimBytesLeft на 1 з буфера 10 bytes або left trim ' abc' зсуває дані в межах
того самого буфера. Це порушує documented MEMCPY contract; фактичне пошкодження
на target не відтворене. Мінімальна правка — MEMMOVE, без зміни public API.
[Beckhoff MEMCPY](https://infosys.beckhoff.com/content/1033/tcplclib_tc2_system/31041163.html).

### P09 — WideStrings.TryJoinToTarget має STRING separator

[WideStrings:1198](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Strings/WideStrings.TcPOU#L1198).
Параметр STRING передається ADR у POINTER TO WSTRING. Separator ', ' буде
прочитано як UTF-16 code unit 16#202C, а не як два символи. Односимвольна кома
може випадково працювати. Мінімум — WSTRING; зміна public parameter type,
тому callers із STRING треба адаптувати. Знайдені helper tests викликають
JoinToTarget, не цей Try-варіант.

### P10 — allocation failure поза спільним terminal шляхом

[Factory:430](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Generic/GenericValueFactory.TcPOU#L430)
і обидва splitting MoveNext роблять NEW без перевірки 0. При failure Factory
викликає MEMCPY з 0, потім Assign піднімає heap ArgumentNotSpecifiedException;
це не terminal allocation protocol. Splitter може повернути TRUE з порожнім
Current або розіменувати null при trim/remove-empty.
Мінімум — shared RaiseAllocationFailure перед використанням allocation.
Runtime exhaustion не виконувалося. ULINT size → UDINT також потребує явної
межі перед allocation, якщо FromParts допускає більші значення.

### P11 — formatting errors на допустимих рядках

[WideStrings:693](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Strings/WideStrings.TcPOU#L693):
Replace("abc", "b", "") спочатку зсуває хвіст до "ac", потім MEMCPY n=0
повертає 0 і метод повідомляє failure/overflow. У narrow версії вже є guard
newSubstringLength>0; такий самий guard достатній тут.

[Strings:435](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Strings/Strings.TcPOU#L435):
AppendToTarget(target,'') повертає FALSE з InternalAppendToTarget і піднімає
memory-overflow exception, хоча жодної додаткової пам'яті не потрібно.
Порожній single append варто зробити успішним no-op. Поведінка порожніх
середніх аргументів багатопараметрових helpers — окреме Q4.

[READ_ONLY_ERROR:71](../../Sources/TwinCAT.OpenFramework.Core/Primitives/Errors/READ_ONLY_ERROR.TcPOU#L71):
TopMessage довжиною 2000 плюс відмінний RootMessage або ввімкнений source/time
не вміщаються в ToString: ERROR_MESSAGE. AppendToTarget піднімає нове exception
під час показу вже наявної помилки. Це досяжне через HmiAutomationComponentElement,
який викликає Error.ToString. Механізм доведений кодом; бажану overflow policy
потрібно погодити: рекомендовано bounded truncation з ELLIPSIS як у exceptions.

### P12 — LongDateAndTimes.ToString: неузгоджений prefix offset

[LongDateAndTimes:55](../../Sources/TwinCAT.OpenFramework.Core/Primitives/DateAndTime/LongDateAndTimes.TcPOU#L55)
видаляє 3 символи, wide-варіант — 4. Для literal notation LDT# narrow залишає
'#', а подальші REPLACE звертаються до зміщених позицій. Мінімум — однакове
видалення повного prefix. Це статична невідповідність очікуваному LDT format;
точний native STRING/WSTRING output поточного runtime перевірити вручну.
[Date conversion](https://infosys.beckhoff.com/content/1033/tc3_plc_intro/2529063563.html).

### P13 — неправильний destination type у повідомленнях конверсії

GENERIC_VALUE.AsLDate (414), AsLDateAndTime і AsLTimeOfDay (636) передають
32-bit destination class в exception замість відповідного 64-bit.
Сценарій: unsupported string → AsLDate дає повідомлення про DATE_32.
Локальне виправлення enum arguments; саму conversion matrix не перебудовувати.

### P14 — частина DocGen описує не призначення методу

GenericTypeClassConvertor.GetGenericTypeClassBySystemTypeClass описано як
"Prepares diagnostic text locally...", хоча головна функція — відображення типів.
Схожі надто загальні описи generic values зосереджені на diagnostic string input,
не ownership. Багато декларацій зовсім без meaningful summary/contract.
Це недолік документації, не runtime defect. Виправляти під час поштучного
обговорення, не масовим шаблонним текстом.

## Питання контракту та ризики, які не слід змішувати з підтвердженими багами

Q1. OBJECT без ICloneable у FromParts копіюється через NEW(BYTE)+MEMCPY, але
Release трактує результат як Object. Для StringBuilder це копія pointer на той
самий owned buffer без FB_init; незалежного ресурсу не створено. Рекомендація:
для OBJECT cloning вимагати ICloneable й відхиляти відсутність, не вигадувати
reflection/deep-copy. Для USER_DEFINED дозволити raw copy лише даних, де це
задумано. Потрібне рішення власника про підтримувані типи. Не поширювати
exception auto-ownership на generic collections — це вже заборонено контрактом.

Q2. GENERIC_VALUE.Equals порівнює bytes без перевірки TypeClass (крім string
length handling); INT#1 і UINT#1 можуть бути equal, +0.0/-0.0 — різними.
Це може бути навмисний representation equality. Caller List.Contains реально
використовує цей метод. CopyTo теж перевіряє size, не type. AsBool читає один
BYTE через BOOL pointer навіть для INT32: значення 256 має нульовий молодший byte.
Потрібно визначити: numeric semantics чи raw view. Рекомендую numeric AsBool,
а Equals обговорити окремо; не додавати conversion graph.

Q3. Enum/subrange converter відображає будь-який розмір у UINT_n і губить sign:
SINT enum -1 форматуватиметься як 255. System metadata тут не дає автоматичного
знання signedness. Потрібна політика: raw bits, caller hint чи відмова від numeric
трактування. allowTypeCastWithDataLoss також фактично визначає allowed pairs,
не перевіряє поточне значення; назва потребує чіткого опису. Long temporal
конверсії мають несиметричні allowed pairs — не міняти без контракту.

Q4. Concat255/Append255 припиняють обробку на першому пустому optional аргументі.
Split пропускає trailing empty навіть при RemoveEmptyEntries=FALSE; MaxCount
відкидає хвіст, а не повертає решту одним fragment. Це може бути задумом.
Separator зберігається в STRING/WSTRING стандартного розміру: довгий separator
може бути обрізаний, тоді як SeparatorLength у narrow рахується з оригіналу.
Потрібно обмеження довжини або узгоджене збереження. IsInteger/IsFloat/
IsUnsignedInteger використовують LEN/WLEN (межа255), хоча входи const references
можуть бути довшими: 255 цифр + 'X' може бути оцінене за prefix.
Рекомендація — довгі рядки перевіряти LEN2/WLEN2 й відповідним index або явно
обмежити контракт. Negative bounds trimChars arrays не враховано через UDINT cast.

Q5. Builder та splitter володіють raw allocations і не мають deep assignment.
Звичайне копіювання активного FB може створити aliases і подвійне звільнення;
CreateSplitter як return-by-value без current allocation не тотожний копіюванню
вже активного splitter. Source має жити довше cursor, buffers/views — тільки
до mutation/Reset/destruction. Ці правила потрібно прописати. Online change
FB_exit(bInCopyCode) також потребує окремого target сценарію, не заявлено safe.
Right trim має UDINT loop до 0 BY -1 зі suppressed warning: для рядка тільки
з trim chars можливий underflow після index0. До runtime/точного compiler
підтвердження це серйозний ризик; простий signed counter усуває його без складності.

Q6. NOT_A_NUMBER := LOG(-1) залежить від обробки domain error; exception/startup
failure не відтворений. Рекомендую вже наявні REAL_UNION/LREAL_UNION bit patterns,
не математичну помилку для створення NaN. Reals.MAX_VALUE округлене й не точний
найбільший finite REAL — уточнити, чи це саме точна межа. Times/LongTimes для
negative, NaN, infinity та overflow потребують передумов; не додавати guards
скрізь без рішення. LREAL не точно представляє кожну nanosecond біля ULINT max.

Q7. ERROR.HasError визначається лише TopMessage. Exception з nonzero code, але
порожнім message, може бути nonempty у exception API і empty у ERROR. Чи
підтримується такий conversion, слід узгодити; не змінювати severity logic навмання.
GetSource повертає255, а local tempString у ToString має80 — ще одне місце
можливого обрізання source, яке потрібно врахувати разом із P11.

## Мінімальні покращення без перебудови

- Спочатку локальні виправлення P01–P13, кожне після погодження; більшість —
  один type/tag/literal, guard або memory operation. P09 має signature impact;
  Q1 та equality/empty-input policies можуть змінити допустимий usage.
- GenericValueValidator залишити вузьким TypeClass checker; actual/expected
  уже правильні. Не додавати перевірку lifetime, якої неможливо забезпечити адресою.
- StringBuilder.Clear(FALSE) може зануляти лише terminator замість усього capacity,
  якщо ніхто не покладається на нулі поза text. Це optional performance change.
- Growth +80 може давати багато allocations/copies при великих текстах;
  геометричне growth або Reserve обговорювати лише при реальному навантаженні.
- Не впроваджувати zero-copy split, pooling, refcount, нові manager layers.
- PROGRAM helper methods переважно мають локальні робочі дані, але це не доказ
  thread safety всіх sources, borrowed buffers та container operations.
- Heap allocations і довгі цикли мають змінну ціну в PLC; bounded usage та
  повторне використання вже наявного builder доречніші за масове ускладнення.

## Перевірки, яких бракує

Наявні StringHelperTest/WideStringHelperTest охоплюють append/overflow, join,
replace, split і trim на коротких прикладах. Builder suites — empty/basic build,
wrong type/too-small target. Collections tests використовують factories, але
не замінюють conversion matrix tests. Split tests не assert-ять total count після
циклу; wide tail лише один символ, тому P07 ним не виявляється. Окремих знайдених
сценаріїв Bits/FromNanoseconds/AsReal/long-temporal factories немає. Це прогалини
покриття, не докази дефектів. Тести тут не виконувалися.

Потрібні сценарії після узгоджених правок:

1. Bits: first/last/single/full range для 8/16/32/64, inverted range; очікуваний
   alignment погодити. Time: 1e6/1e9 ns, boundaries та chosen invalid-input policy.
2. Generic: LREAL 1.5 → REAL; four long-temporal reference/value tags; numeric
   Bool 0/1/256; exact allowed casts і error destination metadata.
3. Strings: Find match/no-match/empty; empty append; optional empty middle;
   join 80/81/100/254/255/256 chars, wide separator з двох символів;
   replace на empty; wide split 'ABCD' і 'A,BCDE', multi-char separator;
   assert кількість entries, Current до/після MoveNext/Reset, trailing/maxCount.
4. Trim: left overlap, RIGHT тільки spaces, negative-bound trimChars array;
   long lexical string із недопустимим символом після позиції255.
5. Error formatting: top2000 + root/source/time, empty/error snapshots,
   source80/255; узгоджений bounded результат замість secondary exception.
6. Factory allocation failure на ізольованому target і відмова OBJECT без Clone
   після погодження Q1; borrowing/adoption/release без подвійного cleanup.
7. Builders: exact-fit, >255 fragments, self-append з growth/без, Clear reuse,
   no-copy lifetime. Не повторювати старі тести як доказ нової редакції.

Пропонований порядок діалогів: Bits/Bytes → Times/DateAndTimes → numeric helpers
і DUT → generic converters/value/factory → validators → Strings/WideStrings →
splitters/builders → ERROR. Починати з локальних confirmed issues; Q-пункти
не реалізовувати до відповіді власника.


## Поступові виправлення — 2026-10-16

- Bytes.TrimBytesLeft: MEMCPY замінено на MEMMOVE для перекриття джерела й
  призначення. Сигнатуру, правила trim count та зміну totalBytesCount збережено.
  Додано DocGen типу Bytes і методу. Це виправлення частини P08;
  Strings/WideStrings ще не змінено.
- Bits (P01): перед зміною алгоритму поставлено питання про вирівнювання
  вибраного діапазону — до молодшого біта чи зі збереженням позицій.
- Compilation, runtime та check-скрипти не запускалися. Для ручної перевірки
  TrimBytesLeft: часткове видалення з перекриттям, видалення всіх байтів,
  нульовий/від'ємний count та count понад довжину.

- P01 / Bits: власник погодив зсув вибраного діапазону до молодшого біта.
  У всіх чотирьох методах ширина тепер SIZEOF(type) * 8; алгоритм SHL/SHR
  відкидає старші й молодші зайві біти. Залишено одну локальну змінну зсуву,
  наявні перевірки аргументів та сигнатури. DocGen описує реальний контракт.
  Перевірки не запускалися. Ручні сценарії: B0, 4..7 -> 0B; FF, 0..0 -> 1;
  повна ширина, старший одиночний біт, середній діапазон, зворотні межі.

- P02 / Times.FromNanoseconds: виправлено дільник на 1_000_000; додано
  DocGen типу й методу. Інші правила native conversion не змінено.
  Перевірки не запускалися; ручні приклади: 0 -> T#0ms,
  1_000_000 -> T#1ms, 1_000_000_000 -> T#1s.

- Times/LongTimes (часова частина Q6): власник погодив відповідальність caller
  за скінченний невід'ємний вхід, який після масштабування вміщується в результат.
  Передумову записано в DocGen обох типів і всіх From-методів; runtime guards
  не додано. Описано використання LREAL/native conversion без нової політики
  округлення; для LTIME зазначено обмеження точності LREAL. Реалізації не змінено.
  Compilation/runtime та інші перевірки не запускалися.
- DateAndTimes/LongDateAndTimes: поставлено питання про порожні separators;
  залежні зміни форматування відкладено до відповіді власника.

- DateAndTimes/LongDateAndTimes: власник погодив порожні separators.
  У ToString/ToWideString заміни виконуються справа наліво (17, 14, 11, 8, 5),
  щоб видалення delimiter не зміщувало ще не оброблені позиції.
  Додано DocGen типів і методів, прибрано невикористані result : STRING.
  P12: LongDateAndTimes.ToString видаляє 4 символи префікса LDT#, як wide-метод.
  Це статичне виправлення; native formatting на target ще потребує перевірки.
  Runtime/compilation/check-скрипти не запускалися. Ручні сценарії: default,
  кожен separator порожній окремо, усі порожні, змішані separators; для LDT
  додатково ненульові дробові секунди та відсутність залишкового #.


## Продовження — 2026-10-17

- Q6 / NaN: власник відхилив перехід на union через відомі йому проблеми
  компілятора. Reals/LongReals.NOT_A_NUMBER залишено з LOG(-1), типи не змінено.
  Пропозицію заміни закрито; локально проблеми компілятора не відтворювалися.
- Q6 / REAL limits: власник підтвердив точні крайні скінченні значення REAL.
  Reals.MIN_VALUE/MAX_VALUE тепер використовують ±3.402823466E+38;
  при округленні до binary32 це крайні finite значення, raw FF7FFFFF/7F7FFFFF.
  Додано DocGen контракту. LongReals bounds не змінювалися.
- P03 / GENERIC_VALUE.AsReal: REAL_64 читається через AsLReal, а не AsLWord,
  перед TO_REAL. Сигнатуру та allowTypeCastWithDataLoss збережено.
  Додано DocGen AsReal, нерелевантний загальний опис GENERIC_VALUE замінено
  описом descriptor і його storage/lifetime. Інші методи не змінено.
- Підстава виправлень: статичний аналіз та погоджений задум власника.
  Compilation/runtime/check-скрипти не запускалися. Ручна перевірка:
  raw bits меж REAL; AsReal для LREAL 1.5 з TRUE -> 1.5, з FALSE ->
  GenericConversionNotSupportedException; прямий REAL читається без конверсії.

- Q1 / OBJECT cloning: власник погодив вимогу ICloneable. У FromParts для
  OBJECT у clone mode відсутність інтерфейсу піднімає NotSupportedException
  з повідомленням "Object cloning requires ICloneable." до виділення byte buffer.
  Побайтовий fallback залишено лише для інших type categories. Режими borrowing
  та adoption не змінено. Додано DocGen фабрики/FromObjectValue, актуалізовано
  FromParts; прибрано невикористану cloneableIntance з FromObjectValue.
  Compilation/runtime не запускалися. Ручні сценарії: OBJECT без ICloneable
  відхиляється; OBJECT з ICloneable використовує Clone; FromObjectReference
  працює без ICloneable; числове/рядкове копіювання зберігається.
  Відкриті окремі питання allocation failure та контракту результату Clone
  цією правкою не закриваються.

- Q2 / Equals, integer pairs: власник погодив числову рівність усіх цілих
  категорій незалежно від розрядності та знаковості. Додано чотири випадки
  signed/signed, unsigned/unsigned і дві змішані пари; використовуються наявні
  AsLInt/AsULInt без loss-enabled casts. Перед TO_ULINT signed-операнда
  перевіряється невід'ємність через AND_THEN. Один локальний LINT,
  без нових helpers, flags або floating-point conversion.
  BYTE/WORD/DWORD/LWORD представлені UINT-категоріями й входять до цієї зміни.
  Empty semantics та всі пари, де хоча б один operand не integer, поки
  зберігають попередню поведінку. Це часткове узгодження Equals, не остаточний
  контракт інших категорій. DocGen описує поточні межі реалізації.
  Перевірки не запускалися. Ручні сценарії в обох порядках operands:
  INT#1/UINT#1, BYTE#1/LINT#1, SINT#-1/LINT#-1 -> TRUE;
  LINT#-1/ULINT max -> FALSE; LINT max/відповідний ULINT -> TRUE;
  LINT max/ULINT (LINT max + 1) -> FALSE; ULINT max/ULINT max -> TRUE;
  два різні цілі понад 2^53 -> FALSE; різні ширини нуля -> TRUE.
  Додатково regression старих empty та string comparisons.

- Q2 / Equals, floating-point pairs: власник погодив числову рівність REAL/LREAL
  без допуску. Для пар REAL_32/REAL_64 використано AsLReal() = otherValue.AsLReal();
  REAL розширюється до LREAL без звуження другого operand. Нових helpers чи
  локальних змінних немає. DocGen актуалізовано. Native floating-point exceptions
  залежать від runtime configuration; нових TRY/CATCH не додано.
  Змішані integer/floating та інші категорії ще не узгоджені й зберігають старий
  fallback. Compilation/runtime/check-скрипти не запускалися.
  Ручні сценарії в обох порядках: REAL#1/LREAL#1 -> TRUE; REAL#1/LREAL#1.5 -> FALSE;
  +0/-0 -> TRUE; NaN/NaN і NaN/1 -> FALSE за умов виконання native comparison;
  LREAL#1 і наступне відмінне представиме LREAL -> FALSE (немає tolerance).

- Q2 / Equals, integer–floating pairs: власник погодив FALSE без конверсій.
  Додано явні гілки для signed/unsigned проти REAL_32/REAL_64 та навпаки.
  Empty descriptors і решта категорій не змінені; DocGen актуалізовано.
  Перевірки не запускалися. Ручні сценарії в обох порядках: INT#1/REAL#1,
  DINT#0/REAL#0, LINT#0/LREAL#0 -> FALSE. Останні два випадки раніше могли
  збігатися побайтово. Integer/integer та floating/floating — regression.

- Q2 / Equals, категорії: власник погодив BOOL лише з BOOL (логічна рівність),
  дати/час — побітно лише в однаковому TypeClass; різні категорії нерівні,
  крім раніше погоджених integer/integer та floating/floating пар.
  Додано один спільний TypeClass guard після числових гілок; він також замінив
  три окремі integer/floating rejection branches. Empty semantics збережено.
  Для однакових інших категорій старе порівняння вмісту ще не переглядалося.
- Q2 / AsBool: власник погодив zero/nonzero для цілих. Signed читаються через
  AsLInt(), unsigned через AsULInt(), після чого порівнюються з нулем.
  BOOLEAN читається як BOOL; перелік підтримуваних типів не розширено.
  DocGen обох методів оновлено. Перевірки не запускалися.
  Ручні сценарії: AsBool для 0 -> FALSE, 1/256/-256/ULINT max -> TRUE;
  BOOL/BOOL звичайна логічна рівність; TRUE/UINT#1 -> FALSE в обох порядках;
  TIME/UDINT з однаковими бітами -> FALSE; однаковий TIME -> TRUE;
  TIME/LTIME -> FALSE. Regression погоджених numeric та empty comparisons.

- Q2 / Equals, OBJECT: власник погодив identity equality. Після перевірки
  однакового TypeClass непорожні OBJECT порівнюються лише за Address;
  пам'ять об'єктів не читається і їхні поля не порівнюються. Це не перевірка
  lifetime. Empty semantics збережено. DocGen оновлено.
  Перевірки не запускалися. Ручні сценарії: два descriptors одного instance
  -> TRUE; різні instances з однаковими полями -> FALSE; object/інша категорія
  -> FALSE; object clone та original -> FALSE за різних адрес.

- Q2 / Equals, optional comparer: власник погодив comparer : IComparer := 0.
  За ненульового comparer перед стандартними перевірками створюються два
  borrowed AnyType через AsAnyType, викликається Compare, і TRUE повертається
  лише для FIRST_EQUAL_TO_SECOND. Нульовий comparer залишає built-in правила.
  Сумісність, зокрема empty operands, визначає caller/контракт comparer;
  exceptions не перехоплюються. Нових interfaces/helpers і heap allocations
  не додано. Розмір має вміщуватися в DINT AnyType; OBJECT -> TYPE_USERDEF
  не містить ідентичності класу. DocGen оновлено, старі виклики без другого
  аргументу зберігають default behavior. Compilation/runtime не запускалися.
  Ручні сценарії: omitted/zero comparer; три результати Compare; comparer для
  різних instances з однаковим змістом; empty operands передаються comparer;
  exception comparer поширюється без переходу до built-in equality.

- Q2 / USER_DEFINED: власник погодив стандартне побайтове порівняння,
  включно з padding і значеннями pointer-полів. Для порівняння значущих полів
  caller передає сумісний comparer. Обмеження записано біля Equals;
  concrete type identity USER_DEFINED не перевіряється. Алгоритм не змінено.
- P04: FromLDateAndTimeReference/FromLDateReference/FromLTimeOfDayReference/
  FromLTimeReference тепер задають відповідно DATE_AND_TIME_64/DATE_64/
  TIME_OF_DAY_64/TIME_64 замість UINT_64. Borrowing і сигнатури збережено,
  додано DocGen чотирьох методів. Підстава — статичний аналіз категорій входу.
  Перевірки не запускалися. Ручна перевірка: reference/value factories для
  кожного з чотирьох типів дають однаковий TypeClass; reference зберігає адресу
  оригіналу та IsMemoryOwner=FALSE; відповідний typed getter читає значення.

- ICloneable.Clone: власник підтвердив ненульовий результат при успіху,
  exception при невдачі. Записано біля інтерфейсу/методу і в FromParts.
  Фабрика покладається на контракт; додаткового null-result guard не додано.
  Переглянуті exception-clone allocations вже використовують terminal failure;
  повну runtime перевірку всіх сторонніх реалізацій не заявлено.
- P10 / GenericValueFactory byte allocation: після __NEW(BYTE, ...) додано
  перевірку newAddress = 0 з DynamicMemoryManager.RaiseAllocationFailure()
  перед MEMCPY. Використано погоджену terminal-поведінку без створення heap
  exception і без зайвого RETURN. Size ULINT -> UDINT залишається окремим
  відкритим питанням діапазону; splitter allocations ще не виправлені.
  Compilation/runtime/check-скрипти не запускалися. Ручні сценарії:
  successful Clone, throwing Clone без fallback, allocation failure byte copy
  з terminal flag; звичайне копіювання числа/рядка.

- P10 / FromParts byte-copy size: власник погодив відхилення size понад UDINT.
  У non-OBJECT clone branch додано size > TO_ULINT(UnsignedInt32.MAX_VALUE)
  з ArgumentOutOfRangeException до __NEW/TO_UDINT/MEMCPY. Використано наявну
  константу. Object Clone, borrowing/adoption і ранній empty return не змінено.
  DocGen оновлено. Перевірки не запускалися. Ручний сценарій: ненульова адреса,
  non-OBJECT clone mode, size = 4294967296 -> ArgumentOutOfRangeException
  для size без читання payload/виділення byte copy. Звичайні малі копії — regression.
  Це не перевірка наявності достатньої пам'яті й не гарантія успіху __NEW.

- Q3 / ENUM, SUBRANGE: власник погодив збереження поточного unsigned mapping
  за розміром 1/2/4/8. Це бітове представлення, а не відновлення signed значення;
  signed enum -1 розміром 1 байт може дорівнювати UINT_8 255. Для signed semantics
  caller явно конвертує до signed integer; borrowed converted variable не є
  посиланням на original enum. DocGen оновлено для GenericTypeClassConvertor,
  його чотирьох mapping methods і GenericValueFactory.FromAny/FromAnyType.
  Нерелевантний diagnostic-text опис прибрано. API/implementation не змінено.
  Перевірки не запускалися. Це погоджений контракт/обмеження, не нове виправлення.

- P05 / Find: власник погодив empty needle -> TRUE/position=1, навіть в empty
  source; no-match -> FALSE/position=0. Обидва public Find тепер читають довжину
  самого stringToFind, а не локального UDINT; залишено одну локальну довжину.
  Empty needle оброблено в public Find. InternalFind має явні FALSE/0 та ранню
  відмову для empty needle: його викликає InternalReplaceInSource, де empty match
  міг би створити цикл без просування. Таким чином public контракт виконано,
  без нового empty-replacement behavior. Видалено unused memCoparisionResult,
  додано DocGen чотирьох методів. Перевірки не запускалися.
  Ручні сценарії STRING/WSTRING: abc/b -> TRUE/2; abc/x -> FALSE/0;
  abc/abcd -> FALSE/0; abc/empty і empty/empty -> TRUE/1; empty/a -> FALSE/0;
  перший/останній/повторений збіг, mixed case, повторний виклик після успішного.
  Replace/Split із nonempty delimiter — regression; empty replacement pattern
  потребує окремого погодження, поточну відсутність замін збережено.

- Replace empty oldSubstring: власник погодив успіх без змін та replacementCount=0.
  У Strings/WideStrings.InternalReplaceInSource додано явне скидання результату
  й count та ранній TRUE/RETURN до читання source/newSubstring для empty pattern.
  Перевірка encoding у public wrappers збережена. DocGen оновлено для internal
  і чотирьох public Replace/TryReplace методів кожної родини.
- P11 / WideStrings replacement deletion: MEMCPY викликається лише коли
  newSubstringLength > 0, як у Strings. Видалення підрядка більше не трактує
  нульовий результат zero-length MEMCPY як failure після виконаного MEMMOVE.
  Інші алгоритми/параметри не змінено. Перевірки не запускалися.
  Ручні сценарії STRING/WSTRING: empty pattern з empty/nonempty replacement
  і source -> без змін, count=0, Try=TRUE; abc/b/empty -> ac, count=1;
  aaa/a/empty -> empty, count=3; skip/max limits; звичайні replacements;
  overflow після попередніх замін (поточний алгоритм не є атомарним).

- Replace capacity failure: власник погодив неатомарну заміну. Завершені заміни
  зберігаються, поточна при нестачі місткості не виконується; рядок зберігає
  terminator, count описує завершені заміни. Це гарантія для коректних буферів
  при capacity failure, не для invalid memory access. За читанням реалізації
  перевірка місткості передує MEMMOVE/MEMCPY поточної заміни в обох helpers.
  Оновлено DocGen internal і public Replace/TryReplace; алгоритм не змінено.
  Runtime/compilation/check-скрипти не запускалися. Ручний приклад:
  STRING(5) з 'aa', заміна 'a' -> 'bbb': результат 'bbba', count=1,
  Try=FALSE / throwing wrapper піднімає exception; аналогічно WSTRING(5).

- P11 / Strings.AppendToTarget: власник погодив empty source як успішну
  операцію без змін. Додано ранній RETURN після перевірки target TypeClass,
  до InternalAppendToTarget; DocGen методу виправлено. Лише двопараметровий
  public метод змінено, InternalAppendToTarget і AppendToTarget255 не змінені.
  Перевірки не запускалися. Ручні сценарії: empty source з empty/nonempty/full
  STRING target не змінює target і не піднімає exception; неправильний тип
  target далі відхиляється; nonempty source використовує попередню логіку.

- Strings.AppendToTarget255: власник погодив пропуск порожніх фрагментів.
  InternalAppendToTarget обробляє всі 10 позицій у порядку аргументів,
  пропускаючи null pointers та empty strings; FALSE лише для несумісного
  target type або failure CONCAT2, TRUE після завершення. На failure
  наступні фрагменти не обробляються. Нових arrays/helpers/locals немає.
  Спільний helper також узгоджує TryAppendToTarget255 та TryAppendToTarget:
  всі порожні дають TRUE без змін. DocGen чотирьох методів актуалізовано.
  WideStrings та Concat255 у цьому кроці не змінено. Перевірки не запускалися.
  Ручні сценарії: A/empty/B -> AB; empty/A -> A; тільки sourceString10 ->
  його вміст; усі empty -> без змін/успіх; overflow зупиняє наступні append;
  single-source TryAppend з empty -> TRUE; non-STRING target -> відмова.

- Погоджене продовження: WideStrings Append/TryAppend тепер пропускають empty
  і omitted fragments аналогічно Strings, зупиняючись лише при failure.
  P07: wide splitter обчислює source/tail byte size як (length + 1) * CharSize;
  хвіст копіюється разом із terminator за _CurrentEntrySize.
  P10: обидва splitters перевіряють кожен __NEW перед доступом до fragment,
  використовуючи RaiseAllocationFailure без зайвого RETURN.
  P08: у двох TrimChars MEMCPY з перекриттям замінено на MEMMOVE.
  P09: WideStrings.TryJoinToTarget.separator тепер WSTRING. Callers цього
  методу в Sources пошуком не знайдено; зовнішні callers мають передавати WSTRING.
  DocGen змінених методів/типів оновлено. Перевірки не запускалися.
  Ручні сценарії: wide A/empty/B та всі empty; wide split ABCD без separator
  та A,BCDE з довгим хвостом; allocation failure; left trim із перекриттям;
  wide join із separator з двох символів. Right-trim index питання не закрито.

- P06: InternalJoinToTarget в обох родинах має string255 місткістю 255,
  а не default 80. GENERIC_VALUE.AsString255/AsWString255 для same-encoding
  strings використовують STRNCPY/WSTRNCPY у власний результат із SIZEOF(result),
  як уже роблять builders.ToString255. Це усуває приховану 80-character межу
  без зміни UNIVERSAL_POINTER і без читання фіксованих 255 байтів із короткого
  джерела. DocGen оновлено. Перевірки не запускалися.
  Cross-encoding TO_STRING/TO_WSTRING ще потребують окремого рішення щодо
  символів, які не вміщуються в STRING; ці гілки не змінені.
  Ручні сценарії: same-encoding 0/1/80/81/100/255/256 символів, join 100
  символів у достатній target, короткий окремо виділений string buffer.

- P06 / cross-encoding: власник погодив WSTRING -> STRING лише за
  allowTypeCastWithDataLoss=TRUE, без додаткового exception через втрату символів.
  AsString255 використовує WSTRING_TO_STRING2, AsWString255 — STRING_TO_WSTRING2,
  безпосередньо з source pointer у result із SIZEOF(result). FALSE flag конвертера
  не перетворюється на exception: результат API обмежений 255 одиницями тексту.
  За документацією WSTRING_TO_STRING2 непредставимі символи пропускаються;
  обидві функції обмежують обхід Parameterlist.cMaxCharacters. Це не UTF-8 API.
  DocGen актуалізовано, allow flag та exception для WSTRING при FALSE збережені.
  Compilation/runtime/check-скрипти не запускалися. Ручні сценарії: empty,
  ASCII 80/81/255/256, непредставимий символ між ASCII літерами, FALSE/TRUE
  allow flag, single-byte extended characters у STRING -> WSTRING.
  Джерела Beckhoff:
  https://infosys.beckhoff.com/content/1033/tcplclib_tc2_utilities/3483047691.html
  https://infosys.beckhoff.com/content/1033/tcplclib_tc2_utilities/3483030795.html

- Q4/Q5 / TrimChars indices: у Strings/WideStrings правий цикл тепер
  проходить stringLength..1 і читає [originalCharIndex - 1], тому не потребує
  unsigned decrement нижче нуля. Suppression C0266 прибрано. trimCharIndex
  має DINT; LOWER_BOUND/UPPER_BOUND більше не звужуються до UDINT, що дозволяє
  масиви з negative bounds. Додаткових locals/helpers немає, DocGen оновлено.
  Це усунення статично виявленого ризику; зависання на runtime не відтворене.
  Перевірки не запускалися. Ручні сценарії: RIGHT для empty/одного пробілу/
  лише пробілів/без пробілів/тексту з хвостом; LEFT і LEFT_AND_RIGHT regression;
  trimChars ARRAY[-2..-1], STRING/WSTRING, різні символи для видалення.

- P13: AsLDate/AsLDateAndTime/AsLTimeOfDay передають у conversion exception
  DATE_64/DATE_AND_TIME_64/TIME_OF_DAY_64 замість 32-bit категорії. Додано
  DocGen фактичної поточної conversion matrix; її асиметрія й трактування
  INT_64 через unsigned view не змінені й не оголошені погодженими власником.
  Перевірки не запускалися. Ручний сценарій: unsupported STRING input у кожен
  getter -> diagnostic з правильною 64-bit destination category.

- Q4 / numeric text predicates: власник погодив перевірку повного рядка.
  IsFloat/IsInteger/IsUnsignedInteger у Strings/WideStrings використовують
  LEN2/WLEN2(ADR(...)), UDINT length/index, ранній FALSE для empty input до
  віднімання 1. Граматика циклів збережена; нової перевірки numeric range немає.
  DocGen усіх шести методів описує lexical contract і залежність вартості від
  довжини. Compilation/runtime/check-скрипти не запускалися.
  Ручні сценарії: 255 цифр + X -> FALSE; 256/300 цифр -> TRUE (лише syntax);
  знак/exponent/invalid suffix після 255; довжина понад 32767 перевіряється
  без INT index overflow; empty, один знак, 1e, 1e+ -> FALSE; 1e-2 -> TRUE.

- Concat255: власник пояснив початковий задум — заміна каскаду CONCAT
  методом із optional arguments; empty argument був маркером завершення.
  Після обговорення погоджено пропуск empty fragments, щоб порожнє значення
  змінної не губило наступний текст. Strings/WideStrings тепер перевіряють
  усі optional arguments 3..16 й додають лише непорожні; перші два аргументи
  поєднуються як раніше. Сигнатури, місткість 255 і truncation не змінені.
  Додано DocGen контракт. Нових locals/helpers або allocation немає.
  Підстава зміни: статичний аналіз і погодження власника. Перевірки не запускалися.
  Ручні сценарії: A/B/empty/C -> ABC; лише string16 непорожній при порожніх
  перших двох -> string16; усі empty -> empty; звичайний виклик із двома
  аргументами; результат довший за 255; аналогічні WSTRING сценарії.

- Split / empty fragments: власник погодив збереження всіх порожніх фрагментів
  при RemoveEmptyEntries=FALSE, включно з trailing empty та одним empty для
  порожнього source. У MoveNext обох enumerators прибрано достроковий вихід
  через нульову remaining length. Наявний non-null cursor дозволяє обробити
  порожній хвіст у звичайній final-fragment гілці, яка потім обнуляє cursor.
  Нових flags/locals немає. RemoveEmptyEntries далі фільтрує після TrimEntries.
  MaxCount і поведінка empty separator не змінені; контракт описує nonempty
  separator. DocGen типів і MoveNext актуалізовано.
  Підстава: статичний аналіз і погодження власника; перевірки не запускалися.
  Ручні сценарії для STRING/WSTRING з separator comma і MaxCount=0:
  empty -> [empty]; A, -> [A, empty]; , -> [empty, empty]; ,A,, ->
  [empty, A, empty, empty]. При RemoveEmptyEntries=TRUE лишаються тільки
  непорожні фрагменти; перевірити TrimEntries, повторний MoveNext після кінця
  та повторний обхід після Reset.

- Split / MaxCount: власник підтвердив задум — повернути не більше MaxCount
  елементів звичайного split, без приєднання залишку до останнього елемента.
  Назву збережено; 0 означає без обмеження, відфільтровані empty fragments
  не витрачають ліміт. Контракт додано до MaxCount, Initialize, CreateSplitter
  і TryCreateSplitter обох родин. Реалізація не змінена: це погоджена поведінка,
  а не дефект. Перевірки не запускалися. Ручний приклад: A,B,C із MaxCount=2
  повертає A і B; empty/A/empty/B із removeEmptyEntries=TRUE і лімітом 2
  повертає A і B.

- 2026-10-18 / separator capacity, частковий крок: власник погодив межу 255.
  Separator в обох enumerators розширено до 255; wide Initialize також приймає
  WSTRING(255). SeparatorLength обчислюється зі збереженої копії, а не з
  потенційно довшого оригіналу. Обидва CreateSplitter відхиляють >255 через
  ArgumentOutOfRangeException до Initialize; Strings.TryCreateSplitter повертає
  FALSE для >255 або invalid separator reference. DocGen актуалізовано.
  WideStrings.TryCreateSplitter поки має VAR_INPUT WSTRING(255), тому довший
  аргумент може обрізатися до входу в метод. Питання про VAR_IN_OUT CONSTANT
  поставлено власнику, відповіді ще немає; цей API не змінено. Рішення не завершене.
  Підстава: читання коду й погоджена межа; перевірки не запускалися.
  Для ручної перевірки: separators довжиною 80/81/255/256, STRING/WSTRING;
  для CreateSplitter >255 має бути exception, для narrow Try — FALSE.

- 2026-10-18 / остаточна межа separator: власник переглянув попереднє рішення
  й погодив повернення до 80 символів з явним відхиленням довших значень.
  В обох enumerators Separator має явну місткість 80; wide Initialize також
  WSTRING(80). Обидва CreateSplitter перевіряють >80 до Initialize і піднімають
  ArgumentOutOfRangeException; обидва TryCreateSplitter повертають FALSE.
  Обчислення SeparatorLength зі збереженої копії збережено. Публічні способи
  передачі параметрів не змінені: wide Try має VAR_INPUT WSTRING(255),
  достатній для відхилення >80 навіть після обрізання аргументу до 255.
  Питання про VAR_IN_OUT CONSTANT для wide Try більше не актуальне.
  DocGen оновлено. Попередня межа 255 та частковий статус вище — історичні.
  Перевірки не запускалися. Ручні сценарії: separator 1/80 працює; 81/255/256
  відхиляється (exception у Create, FALSE у Try), для STRING і WSTRING.

- 2026-10-18 / empty separator: власник підтвердив, що успішне створення
  enumerator без результатів для empty separator не було навмисним.
  Обидва CreateSplitter тепер відхиляють empty separator наявним
  ArgumentOutOfRangeException; обидва TryCreateSplitter повертають FALSE.
  Перевірка виконується до Initialize і доповнює існуючу межу 80,
  без нових locals/exception instances. DocGen public методів та internal
  Initialize описує діапазон 1..80. Порожній source з валідним separator
  залишається дозволеним за попереднім погодженням.
  Підстава: статичний аналіз та підтвердження власника. Перевірки не запускалися.
  Ручні сценарії для STRING/WSTRING: empty separator з empty/nonempty source
  -> exception/Create або FALSE/Try; separator 1/80 -> успіх, 81 -> відмова;
  empty source з comma -> один empty fragment при RemoveEmptyEntries=FALSE.

- 2026-10-18 / READ_ONLY_ERROR.ToString overflow: погоджено bounded result
  з ellipsis замість exception через переповнення. AppendToTarget замінено
  на TryAppendToTarget; перший FALSE переводить до спільного завершення,
  яке замінює останній символ результату на WideStrings.ELLIPSIS. Exact-fit
  не змінюється. Порядок фрагментів збережено; нових heap allocations/locals
  немає. DocGen типу й ToString додано. Локальний tempString місткістю 80
  і GetSource limit поки не змінені — окреме питання форматування джерела.
  Підстава: погодження власника, читання коду і документація WCONCAT2:
  https://infosys.beckhoff.com/content/1033/tcplclib_tc2_utilities/3483043467.html
  WCONCAT2 заповнює обмежений target і повертає FALSE при truncation.
  Перевірки не запускалися. Ручні сценарії: empty; combined 1999/2000/2001
  code units; top=2000 без suffix та з root/source/time; overflow на кожному
  фрагменті; останній символ ellipsis лише при truncation, terminator збережений.

- 2026-10-18 / READ_ONLY_ERROR.ToString source buffer: за погодженням власника
  tempString змінено з WSTRING (80) на WSTRING(255), відповідно до місткості
  GetSource. DocGen актуалізовано. Збільшення локальної пам'яті — 350 байтів;
  нових змінних і heap allocations немає. GetSource і TO_WSTRING не змінені.
  Перевірки не запускалися; фактичне збереження source довжиною 80/81/255
  при достатньому місці в результаті потрібно перевірити на target.

- 2026-10-18 / GetSource truncation: за погодженням власника GetSource(TRUE)
  позначає перевищення місткості трьома ASCII dots: перші 252 символи + '...'.
  Сумарна довжина рахується до обрізання з TopSource, перетвореного prefix
  та RootSource. Результат рівно 255 символів зберігається без позначки;
  omitted/empty/identical root як раніше повертає TopSource. Сигнатура й
  місткість 255 збережені, нових locals/heap allocations немає. DocGen додано.
  Перевірки не запускалися. Ручні сценарії: combined 254/255/256, top=255
  з distinct root, empty/identical root, appendRootSource=FALSE; HMI/logging.

- 2026-10-18 / GENERIC_VALUE.CopyTo: власник підтвердив побайтове копіювання
  за однакового розміру, без type conversion, cloning або ownership transfer;
  caller відповідає за сумісність. Нерелевантний diagnostic DocGen замінено
  описом цього контракту, фактичних перевірок target/size та shared pointers.
  Реалізацію не змінено. Zero-fill при Address=0 і відсутність overlap handling
  описані як поточні властивості реалізації, не окреме погодження їх бажаності.
  Перевірки не запускалися. Наступне питання — overlap/source=target у MEMCPY.

- 2026-10-18 / CopyTo overlap: власник погодив підтримку перекриття.
  internalCopyTo використовує MEMMOVE замість MEMCPY для ненульової Address;
  зміна спільна для CopyTo і TryCopyTo. Zero-fill та перевірки розміру/target
  не змінені. DocGen CopyTo, TryCopyTo й private helper узгоджено.
  Нових locals/allocations немає. Підстава: погодження власника і читання коду;
  compilation/runtime/check-скрипти не запускалися.
  Ручні сценарії для обох методів: окремі buffers, source=target, перекриття
  зі зміщенням у кожен бік; mismatch/null target з попередньою поведінкою.

- 2026-10-18 / CopyTo missing source: після обговорення власник погодив
  відхилення Address=0 без зміни target. CopyTo піднімає
  DataMemberNotSpecifiedException для Address до інших перевірок;
  TryCopyTo повертає FALSE. MEMSET-гілку internalCopyTo прибрано — лишився
  MEMMOVE. DocGen трьох методів актуалізовано. Перевірки не запускалися.
  Ручні сценарії: Address=0 і Size=SIZEOF(target), target із ненульовими
  даними -> exception/FALSE, дані незмінні; descriptor після Reset;
  валідне джерело з нульовими байтами -> успішне копіювання нулів;
  звичайне й overlapping копіювання як regression.

- 2026-10-18 / Q5 ownership і копіювання: власник погодив заборону value-copy
  builder/splitter з allocated buffer і відповідальність творця за cleanup
  splitter. DocGen чотирьох типів і Create/TryCreateSplitter обох родин
  доповнено. Активні екземпляри передаються за посиланням; присвоєння не
  клонує пам'ять і не переносить ownership. Не перезаписувати екземпляр,
  який ще володіє буфером. Reset звільняє current fragment; FB_exit також
  звільняє його. __DELETE застосовується лише до __NEW-екземпляра.
  CreateSplitter повертає FB без __NEW і без fragment allocation до MoveNext;
  отже сам результат не вимагає __DELETE. Source залишається borrowed.
  Це документація погодженого обмеження, без runtime guards чи зміни API.
  Перевірки не запускалися; online-change lifetime лишається окремим питанням,
  заборона користувацького присвоєння не є доказом безпечності online change.

## Online Change: дослідження 2026-10-18, рішення ще не погоджене

Запит власника: документація і варіанти для всього framework; код не змінювати.
Це огляд механізмів і вибіркових lifecycle paths, не повний framework audit.
Compilation/runtime/XML/check-скрипти не запускалися.

Документація Beckhoff:
- Operating cases: https://infosys.beckhoff.com/content/1033/tc3_plc_intro/6415331211.html
  Для перенесеної instance: old FB_exit(TRUE), new FB_init(FALSE,TRUE), copy,
  FB_reinit; external initializers/call_after_init також перед copy. Для зміни
  лише implementation без заміни data areas цих lifecycle calls немає.
- POINTER (4026): https://infosys.beckhoff.com/content/1033/tc3_plc_intro/2529453451.html
  Symbol знайдено й type незмінний -> адреса оновлюється; symbol removed/type
  changed -> zero; symbol не знайдено -> pointer unchanged. Потрібний ADS symbol
  description destination; hide може його прибирати. Для interior pointers,
  type-erased addresses і pointer fields у heap coverage не доведене.
- __NEW: https://infosys.beckhoff.com/content/1033/tc3_plc_intro/2529171083.html
  Router allocation; fixed memory for dynamic FB/DUT; зміна layout типу з
  enable_dynamic_creation не підтримується Online Change, потрібний download.
- Inheritance: https://infosys.beckhoff.com/content/1033/tc3_plc_intro/5482088715.html
  FB_exit derived -> base автоматично; FB_init base -> derived автоматично;
  FB_reinit base потребує explicit SUPER call. Guard у Object не замінить
  guards у descendants, які вже виконали cleanup.
- no_copy: https://infosys.beckhoff.com/content/1033/tc3_plc_intro/2529708427.html
  Variable reinitialized замість copied; не звільняє owned resource автоматично.
- Fast OC: https://infosys.beckhoff.com/content/1033/tc3_userinterface/2531444363.html
  init_on_onlchange не виконується у fast path; не універсальний reset hook.

Статичні спостереження:
- StringBuilder/WideStringBuilder.FB_exit безумовно Clear(TRUE), який очищає
  length/capacity і звільняє buffer. При перенесенні такого FB очікується
  втрата тексту; це не доказ dangling pointer (old state змінено до copy).
- Splitters.FB_exit видаляють current fragment, але не скидають весь cursor
  state. Current і подальший обхід після перенесення потребують контракту.
- List.FB_exit викликає Clear; FB_init прив'язує _Array до _StaticArray,
  якщо NOT Dynamic. Для borrowed addresses і graph це окремий review.
- MemoryCleanupHelper.FB_Exit безумовно CleanupAllTasks; не можна трактувати
  його як гарантований global hook кожного OC. AutoDisposeRegistrar.FB_Init
  реєструє nonzero object без окремої гілки bInCopyCode.
- FileHandleResourceManager.FB_exit запускає close при acquired handle;
  переносити/скидати handle та pending operation треба узгоджено.
- Пошуком FB_reinit/no_copy у Sources TcPOU не знайдено. Це не повна
  перевірка всіх compiler attributes або сторонніх бібліотек.

Варіанти (пропозиції, не контракти власника):
1. Обмежена підтримка: лише code-only OC без перенесення ресурсних instances;
   структурні зміни через контрольований download. Найменша ціна, без гарантії
   довільної зміни логіки активного алгоритму навіть у code-only випадку.
2. Поступове збереження ресурсів: для перевірених heap owners не звільняти
   ресурси в FB_exit(TRUE); зберігати узгоджено pointer/length/capacity;
   borrowed references до PLC data перев'язувати/валідувати окремо.
   Для transient split операцій можна вимагати завершення/reset до OC.
   Не додавати такий guard масово без розбору callers і descendants.
3. Контрольоване завершення операцій усіх tasks перед OC і відновлення після:
   дорожче; потребує app-level протоколу, не тільки FB_exit одного runner.
Рекомендація: зараз явно обмежити гарантії, далі по малих групах варіант 2;
не вводити загальну migration infrastructure без конкретної потреби.

Майбутні ручні перевірки власника: code-only change; примусове перенесення
owner зі збереженим buffer; borrowed source relocation і changed/removed type;
повторні OC з контролем resource count; нормальний delete/download після OC;
окремо hierarchy callbacks, registry кількох tasks та file operations.

- 2026-10-18 / Online Change відкладено за рішенням власника: практична
  потреба рідкісна, зараз не впроваджувати підтримку й не змінювати lifecycle
  callbacks. Дослідження вище збережене для конкретної майбутньої потреби.
  Гарантія підтримки Online Change фреймворком не заявлена; runtime не перевірено.

- 2026-10-18 / SystemTypeClassConvertor: за дорученням рухатися по пунктах
  таблицю відповідностей перенесено без зміни пар у TryGet...; для unsupported
  він повертає FALSE/TYPE_NONE без exception. Get... викликає TryGet... та
  піднімає попередній ArgumentValueNotSupportedException при FALSE.
  Нових helpers/locals немає. DocGen типу й двох методів додано.
  Пошуком на момент зміни зовнішніх викликів TryGet... у Sources не знайдено.
  Перевірки не запускалися. Ручні сценарії: усі enum categories з попередньої
  таблиці, UNSPECIFIED -> TRUE/TYPE_NONE, invalid enum -> FALSE/TYPE_NONE
  без зміни exception state; Get для invalid enum піднімає exception.

## Temporal conversions: статичний розбір 2026-10-18

Власник підтвердив: allowTypeCastWithDataLoss дозволяє потенційно втратні
пари типів; без нього весь діапазон джерела має зберігатися. Runtime range
checks кожного значення не потрібні. Нижче фактична таблиця, не погоджений
новий контракт. Self-type завжди дозволений. I32/U32 = INT_32/UINT_32;
I64/U64 = INT_64/UINT_64; TRUE додає тільки перелічені гілки.

| Getter | Додатково при FALSE | Додатково лише при TRUE |
|---|---|---|
| AsDate | I32/U32, DT | LDATE, I64/U64 |
| AsDateAndTime | I32/U32, DATE | LDT, I64/U64 |
| AsLDate | DATE, I64/U64, DT | LDT |
| AsLDateAndTime | DT, I64/U64, DATE, TIME | LDATE, LTIME |
| AsTime | DT, I32/U32, TOD | LTIME, I64/U64 |
| AsLTime | TIME, I64/U64, DT, TOD | LDT, LTOD |
| AsTimeOfDay | I32/U32 | TIME, I64/U64, LTIME |
| AsLTimeOfDay | TOD, I64/U64, TIME, DT | LTIME, LDT |

Підстави: поточні CASE у GENERIC_VALUE і документація Beckhoff:
- https://infosys.beckhoff.com/content/1033/tc3_plc_intro/12189021579.html
  TIME: unsigned milliseconds, максимум понад 49 діб; LTIME: unsigned ns.
- https://infosys.beckhoff.com/content/1033/tc3_plc_intro/2529415819.html
  TOD/LTOD: час у межах доби, ms/ns. DATE/LDATE мають внутрішню роздільність
  seconds/ns, хоча відображається лише день. Самої назви DATE недостатньо
  для висновку про обнулення часу оператором TO_DATE.
- https://infosys.beckhoff.com/content/1033/tc3_plc_intro/2529063563.html
  При виході за діапазон результат platform-dependent, можливий exception.

Чіткі невідповідності погодженому правилу:
- TIME -> LTOD дозволений без flag, хоча T#25h не є valid time-of-day.
- U32 -> TOD та U64 -> LTOD дозволені без flag, хоча весь діапазон integer
  значно більший за добу (86400000 ms / 86400000000000 ns вже на межі 24h).
- Signed INT_32/INT_64 у відповідних getters читаються через unsigned view;
  зокрема DINT#-1 -> AsTime(FALSE) перетворюється на UINT32_MAX milliseconds,
  а LINT#-1 -> AsLTime(FALSE) на UINT64_MAX ns. Це не numeric preservation.
  Для TRUE окремо погодити, чи потрібні raw bits або signed native conversion.
- LTOD -> LTIME зараз потребує TRUE, хоча valid LTOD range вміщується в LTIME
  з тією самою ns точністю. Кандидат на перенесення у безумовну гілку.

Окремо не закриті: зміна epoch/units при date <-> duration, фактичні native
DT/LDT -> DATE/LDATE/TOD/LTOD operators, missing conversion pairs. Відсутня
пара не є автоматично дефектом і не буде додана без погодження.
Поточна online документація LDATE/LDT дає signed-date діапазон 1677..2262,
тоді як старі official PDF/сторінка literals описують 1970..2554. Не оголошувати
точний діапазон target 4026.27 перевіреним без runtime evidence.
Пошук прямих .AsDate/.AsTime та long variants викликів у Sources не дав збігів;
це не виключає зовнішніх library callers. Код не змінено, тести не запускалися.
Пропозиція першого кроку: тільки перенесення TIME -> LTOD, I32/U32 -> TOD,
I64/U64 -> LTOD за flag; без зміни native операторів і без нових range checks.

- 2026-10-18 / temporal step 1: погоджено й перенесено за flag TRUE:
  INT_32/UINT_32 -> AsTimeOfDay; INT_64/UINT_64 і TIME_32 -> AsLTimeOfDay.
  FALSE тепер відхиляє ці пари через наявний conversion exception незалежно
  від фактичного значення. Native operators та unsigned views не змінені.
  Решта пар, зокрема DT -> LTOD, не змінені й потребують окремого розбору.
  DocGen двох методів актуалізовано. Перевірки не запускалися.
  Ручні сценарії: кожна перенесена пара з value=1 та FALSE -> exception;
  TRUE -> попередній native conversion; valid TOD/LTOD direct/widening
  paths з FALSE працюють як раніше. Out-of-range TRUE не обіцяє safe result.

- 2026-10-19 / temporal step 2: за погодженням власника TIME_OF_DAY_64 ->
  AsLTime перенесено з allowTypeCastWithDataLoss у безумовний CASE.
  TO_LTIME і решту пар не змінено. DocGen AsLTime додано: допустимий LTOD
  перетворюється на duration since midnight без втрати ns precision.
  Signed integers та DATE_AND_TIME conversions ще не закриті.
  Перевірки не запускалися. Ручні сценарії: LTOD midnight, 1 ns,
  23:59:59.999999999 при FALSE/TRUE -> однакове LTIME; LDT при FALSE
  далі відхиляється. Підстава: погоджений контракт і попередній статичний аналіз.

- 2026-10-19 / новий контракт conversion flag: власник доручив перевіряти
  конкретне значення. FALSE дозволяє підтримувану пару, якщо value зберігається
  точно; TRUE дозволяє native conversion із потенційною втратою. Попередній
  blanket type-range контракт замінений. Міграція по групах, не завершена.
  Виконано всі 12 integer getters (signed/unsigned/bitstring): колишні gated
  гілки приймають value у межах target range без flag, checks до conversion.
  Наявні safe branches, BOOLEAN representation і набір supported types збережені.
  DINT -> AsTime та LINT -> AsLTime перевіряють невід'ємність при FALSE;
  читають signed storage і при TRUE передають native operator signed value.
  Нових helpers/locals немає. DocGen змінених методів актуалізовано.
  Перевірки не запускалися. Ручні сценарії: для integer min/max та сусідні
  значення, signed-negative -> unsigned, UINT64_MAX -> signed, 100 -> INT;
  FALSE відхиляє out-of-range, TRUE використовує native conversion.
  AsTime/AsLTime: -1/0/1/max signed, відмова лише -1 при FALSE.
  Ще не мігровано: решта temporal paths, LREAL -> REAL, WSTRING -> STRING.
  Для NaN/Infinity при LREAL -> REAL поставлено питання власнику.

- 2026-10-19 / value checks, durations/time-of-day: AsTime тепер перевіряє
  signed nonnegative, 64-bit integer <= UINT32_MAX (ms), LTIME <= TIME max
  і кратність 1ms до conversion. AsTimeOfDay: numeric ms / durations у [0,24h),
  LTIME також кратне 1ms. AsLTimeOfDay: numeric ns / durations у [0,24h).
  Signed integers читаються як signed. TRUE допускає попередні supported
  native conversion pairs без value guards; signed native input виправлено.
  Нових supported type pairs немає. Попередні blanket flag обмеження цих
  пар замінені новим погодженим контрактом. Calendar branches ще не змінені.
  Перевірки не запускалися: ручні boundary сценарії 0, -1, 24h-1 unit, 24h,
  TIME max, LTIME 1ms/1ms+1ns, signed/unsigned integer upper bounds.

- 2026-10-19 / AsReal: власник погодив NaN та +/-Infinity лише при TRUE
  для LREAL -> REAL і використання Reals/LongReals constants. FALSE спочатку
  відхиляє special exponent bits через LongReals.POSITIVE_INFINITY.Raw,
  перевіряє Reals.MIN_VALUE/MAX_VALUE, тоді порівнює widened narrowed result
  з original. TRUE виконує native TO_REAL; REAL direct read не змінений.
  Додаткових locals/constants не знадобилося. Підтримка subnormal та FPU
  conversion behavior залежить від target; жодної runtime гарантії не перевірено.
  DocGen оновлено; перевірки не запускалися. Ручні сценарії: +/-0, 1.5,
  LREAL 0.1 (inexact), REAL finite endpoints widened, outside endpoints,
  NaN/Infinity при FALSE/TRUE, smallest normal/subnormal REAL widened.

- 2026-10-19 / constants in conversion guards: за дорученням власника
  integer lower bounds використовують відповідний Unsigned*.MIN_VALUE;
  duration lower bounds — Times/LongTimes.MIN_VALUE, AsTime integer upper
  bounds — Times.MAX_VALUE. Додано Times.ONE_DAY, LongTimes.ONE_DAY та
  LongTimes.ONE_MILLISECOND з DocGen; TOD guards і перевірка кратності
  використовують ці константи. Алгоритм і допустимі значення не змінено.
  Загальне правило використання констант записано в AGENTS.md. Calendar
  conversion migration лишається відкритою; нових перевірок дат не додано.
  Компіляція, runtime та check-скрипти не запускалися.

- 2026-10-19 / calendar date semantics: власник погодив DATE/LDATE як
  календарну дату: перетворення DT/LDT з ненульовим часом потребує TRUE,
  а результат має бути без прихованого залишку часу. Реалізовано DT -> DATE
  та DT -> LDATE: seconds MOD Times.SECONDS_PER_DAY, FALSE відхиляє
  ненульовий залишок, TRUE віднімає його перед conversion. Для DT -> LDATE
  очищений timestamp зберігає тип DT перед widening, щоб не трактувати
  seconds як nanoseconds. Додано Times.SECONDS_PER_DAY і DocGen.
  LDT -> LDATE ще не реалізовано: константи проєкту 1970..2554 суперечать
  актуальній документації Beckhoff 1677..2262; signed/unsigned arithmetic
  та підтримуваний діапазон потребують уточнення до нормалізації LDT.
  Підстава: погодження власника, статичний аналіз. Перевірки не запускалися.
  Ручні сценарії DT: epoch, midnight, noon, last second of day, MAX_VALUE;
  FALSE приймає лише midnight, TRUE повертає midnight відповідної дати.

- 2026-10-19 / LDT documented range: власник погодив перехід на діапазон
  актуальної документації Beckhoff. MAX_VALUE змінено на
  LDT#2262-4-11-23:47:16.854775807. MIN_VALUE ще не змінено: знайдено
  використання як reset timestamp у ERROR, Exception, SystemException і HMI.
  Поставлено питання про збереження попереднього reset value через EPOCH.
  Друге питання: відхиляти LDT першого неповного дня 1677-09-21 навіть
  при TRUE, бо midnight цього дня не представляється в LDATE.
  Реалізація LDT -> LDATE очікує рішення щодо цієї межі.
  Джерело: https://infosys.beckhoff.com/content/1033/tc3_plc_intro/2529415819.html
  Підстава: документація і статичний аналіз callers. Перевірки не запускалися.

- 2026-10-19 / LDT calendar normalization completed: власник погодив EPOCH
  для очищення timestamps та відмову для першого неповного дня навіть при TRUE.
  LongDateAndTimes.MIN_VALUE = LDT#1677-9-21-0:12:43.145224192; EPOCH = 1970.
  ERROR.Clear, Exception.Clear, SystemException.Clear та HMI status reset
  використовують EPOCH і зберігають попередню поведінку. DocGen актуалізовано.
  AsLDate для LDT читає signed nanoseconds, нормалізує MOD ONE_DAY у [0,day),
  FALSE приймає лише midnight; перед відніманням перевіряє signed lower bound
  через SignedInt64.MIN_VALUE + remainder. Перший неповний день відхиляється
  без arithmetic underflow. Нових conversion pairs не додано.
  Підстава: погоджений контракт і статичний аналіз; перевірки не запускалися.
  Ручні сценарії: epoch, epoch-1ns -> 1969-12-31 при TRUE/exception FALSE;
  negative midnight при обох flags; MIN_VALUE та кінець 1677-09-21 -> exception
  при обох flags; 1677-09-22 midnight; MAX_VALUE -> 2262-04-11 при TRUE.
  Решта date/numeric/duration conversions ще потребує окремих кроків.

- 2026-10-19 / LDT -> DT value checks: AsDateAndTime приймає LDT при FALSE
  лише в межах DateAndTimes.MIN_VALUE/MAX_VALUE (widened to LDT) і з цілими
  секундами. Signed nanosecond checks виконуються до TO_DT; TRUE лишає native
  conversion без range/precision checks. Додано LongTimes.ONE_SECOND і DocGen.
  Нових locals/conversion pairs немає. Решта numeric/date paths не змінена.
  Підстава: погоджений value-based контракт і статичний аналіз.
  Перевірки не запускалися. Ручні сценарії: epoch, epoch-1ns, epoch+1ns,
  ціла секунда, widened DT.MAX_VALUE, DT.MAX_VALUE+1ns/+1s; FALSE приймає
  тільки точні значення в діапазоні. TRUE лишається native/platform-dependent.

- 2026-10-19 / numeric calendar inputs: власник погодив seconds since epoch
  для DATE і nanoseconds since epoch для LDATE; FALSE вимагає midnight,
  TRUE прибирає час. Виконано INT_64 -> LDATE: спільна гілка з LDT читає
  signed nanoseconds і нормалізує до midnight без втрати знаку. Погоджена
  відмова для першого неповного дня застосовується також до його числового
  представлення. Документацію оновлено; перевірки не запускалися.
  Решта numeric inputs очікує уточнення TRUE поза діапазоном: exception
  або native overflow behavior. Не обирати цю поведінку без відповіді.
  Ручні сценарії INT_64: 0, +/-1ns, +/-ONE_DAY, signed minimum/maximum;
  FALSE лише midnight, TRUE floor to day, minimum day -> exception.

- 2026-10-19 / numeric calendar range policy completed: власник погодив
  AsDate/AsLDate exceptions для out-of-range numeric input при обох flags;
  Try-версії лише за реальною потребою, зараз не додаються.
  AsDate I32/U32/I64/U64 означають seconds since epoch: bounds checked before
  narrowing, FALSE лише midnight, TRUE віднімає seconds within day.
  AsLDate U64 означає ns: MAX_VALUE check before conversion, FALSE лише
  midnight, TRUE прибирає ns within day. Signed I64 normalization вже виконана.
  Межі беруться з DateAndTimes/LongDateAndTimes, тривалість доби — з Times/
  LongTimes. Нових locals, helper methods або conversion pairs не додано.
  LDATE -> DATE policy ще не змінена; це наступний крок.
  DocGen оновлено. Підстава: погодження власника та статичний аналіз.
  Перевірки не запускалися. Ручні сценарії: 0, one day, one day+1 unit,
  signed negative, widened DT maximum та +1, U64 maximum, LDT maximum та +1.
  Out-of-range numeric input -> exception з FALSE/TRUE; in-range non-midnight
  -> exception FALSE / normalized date TRUE.

- 2026-10-19 / LDATE -> DATE: перенесено DATE_64 у головний CASE AsDate.
  Signed nanoseconds перевіряються проти widened DateAndTimes.MIN_VALUE/
  MAX_VALUE при обох flags. FALSE вимагає midnight (MOD LongTimes.ONE_DAY=0);
  TRUE явно прибирає hidden time remainder. Після перевірки й обнулення часу
  ns діляться на LongTimes.ONE_SECOND, тоді seconds перетворюються в DATE.
  Нових locals/helpers немає. DocGen актуалізовано. Підстава: погоджений
  контракт і статичний аналіз. Перевірки не запускалися.
  Ручні сценарії: LD#1970-01-01, звичайна дата, LD#2106-02-07 проходять
  з FALSE/TRUE; LD#1969-12-31, LD#2106-02-08 -> exception з обома flags;
  hidden subsecond/day remainder у допустимому timestamp range -> exception
  FALSE / midnight TRUE. Решта date-time getters не змінена.

- 2026-10-19 / DT/LDT numeric conversion migration: AsDateAndTime numeric
  inputs are seconds; FALSE checks signed nonnegative / 64-bit DT bounds,
  TRUE retains native conversion with the correct signedness. AsLDateAndTime
  reads INT_64 as signed ns; UINT_64 FALSE checks LongDateAndTimes.MAX_VALUE,
  TRUE retains native conversion. Valid LDATE -> LDT now accepts FALSE.
  This preserves the previously agreed native out-of-range policy for DT/LDT;
  the stricter calendar DATE/LDATE policy was not extended to these getters.
  Duration paths unchanged pending epoch/units discussion. No new helpers,
  locals or supported pairs. DocGen updated. No compilation/runtime/checks run.
  Manual scenarios: DT numeric -1/0/1/DT max/max+1; LDT LINT min/-1/0/max,
  ULINT LDT max/max+1; LDATE before epoch/epoch/latest date with both flags.
