# Відкриті питання та межі аудиту

Актуалізовано 2026-10-16 шляхом зведення журналів, без нового аналізу реалізацій.
Цей список не є дорученням автоматично виправляти все перелічене.

## Що потребує подальшого розгляду

- Первинний native exception code у TwinCAT 3.1.4026.27: власник спостерігав
  3902013441 замість 28. Обгортка не відновлює інформацію, втрачену до catch.
  Деталі й межі — [Exceptions](exceptions-status.md).
- Загальний аудит allocation sites (OF-007) був виключений власником із початкового
  review. Локальні guards у memory/exceptions/enumerators/builders не доводять
  охоплення всіх Collections/GenericValueFactory. Перед висновками читати поточний код.
- Поза погодженим Objects scope залишився попередній [огляд Core classes](core-classes-overview.md).
  Зокрема CC-02 — одиниці розміру wide split, CC-04 — сирі строкові fragments,
  CC-06 — outputs/lifecycle LinearRamp, CC-07 — GenericValueValidator.
  Статуси цих кандидатів треба звірити з актуальним кодом; не вважати старі
  рядки доказом поточного дефекту. CC-01/03/05 пізніше опрацьовані.
- Lifecycle reentry з Task callbacks поза конкретними погодженими шляхами
  не має загального нового контракту. Non-throwing resource getters погоджено;
  гіпотетичне throwing getter саме по собі не є дефектом допустимого usage.
- Повний non-throwing/thread-safety контракт logging/filter та інших services
  не доведений. Заборона exceptions у cleanup callbacks і exception policies
  не є автоматичною гарантією всіх custom loggers.
- Повний аудит GENERIC_VALUE ownership, clone/adoption, concrete enumerators,
  IO processing frequency, JSON dynamic structures і решти utilities не завершений.
- Історична документація Guides/Concepts може відставати (назви типів, runner,
  IO напрямки); її не переписували під час цього прибирання.
- DirectoryTest/LoggerTest мають окремі питання ізоляції шляхів, deadlines,
  readback та повноти assertions: див. [task tests](task-tests-2026-10-05.md).

## Погоджене, що не слід відкривати заново без нових доказів

- Object/Interfaces/Actions/Events — [Core contracts](core-contracts.md).
- Tasks/FileSystem — [чинні рішення](tasks-contracts.md), не відкатаний T00–T10.
- E1–E9 — [Exceptions status](exceptions-status.md); залишилися перевірки та
  відоме runtime обмеження, а не черга непогоджених контрактів.
- OF-001/002/003/005 були виправлені за історичним статичним review.
  OF-006 закритий погодженням best-effort close і виправленням logging.
  OF-004 оцінювати за чинною cancellation моделлю після відкату.
  OF-008: обидва конкретні сценарії підтвердив власник; інші paths не охоплені.

Відсутність тесту не доводить дефект. Відрізняти читання коду, погодження власника
та фактичний runtime результат. Нові перевірки не виконувалися.
