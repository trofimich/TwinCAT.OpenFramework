# Винятки: підсумок E1–E9

Зведено 2026-10-16 з читання коду та погоджень власника, без нового аудиту.
Обговорені E1–E9 завершені; невирішених рішень у цьому scope немає.
Останні compilation/runtime залишаються власнику; це не доказ відсутності всіх багів.

## Lifetime і transport

- Exception — подія поточного PLC-циклу; ERROR зберігає стан довше. Користувацькі
  колекції exceptions не підтримані. Dynamic exceptions виключно належать
  DynamicMemoryManager, не передаються між tasks і не видаляються вручну.
- У FB_init не виконують Throw і не створюють dynamic exceptions; статичні
  templates допустимі. Shared templates не можна одночасно змінювати з різних tasks.
- ExceptionManager має per-task payload і SystemException wrapper, memory manager —
  per-task registry/cycle/missed-cleanup counter. System.TASK_COUNT — єдине джерело меж.
  Non-cyclic exception operations відхиляються native guard без heap exception.
- CleanupMemory очищує свою task і скидає payload; fallback при новій registration
  очищує пропущений попередній цикл своєї task. MissedCleanupCount насичується
  на UDINT maximum, звичайне cleanup не скидає його. Це діагностика, не заміна
  регулярного cleanup.
- Shutdown CleanupAllTasks дозволений лише при зупиненому cyclic execution.
  FB_exit/callbacks не кидають, не реєструють auto-disposed objects і не входять
  у cleanup повторно. Власні ресурси звільняти дозволено.
- Allocation failure: global terminal latch, коротка critical section тільки
  для flag; NEW/DELETE/callbacks/raise поза lock. Після failure raise одразу,
  потім повторно на boundary. Latch не скидають щотакту. Lock Enter failure теж
  піднімає native OUT_OF_MEMORY, не записує latch без lock.
- Без AutomationRunner caller наприкінці кожної task після всіх consumers,
  поза recoverable catch, виконує:

```structuredtext
TOF_Core.DynamicMemoryManager.RaiseIfAllocationFailed();

TOF_Core.ExceptionManager.Cleanup();
TOF_Core.DynamicMemoryManager.CleanupMemory();
```

Це підтримка exception transport/cleanup у кількох tasks, не загальна
thread safety LogManager, AutomationRunner чи custom callbacks.

## Представлення й вкладення

- Framework timestamps фіксуються на Throw. Native timestamps — на GetLastException,
  оскільки точного native Throw time немає. Clone зберігає час.
- SystemException — shared mutable wrapper поточної task; перед вкладеним handling,
  яке може його перезаписати, потрібен Clone. showSource не має даних native source;
  найближча доступна інформація — catch point.
- Native повторно пропагується framework-обгорткою. ReThrowLastException залишений
  для caught code/context; збережений object передається через Throw(exception).
- Source/SourceMessage — read-only references за контрактом. InnerException,
  GetRootException та GetInnerException повертають IReadOnlyException.
- GeneralException із own code=0 та own message='' є empty. Якщо inner непорожній,
  caller зобов'язаний мати власний message або code; runtime guard не додавали.
- Static inner клонується; dynamic inner позичається до cleanup і не змінюється
  через інші aliases/Clear. Підготовлений граф має бути acyclic, зокрема custom types.
- При додаванні перевіряється, чи incoming graph досягає owner. Перевірка до
  mutation; порушення піднімає StandardException. EXCEPTION_GRAPH_PATH та
  надмірний загальний обхід видалені за погодженим спрощенням.
- Aggregate: максимум 255 entries; 256-й — terminal allocation failure навіть
  без фізичного heap exhaustion. Null/empty additions не займають entry.
  Flattening incremental, раніше додане не відкочується при capacity/allocation failure.
- Aggregate володіє масивом, не вкладеними engine-managed causes. Clear очищує
  масив/count/base; Clone має власний масив, використовує prepared causes.
  CopyFields потребує іншого порожнього destination.
