# Core: Object і керування пам'яттю

Baseline: `f16e229409111fefb3bcf6aef7f9d0cc1cae9a91`, 2026-10-06.
Робота виконується невеликими кроками; кожна неоднозначна зміна поведінки
спочатку обговорюється з власником.

## C01 — підтверджені контракти, 2026-10-06

Власник підтвердив:

- Зареєстрований через AutoDisposeRegistrar dynamic object належить виключно
  DynamicMemoryManager до cleanup. Інші references є borrowed; ручне видалення
  та передача ownership іншому owner не дозволені. Відсутність unregister
  за цим контрактом не є дефектом.
- FB_exit нащадків Object і logger/filter під час видалення мають завершуватися
  без exceptions. Відсутність TRY/CATCH у Memory.TryRelease… за цим контрактом
  не є дефектом; Try означає можливість відмовити для null/non-dynamic адреси.

Ці правила записано біля декларацій Object.FB_exit, AutoDisposeRegistrar,
DynamicMemoryManager.RegisterAutoDisposedObject/CleanupMemory і Memory.TryRelease….
Логіка, сигнатури й object IDs не змінювалися.

Перевірки: чотири змінені XML sources parsed; зіставлення з Git HEAD підтвердило
незмінність усіх implementations, декларацій без line comments, сигнатур,
XML-структури та object IDs. git diff --check без зауважень.
ST compilation і TcUnit/runtime не виконано; поведінкових змін у C01 немає.

## C02 — allocation failure реєстру, 2026-10-06

Власник визначив нестачу пам'яті для реєстрації критичною помилкою: після неї
контролер має зупинитися. Відмову лише поточної операції з продовженням роботи
не використовувати. Погоджено системний exception одразу й повторне підняття
на межі runner, якщо внутрішній catch перехопив першу помилку.

Внесено у DynamicMemoryManager і AutomationRunner:

- Нова capacity обчислюється локально. Нульовий результат __NEW перевіряється
  до MEMCPY, видалення старого buffer, заміни pointer/capacity й запису slot.
- При невдачі встановлюється _AllocationFailed і викликається
  RaiseIfAllocationFailed: F_RaiseException(RTSEXCPT_OUT_OF_MEMORY), без
  створення framework exception, logging або cleanup. RETURN після виклику
  не дозволяє перейти до використання нульового pointer, якщо виклик повернеться.
- Flag не скидається cleanup і діє до переініціалізації PLC application.
  Наступний RegisterAutoDisposedObject перевіряє його перед іншими діями.
- Runner перевіряє flag у FINAL_ACTIONS перед exception/memory cleanup.
  Перевірка поза callback handlers; усі наявні JMP FINAL_ACTIONS до неї доходять.

