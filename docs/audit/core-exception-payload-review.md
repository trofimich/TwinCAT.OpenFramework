# Core exception payload — група 3, 2026-10-06

Підготовчий статичний review для пункту 2: GeneralException, StandardException,
AggregateException. Звірено IGeneralException/IAggregateException, callers
CopyGeneralFields, InternalThrow, ExceptionManager.Throw та ExceptionTest.
Це не аудит решти конкретних exception subclasses. Runtime не виконано.

## Контракти й оцінка

GeneralException додає message/error code та один inner exception до metadata
Exception. InternalThrow записує source/час, позичає dynamic inner або клонує
static inner. Clear лише скидає reference і payload, не видаляє inner: ним володіє
DynamicMemoryManager. GetRootException рекурсивно повертає deepest inner.
Empty визначається власними message/code, а не inner. Це фактична поведінка,
не окреме підтвердження задуму. Поділ на common payload і конкретні typed
exceptions виправданий. Shared dynamic inner означає shallow copy посилання,
не незалежний immutable snapshot. Clone не продовжує cycle lifetime inner.

StandardException — concrete general-purpose message/code exception. Throw
делегує InternalThrow; Clone створює новий instance й копіює general fields.
Це доречний малий API; окремої перебудови не потрібно. Сигнатура Clone : IObject
успадкована, callers очікують IException. Dynamic clone auto-disposed.

AggregateException — ordered flattened список inner exceptions. Додавання null
нічого не робить; aggregate input рекурсивно розгортається. Звичайний dynamic
inner позичається, static inner клонується. Власний ресурс aggregate — масив
references, а не самі inner objects. Clear звільняє масив; повторний Clear
покладається на обнулення pointer оператором __DELETE. GetInnerException
поза межами повертає null. Root — root першого inner, не набір усіх roots.
Allocation нового масиву на кожне додавання має сумарну квадратичну вартість,
але для малих діагностичних списків це компроміс, не причина вводити capacity API.
Self-add, cyclic graphs та UINT count limit потребують окремого контракту;
такі сценарії не названо підтвердженими дефектами допустимого використання.

## Статичні знахідки

- P01: StandardException.Clone й AggregateException.Clone dereference __NEW
  без null guard; AddInnerException використовує new array без guard. При
  допустимому allocation failure можливі invalid access і пошкоджений cleanup.
  Пропозиція: той самий погоджений RaiseAllocationFailure, до dereference/MEMCPY.
  Розширення guard на всі descendants поза групою не робити автоматично.
- P02: AddInnerException видаляє старий масив до Clone статичного inner.
  Якщо Clone підніме exception, _InnerExceptions ще вказує на видалений масив,
  а новий buffer не закріплено. Пропозиція: підготувати inner reference/clone
  перед allocation масиву, а старий масив звільняти після готовності нового.
  Clone auto-disposed, тому при наступному allocation failure ручне delete
  clone не потрібне й порушувало б підтверджений ownership.
- P03: CopyGeneralFields має блок, що читає destination _InnerException,
  записує локальний innerException, але потім присвоює source.InnerException
  напряму. Для звичайного нового clone destination inner=null, блок не діє.
  Це зайва логіка; для reused destination може створити непотрібний clone.
  Мінімально видалити блок і unused local, зберегти shallow copy source inner.
  Це не доказ втрати inner у звичайному Clone path.

## Перевірки

Наявні StandardExceptions/AggregateException у ExceptionTest перевіряють message
chain/кількість, але не null allocations, clone identity чи cleanup buffers.
Потрібні сценарії: empty aggregate clone/message; add static inner, потім змінити
оригінал; dynamic inner зберігає identity; aggregate clone має власний масив,
Clear оригіналу не очищає clone; повторний Clear. Null allocation — ізольована
injection у кожному з трьох sites та runner terminal re-raise, не production run.
Відсутність тестів не використано як доказ P01–P03.

## Пункт 2 — внесені мінімальні зміни

Після завершення пункту 1 виконано P01–P03 в межах доручення продовжувати
послідовно. Три __NEW sites захищено existing fatal latch helper до використання
pointer. У AddInnerException clone/borrow inner підготовлено до allocation масиву;
при clone/allocation failure старі pointer/count не змінюються цим методом.
Під час flattening aggregate попередні успішні additions не відкочуються:
transactional insertion цілої групи не обіцяється, allocation failure terminal.
З CopyGeneralFields вилучено unused local і блок destination cloning;
shallow copy source.InnerException збережено. Existing IDs/signatures збережено.