- Empty aggregate: Empty=TRUE, GetInnerException=0, root=THIS,
  default message "0 aggregated exceptions", окремий clone з metadata;
  повторний Clear допустимий. Count перед відніманням 1 розширюється до DINT.
- ToError aggregate використовує root першої cause і повідомлення агрегату.
- EmptyException/IEmptyException видалені. Старі назви Incompartible та
  StringOwerflow не перейменовані заради косметики API.

## Повідомлення і конкретні групи

- ERROR_MESSAGE — WSTRING(2000); надлишок обрізається до 1999 + ellipsis,
  без нового overflow exception. WideStrings.ELLIPSIS — спільна constant.
- StringBuilder/WideStringBuilder копіюють same-encoding fragments без проміжного
  обмеження 255. Self-append зберігає old buffer до копіювання; size math ULINT,
  terminator враховується один раз. Інші ANY conversions мають власну межу 255.
- Argument/DataMember value text >255 — 254 + ellipsis. Перевіряється actual
  length, не capacity; сканування має циклічну ціну.
- POINTER/REFERENCE показують адресу даних, а не storage descriptor;
  ширина hex SIZEOF(PVOID)*2. REFERENCE закрито рішенням власника, не runtime тестом.
  DWORD/ LTIMEOFDAY conversion pointer types виправлені.
- Unsupported ANY показує type class і size, не випадковий перший байт.
  Старі закоментовані TYPECLASS cases видалені.
- ArgumentTypeNotSupported/DataMemberTypeNotSupported Clone мають правильний
  concrete type. GenericValues/Memory exception groups задокументовані:
  умову визначає caller, exception сам не вимірює capacity чи allocator.
- NotSupported потребує непорожнього повідомлення від caller; guard не доданий.
  NullReference message: Required reference 'name' is not assigned.
- VAR_IN_OUT CONSTANT міграція лише для diagnostic strings довших за 255.
  ClassInitialization/InvalidPath.errorMessage та ERROR.Fill source255 — VAR_INPUT.
  Старий режим InvalidPath.path збережений; Concat/Append convenience helpers не мігрували.

## Policies і logging

- IExceptionHandler видалений як попередній задум, замінений policies.
- Policy аналізує контекст і повертає реакцію, не піднімає й не обробляє вкладені
  exceptions, навіть непрямо. IGNORE лишає logging, не встановлює Error/не зупиняє
  компонент; initialization має окрему critical/INVALID поведінку.
- Logging APIs приймають IReadOnlyException, borrowing тільки під час виклику.
- EventLogger aggregate fold починається з TRUE (виправлення власника);
  numbered text зберігає prefix, використовує TryAppendToTarget і ELLIPSIS.
- TryAppendToTarget може частково записати та повернути FALSE при truncation;
  wrong target дає FALSE без зміни, heap/overflow exception не потрібні.
- SimpleTextFileLogger: "#number: [category] text", bounded append і ellipsis;
  TRUE означає прийнято до буфера, не записано на диск. Локальний textToLog
  (4002 bytes) залишений за рішенням власника; const message не змінюється.
- AdsLogger передає messageNumber також для singleton aggregate.
- Core Referenced Library відновлено у 13 projects. Дужки навколо library title
  у Resolution не прибирати. Temporary залишений як був; походження втрати дужок
  не встановлено. IDE resolution після reload ще потребує перевірки.

## Відоме обмеження і наступний крок

На TwinCAT 3.1.4026.27 власник отримував 3902013441 замість native 28 ще при
первинному F_RaiseException. Обгортка зберігає отримане, але не відновлює
втрачений код. Колізія з framework transport може також зробити старий payload
неоднозначним. Виправлення цього runtime обмеження не заявлено.

Наступний крок — [перевірки власника](validation.md). Необов'язкові спрощення
ToError/helpers не є дефектами чи автоматично дозволеною перебудовою.
Повний аудит Logging/Collections/Automation цим проходом не заявляється.