Межі: зовнішній caller не повинен поглинати критичний exception із Runner.Execute.
У поточних Tests.MAIN і Samples.MAIN такого handler немає. Без runner application
має сама викликати RaiseIfAllocationFailed на зовнішній межі виконання.
Обробник callbacks може виконати свій catch і подальшу логіку до FINAL_ACTIONS;
це погоджена відкладена повторна сигналізація, не негайна зупинка всіх callbacks.
Cleanup після latched failure у нормальному епілозі runner не виконується.
Відновлення невдалої initialization об'єкта цим кроком не реалізується.
Підстава для зупинки при неперехопленому exception:
[Beckhoff F_RaiseException](https://infosys.beckhoff.com/content/1033/tcplclib_tc2_system/18097973515.html).

Перевірено статично: XML двох sources, збереження всіх 26 existing IDs,
унікальність нового method ID, порядок guard/commit і місце виклику runner.
Три інші sources попереднього C01 збережені побайтово. git diff --check пройдено.
ST compilation, source-to-library resolution і runtime stop НЕ перевірено.

Ручна перевірка на ізольованому runtime після збірки Core та Automation:

1. Звичайні allocation на 1/10/11 objects: успішна реєстрація, growth і cleanup;
   ExceptionTest як regression існуючого throw/catch на нормальній пам'яті.
2. У тимчасовій тестовій збірці замінити саме потрібний registry __NEW на результат
   0 (перший buffer, потім окремо growth при 10 objects). Не обнуляти успішно
   виділений pointer — це створило б штучний витік. Порівняти старі pointer,
   capacity/count безпосередньо перед спробою growth та в catch: незмінні;
   код exception = RTSEXCPT_OUT_OF_MEMORY.
3. Перехопити перший exception усередині callback: flag лишається TRUE,
   runner повторно піднімає код у FINAL_ACTIONS, PLC зупиняє виконання.
   Окремо перевірити неперехоплений перший exception і latched flag після cleanup.
4. Після кожного fatal сценарію повернути production source та переініціалізувати
   test application. Перевірити новий нормальний запуск. Це не підтримка resume
   попередньої невдалої initialization.

Injection перевіряє гілку обробки відмови; фактичне router-memory exhaustion
та поведінка __NEW/FB_init при ньому залишаються окремою runtime-перевіркою.

## C03 — опис фактичного API, 2026-10-06

Біля декларацій IObject/Object/Objects описано borrowed metadata/address,
SelfSize конкретного instance без окремих buffers, identity comparison,
відсутність автоматичної реєстрації в Object і кешування ToLogString.
Objects.Equals порівнює адреси без виклику overrides. Підстава: статичний
аналіз поточного коду, не нове підтвердження задуму власником.
Зіставлення до/після підтвердило лише коментарі: implementations, signatures,
XML structure та IDs збережено. ST compilation/runtime не виконано.

## C04 — перевірка concrete FB_exit, 2026-10-06

Додано ObjectExitProbe та ObjectLifetimeTest у Tests/Core; suite підключено
до PLC project і TestAutomationController. Два сценарії: __DELETE через
pointer конкретного типу та Memory.TryReleaseDynamicObject через IObject.
Обидва очікують рівно один виклик concrete FB_exit. Другий також перевіряє
обнулення переданого interface та повторний release як no-op. Counter живе
до синхронного видалення probe; dangling typed alias після release не читається.
Allocation failure позначає тест невдалим, а відмовлений release прибирається
через pointer конкретного типу.

XML, унікальність IDs, наявність Compile files, підключення suite й виклики
обох test methods перевірено статично. Тести НЕ виконані, ST compilation
НЕ виконано. Вони не доводять звільнення вкладених buffers або всі варіанти
багаторівневого успадкування. Дефект dispatch FB_exit не оголошено доведеним.

## C05 — задум IsMemoryValid, 2026-10-06

Власник уточнив: метод задумано саме для перевірки, чи об'єкт ще існує
в пам'яті, та надав приклад ekvip. Це усуває неоднозначність задуму, але
поточна реалізація не забезпечує такої гарантії. Статичний контрсценарій:
після видалення A його адресу повторно займає B із IObject; перевірка адреси
та query не можуть відрізнити B від початкового A. Runtime-відтворення немає.

Наданий приклад перевіряє memory area, alignment і query. F_CheckMemoryArea
документує область пам'яті, а не ідентичність/lifetime allocation. Stack
heuristic містить лише нижню межу. Catch у 32-bit гілці не перетворює
успішний доступ на доказ lifetime; у решті гілок query взагалі без catch.
Джерело: [Beckhoff F_CheckMemoryArea](https://infosys.beckhoff.com/content/1033/tcplclib_tc2_system/4012887435.html).

Callers IsMemoryValid у Sources не знайдено. Власник погодив видалення;
метод видалено разом із його XML node. Решту IDs збережено. Це зміна public
API: зовнішні споживачі, якщо вони викликали метод, потребуватимуть правки.
Перевірку existence не замінено іншою heuristic. XML і відсутність залишкових
посилань у Sources перевірено статично; ST compilation/runtime не виконано.
Реєстр generations/handles заради цього методу не вводиться.

## C06 — стандартне отримання адреси instance, 2026-10-06

За прямим погодженням власника Memory.GetAddressFromInterface використовує
__QUERYPOINTER замість віднімання pointer size від внутрішньої interface адреси.
Сигнатуру й existing IDs збережено. Результат явно 0 для null або невдалої
конверсії; для живого interface повертається borrowed адреса FB без передачі
ownership. Це не перевірка lifetime. Підстава зміни: усунення залежності від
внутрішнього layout через документований оператор, не runtime-доказ дефекту.
[Beckhoff __QUERYPOINTER](https://infosys.beckhoff.com/content/1033/tc3_plc_intro/2529181835.html).

У ObjectLifetimeTest додано порівняння з адресою конкретного dynamic instance,
окремий тест static instance та null одразу після успішної конверсії.
XML/IDs і diff перевірено статично. ST compilation і TcUnit/runtime не виконано;
зокрема різні interface offsets і target architectures runtime не перевірені.

## C07 — межі cleanup, 2026-10-06

Додано TcUnit scenario RefuseStaticObjectRelease: FALSE, interface незмінний,
FB_exit не викликано. Counter і probe мають VAR_INST lifetime. Доповнено
опис IsDynamicData: класифікація області не доводить lifetime/ownership.
Production behavior не змінено. XML/IDs і підключення test method перевірено
статично; ST compilation і runtime не виконано.

Початкова неоднозначність: no-exceptions контракт сам по собі не забороняє
реєстрацію нового auto-disposed object у FB_exit чи disposal logger/filter.
Наприклад, під час видалення останнього зареєстрованого object logger створює
новий object із registrar; після повернення cleanup скидає count і губить
його реєстрацію. Повторний CleanupMemory із FB_exit також небезпечний, бо
поточний slot ще не обнулено. Це статичні умовні сценарії, не runtime-доказ;
власник підтвердив заборону реєстрації та повторного cleanup із цих callbacks.
Власні ресурси звільняти дозволено. Правило записано біля CleanupMemory,
RegisterAutoDisposedObject, Object.FB_exit та AutoDisposeRegistrar.
Нові runtime guards або черги не додано: це передумова використання,
не перевірка на рівні реалізації. Сценарії вище порушують уточнений контракт;
їх не класифікуємо як дефект за допустимого використання.

## Відкриті наступні кроки

Продовження в group 2: registry allocation guard винесено в INTERNAL
RaiseAllocationFailure, який встановлює existing latch і піднімає native code.
За підтвердженням власника його використовує також null allocation у
SystemException.Clone. Семантика runner boundary/C02 збережена.
SystemException тепер opt-in auto-disposed. Деталі: core-exceptions-review.md.

- C02: реалізовано й статично перевірено; compilation і runtime scenarios вище
  залишаються невиконаними. Інші allocation sites історичного OF-007 не змінено.
- Objects.IsMemoryValid: C05 завершено погодженим видаленням API.
- Видалення через POINTER TO Object: перевірити виконання cleanup конкретного
  нащадка й усіх необхідних FB_exit у runtime; два тести C04 підготовлено,
  але не виконано. Витік не оголошено доведеним.

Інші необов'язкові покращення першого проходу не розпочато.
