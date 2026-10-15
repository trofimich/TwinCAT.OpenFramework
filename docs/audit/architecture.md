# Карта архітектури

Оновлено 2026-10-16 під час упорядкування матеріалів, без нового аудиту коду.

- Solution: Sources/TwinCAT.OpenFramework.sln. ST зберігається у XML/CDATA; object IDs треба зберігати.
- Core: Object/IObject, generic values, memory, exceptions, System, logging facade, базові interfaces.
- Comparision і Collections використовують Core. GENERIC_VALUE описує type/address/size/ownership; borrowing, cloning і adoption не тотожні.
- Automation: MAIN → AutomationRunner → controllers/branch/leaf; explicit initialization, cyclic execution, policies, events, permissions та IO. IO.Models відділено від Devices.IO.
- Tasks: кооперативні state machines acquire/process/release та queues. Timers і FileSystem використовують Tasks; Loggers використовує FileSystem.
- Workflow: окреме дерево activities, variables та dynamic-child registry, не scheduler Tasks. JSON і EventLogger — adapters.
- Tests: TcUnit suites через TestAutomationController/runner. Samples: intersection і workflow. Temporary — legacy, окремий scope.
- Library placeholders не доводять використання поточних sources. Квадратні дужки навколо назви у Resolution/DefaultResolution означають Referenced Library; зберігати їх при точкових правках project files.
- System має окремий TaskSystemState для кожної cyclic task. ExceptionManager і DynamicMemoryManager також мають per-task payload/registry. Це не гарантія thread safety всіх інших services.
- Exception — подія поточного циклу; ERROR — копія стану, яку можна зберігати довше. Зареєстровані exceptions належать DynamicMemoryManager; не всі dynamic objects автоматично реєструються.

Чинні рішення: [Core](core-contracts.md), [Tasks/FileSystem](tasks-contracts.md),
[Exceptions](exceptions-status.md). Межі дослідження і подальші питання:
[findings](findings.md), [перевірки](validation.md).
