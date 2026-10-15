# Core: погоджені рішення

Зведено 2026-10-16 із журналів та підтверджень власника. Це пам'ятка рішень,
не новий аудит і не заміна контрактів біля декларацій. Зміни реалізацій описані
за попередніми проходами; поточний runtime цим документом не підтверджено.

## Object і пам'ять

- Object.ReferencesEquals — FINAL, identity comparison; Objects.ReferencesEquals
  для двох null повертає TRUE, одного null — FALSE. Instance comparison із null — FALSE.
- ToLogString і кеш видалені. ClassName/NamespaceName сталі протягом життя
  instance; повернуті references тільки для читання.
- Objects.IsMemoryValid видалений: перевірка адреси не доводить lifetime.
  ProbeObjectReference — діагностична спроба QUERYINTERFACE із TRY/CATCH для
  обох розрядностей, без евристики меж стеку. TRUE не доводить, що початковий
  об'єкт живий, особливо після повторного використання адреси.
- Memory.GetAddressFromInterface використовує __QUERYPOINTER; null/невдала
  конверсія дає 0. Адреса borrowed, не перевірка lifetime.
- AutoDisposeRegistrar передає виключний ownership менеджеру. Ручне видалення
  або adoption іншим контейнером заборонене. FB_exit не кидає exceptions;
  callbacks cleanup не реєструють auto-disposed objects і не входять у cleanup
  повторно. Звільняти власні ресурси дозволено.
- Невдала allocation має terminal-поведінку: спільний latch і native
  OUT_OF_MEMORY без створення heap exception; raise одразу і на межі runner.
  Прапорець не скидається наступного циклу. Це не recoverable null result.
- Автоматичне повідомлення про кожне видалення та ObjectStatistics видалені.
  Порожній базовий FB_exit збережений для lifecycle через Object pointer.
- Raw pointers/interfaces не дають ownership чи lifetime tracking.
  Деталі per-task cleanup — у [Exceptions](exceptions-status.md).

## Interfaces

- IExecutable задає Execute; частоту, lifecycle та errors визначає спеціалізований
  API. IStartable/ICancellable не потрібні лише заради універсальності.
- INamed.Name і IErrorProvider.Error — borrowed read-only views; ST не забезпечує
  повної заборони запису. HasError/BoundToIO не слід довільно трактувати як
  загальний стан справності обладнання.
- ICloneable робить копію. Deep/shallow, lifetime і право видалення визначає тип.
  Користувацькі колекції exceptions не підтримуються; engine-managed aggregate —
  штатний сценарій. GenericValueFactory не має приймати auto-disposed exceptions
  як звичайні owned clones. Нових ownership flags/guards не додавали.
- IComparable залишений для майбутніх реалізацій; ComapreTo виправлено на CompareTo.
  Конкретний тип визначає сумісність; null/несумісний тип спричиняє exception.
  Порівняння не змінює operands і задає узгоджений порядок. IEquatable видалений.
- IComparer: caller обирає comparer і забезпечує сумісність та чинність даних.
  Реалізація визначає supported representations/null policy; автоматична
  конвертація або перевірка всіх TypeClass не гарантована.
- IPredicate.Check не змінює передані дані й колекцію обходу; власний стан дозволений.
- IEnumerable.CreateEnumerator створює незалежний dynamic cursor, який caller
  явно звільняє. Source borrowed і живе довше cursor. Невдалий NEW використовує
  спільний terminal allocation failure; RaiseAllocationFailure публічний для Collections.
- IEnumerator.Current — borrowed read-only; адреси не гарантовані після MoveNext,
  Reset або destruction. Current порожній до першого успішного MoveNext, після
  завершення та Reset. Reset ставить позицію перед першим елементом.
  Структурні зміни source під час обходу не підтримані. Reset splitting enumerators
  виправлено; оптимізацію повторного використання буфера не впроваджували.