Додано AggregateCloneLifetime: static source клонується, його Clear не змінює
stored inner; dynamic inner має ту саму identity; clone має власний масив,
Clear джерела (включно з повторним) не очищає clone. Dynamic objects не видаляються
вручну. Test method підключено до existing ExceptionTest.

XML/scope/IDs перевірено статично; ST/runtime ще не виконано. Empty-loop boundary,
self/cyclic graphs, UINT capacity limit і null injection лишаються окремими
непідтвердженими runtime/contract scenarios; повне закриття всіх edge cases
цього класу не заявляється. Далі пункт 3 — збірка/перевірки поточного snapshot.

## Продовження після заборони автоматичних перевірок, 2026-10-06

Власник доручив продовжити правки, але залишив усі перевірки собі. Нижче
описано внесені зміни, а не результати compiler/static-check/runtime запусків.

1. Контракт self-add/cyclic graphs і переповнення UINT ще очікує відповіді.
   Запропоновано заборонити self/cyclic input і до зміни масиву обробляти
   capacity limit через existing fatal latch. Цю частину поки не реалізовано.
2. У решті 22 concrete exception Clone додано null guard перед dereference
   із DynamicMemoryManager.RaiseAllocationFailure та RETURN. Це локальна
   уніфікація allocation policy, без зміни hierarchy або public signatures.
   Scope: EmptyException; 5 Argument, 5 DataMember, 3 GenericValues,
   ClassInitialization, 3 Memory exceptions, NotImplemented, NotSupported,
   NullReference, Timeout. Решта allocators Core не входять до цього кроку.
3. При читанні Clone встановлено окрему помилку: ArgumentTypeNotSupportedException
   виділяв ArgumentTypeClassNotSupportedException. Pointer і __NEW виправлено
   на власний concrete type. За попереднього коду clone не реалізував початковий
   IArgumentTypeNotSupportedException. Додано ArgumentTypeCloneIdentity
   до ExceptionTest для ручного запуску; цей тест не виконано.
4. У SimpleException, StandardExceptions, AggregateException додано caught flag,
   reset перед кожним TRY та assertion після кожного ENDTRY. Таким чином
   assertions усередині catch більше не є єдиною умовою успіху сценарію.
   Ці оновлені тести також не виконано.

XML validation, diff checks, compilation і runtime після цих правок не запускалися
за інструкцією власника. Попередні PASS у журналі стосуються попередніх редакцій.

## Завершення журналу XAE

Перша спроба (`core-current-check.json`) завершилась CreateDTE failure 0x80080005,
до відкриття solution. Повторна спроба поза sandbox встигла завершитися після
переривання turn: `core-current-check-unsandboxed.json` має Phase=Blocked,
помилку null-valued expression на фазі CheckAllObjects:Core, порожній Checks.
Тому факт успішної ST compilation не встановлено; сам phase не доводить,
чи завершився compiler call до збою збирання diagnostics. Reports позначають
RuntimeExecuted=false і TargetActivated=false. Нових спроб не робити.

## Погоджені межі aggregate — 2026-10-06

Власник погодив правила з максимумом 255 entries. Додано constant 255 і guard
до cloning/allocation/зміни масиву в гілці окремого inner. 256-та спроба викликає
existing fatal OUT_OF_MEMORY latch — погоджене позначення вичерпаної місткості,
не твердження про фізичне вичерпання heap. Public count лишається UINT.
Null/empty aggregate не додає entry навіть при повному списку. Flattening
incremental: попередні успішні additions не відкочуються при досягненні межі.

Self-add і cyclic inner graphs заборонені контрактом, без нового runtime guard
або обходу графа. Self-add не означає автоматичного створення циклу: aggregate
розгортає entries, а не зберігає aggregate reference. CopyFields вимагає empty
destination, відмінний від source. Правила записано біля declarations.

У Clone, CopyFields і GetMessage count явно перетворюється на DINT до віднімання
1. При count=0 верхня межа -1; попередній underflow не оголошено доведеним
compiler/runtime дефектом. Empty контракт: Empty=TRUE, GetInnerException=0,
root=THIS, default message="0 aggregated exceptions", окремий auto-disposed
clone зі скопійованими metadata, повторний Clear дозволений.

Перевірки не виконано за інструкцією власника. Для ручного запуску: empty
Clone/GetMessage/CopyFields на empty destination, повторний Clear; 255 additions;
256-та спроба без зміни buffer/count та terminal re-raise на межі runner.
Fatal сценарій тільки на ізольованому runtime з наступною переініціалізацією.
Сигнатури не змінено; нова межа є поведінковим обмеженням.