- IResourceManager: без client; StartAcquire/StartRelease одноразово запускають
  фази, IExecutable.Execute просуває їх, idle Execute нічого не робить.
  Один caller керує неперекривними операціями, конфігурація стала до завершення.
  GetResource — borrowed object manager, доступний і до acquisition/після release.
  Underlying resource можна використовувати лише після acquisition до початку release.
  Зміна API вимагає адаптації зовнішніх callers/implementations.

## Actions

- Descriptor Name непорожній, глобальна унікальність не потрібна. Policy обирає
  name/interface/identity для розпізнавання. DenyAll показує порожнє ім'я як
  <empty>, відсутній reference як <unspecified>; це defensive behavior, не дозвіл null.
- Descriptor/requester/evaluator мають бути ненульові й живі. Рішення синхронне;
  arguments і rejectReason buffer borrowed тільки на час виклику.
- Policy оцінює дозвіл, не виконує дію/не змінює обладнання. FALSE записує причину;
  при TRUE очищення rejectReason не потрібне. Exception передається caller,
  результат/причина тоді не гарантовані.
- Automation перевіряє локальну policy, потім батьківські до першої відмови.
  Відсутня policy дозволяє свій рівень; потрібен дозвіл усіх рівнів.

## Events

- Один instance — одна подія, без Reset для нової події. Синхронна доставка
  позичає живий ненульовий event; recipients не утримують його після виклику.
- SourceObject може бути 0. Ненульове джерело borrowed, caller забезпечує його
  життя протягом життя event. Getter виправив власник.
- Handled незалежний від stopPropagation. Останній зупиняє bubbling угору або
  broadcast у поточне піддерево; сусідні гілки продовжуються.
- AutomationComponent має terminal BubbleEvent/BroadcastEvent; root і leaf
  отримують подію включно. IAutomationComponent підтримує IEventDispatcher;
  directional Core interfaces збережені. Порожній AutomationController.Broadcast видалений.
- Доставка незалежна від Enabled/operational state; реакцію вирішує handler.
  Exception перериває маршрут, вже виконані effects не відкочуються.
- SimpleEvent.Name непорожній, не обов'язково унікальний. Порожній default
  сигнатури не є допустимим значенням контракту; нових guards не додавали.

## System

- System.GetCurrentTaskIndex публічний; TASK_COUNT визначений лише в System
  за generated _TaskInfo. Внутрішній memory guard перевіряє cyclic context.
- Статичний масив TaskSystemState має окремі ADS FB, readiness, час/timezone,
  AMS address та sync interval для кожної задачі. Execute без BOOL result.
- SystemDataValid фіксує первинну готовність часу й timezone цієї task;
  AMS Net ID прибраний лише з умови готовності, його property збережена.
- Колишні VAR_OUTPUT часові поля стали read-only properties; читання збережене,
  запис/прив'язка до старих змінних несумісні.
- Поза cyclic context (index 0/-1): defaults, FALSE readiness, null SystemTime;
  Execute/set interval — no-op. FB_init через NEW у циклі має поточну task.
  Спільного fallback clock немає.
- Мілісекунди форматуються трьома цифрами, local time конвертується лише після
  bValid. GetTaskCycleTime очищує error; поза task дає 0 і ERROR без heap exception;
  множення періоду розширюється до ULINT до операції.
- Саморобний GlobalState/runner CycleCounter видалений на користь системного CycleCount.
  Це не робить LogManager чи всі custom callbacks потокобезпечними.

## Назви library placeholders — 2026-10-16

За дорученням власника Include у PlaceholderReference та відповідних
PlaceholderResolution узгоджено до назв TwinCAT Open Framework … із пробілами
в усіх PLC-проєктах Sources, включно з Temporary. Змінено лише ключі:
Resolution/DefaultResolution, дужки Referenced Library, namespaces, версії
й назви самих PLC-проєктів збережені. IDE reload/resolution та compilation
не перевірялися; перевірки виконує власник.
