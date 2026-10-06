# Тести Task та пов’язаних класів — 2026-10-05

## Межі роботи та статус

Додано тести в існуючий `Sources/TwinCAT.OpenFramework.Tests`, за його моделлю:
`FB_TestSuite`, виклики методів із тіла suite, `VAR_INST`, `TEST(__POUNAME())`,
assertions та одноразове `TEST_FINISHED()`. Нові suites створено як instances
у `TestAutomationController`; його наявний виклик `TcUnit.RUN()` збережено.
Production-код бібліотек не змінювався.

**ST compilation, TcUnit та PLC/runtime execution не виконано.** Нижче описано
написані сценарії, а не підтверджені результатами запуску можливості.
Історичні 22 тести зі спроби T00–T10 не є цим набором: він створений для поточних
Task/TaskQueue/Timer/FileContentManager після поступових погоджених змін.

## Що робили наявні тести

| Набір | Сценарій | Недоліки / внесені зміни |
|---|---|---|
| TaskSequenceTest | Три CounterTask послідовно накопичують 10+20+30; порожня черга скасовується | Збережено сценарій; додано watchdog 5 секунд і явне завершення з failure при несподіваному STOPPED. Це тест нормальної послідовності, а не покриття lifecycle |
| FileContentManagerTest | Запис двох рядків, seek у початок, читання й порівняння | Раніше завершувався при порожній черзі, не чекаючи зупинки/close. Тепер StopWhenNoPendingTasks=TRUE, очікування STOPPED, перевірка результату/cleanup flag, watchdog і явні failure paths; шлях береться з TaskTestSettings |
| DirectoryTest | Валідація шляхів; check/create/remove; create-if-missing/remove-if-present | Виправлено перевірку результату чужої задачі на етапі CreateDirectory. Інші недоліки залишено як пропозиції нижче |
| LoggerTest | Надсилання повідомлень і очікування завершення Logging | Це smoke test, який не перевіряє фактичний вміст файлів, порядок, кількість повідомлень чи ротацію |

## Додані сценарії

Розташування: `Tests/TaskLifecycle/`. Всього **53 методи в 5 suites**;
51 доступний за типовими налаштуваннями, 2 додаткові інтеграційні сценарії
вимкнено. Це кількість сценаріїв, не виміряне code coverage.

| Suite | Кількість | Перевірки |
|---|---:|---|
| TaskLifecycleTest | 18 | READY; відмови повторного Start/Cancel та Reset під час RUNNING; завершення й повторне використання; StateChanged; відмови hooks Start/Reset; internal abort, ERROR і exception; acquire перед роботою; очікування release; acquire/release exceptions; збереження OriginalStopReason при cleanup failure; cancel hook один раз; cancellation wait без звичайної роботи; раннє скасування без acquire; best-effort stop hooks; вже отриманий ресурс; exceptions cancellation hooks; Reset з OnAfterStop без повторного входу в роботу |
| TaskQueueLifecycleTest | 12 | Обидві політики порожньої черги; FIFO; автоматичне завершення; child Start refusal, final release failure та abort; Clear до першої child, зі current child та між children; Reset очищує залишок після STOPPED і не скидає children; READY Reset лишається no-op; null enqueue; parent release чекає child cleanup |
| TimerLifecycleTest | 8 | Нульовий interval; Restart під час роботи/після прийнятого Cancel/після завершення; SetIntervalAndRestart; відмова Reset; interval не змінюється при незавершеному cleanup; відлік від Start до першого Execute; Triggered до наступного Execute; Elapsed до Reset |
| FileTaskBindingTest | 3 | Повторне enqueue READY child після Clear/Reset старого parent; заборона зміни binding у RUNNING/STOPPED; повторне binding після Reset; очищення binding у READY. Файлові ADS операції тут не запускаються |
| FileTaskIntegrationTest | 12 | Binary write/tell/seek/read/EOF і close attempt; cancellation під час acquisition; cancellation при реальному bBusy для всіх семи file-content операцій; open failure; віддалений write/seek/read; short write без ADS bError |

Керовані `LifecycleTask`, `LifecycleResource`, `LifecycleQueue` дають змогу
відтворювати очікування та exceptions без ADS/файлів. Вони перевіряють контракт
Task і композицію, але не замінюють реальні інтеграційні тести.
`ObservedFile*` лише відкривають для тестів bBusy (і bError запису) наявного
файлового FB; production реалізація не підміняється. Допоміжні нащадки Timer
імітують відмову Reset і очікування cancellation.

## Як запускати вручну

1. Відкрити `Sources/TwinCAT.OpenFramework.sln`. Перевірити resolution бібліотек:
   Tasks, Timers і FileSystem повинні відповідати поточним sources, а не старим
   встановленим compiled libraries. Порядок для залежностей цих тестів:
   Core → Collections → Tasks → Timers/FileSystem → Tests; інші наявні залежності
   Tests також мають бути resolved. Додано placeholder Timers/namespace TOF_Timers.
2. Перед запуском налаштувати `TaskTestSettings.FileDirectory`: існуючий каталог
   на **PLC target**, доступний для запису, з кінцевим `\`. Типове значення `C:\`.
   Це не шлях на комп’ютері XAE, якщо PLC віддалений. За потреби змінити initializer
   до build/download або встановити значення до першого виконання контролера.
3. Тести створюють/перезаписують файли `OF_TaskRegression_*.dat` у цьому каталозі;
   файли залишаються для перевірки. Не використовувати ці імена для власних даних.
   `OF_TaskRegression_Missing_78430219.dat` має бути відсутній для open-failure case.
   Старі DirectoryTest/LoggerTest мають свої окремі шляхи, які цим GVL не змінено.
4. Побудувати Tests, завантажити на обраний власником тестовий PLC і запустити
   існуючий runner/controller. Перевірити TcUnit summary і конкретні assertion
   failures; відсутність exceptions чи заповнений ErrorList не є проходженням тестів.
5. Для повторного прогону реініціалізувати PLC/test instances: тестові finished
   flags не скидаються при повторному виклику RUN або online change.

Два вимкнені сценарії **не реєструються як passed/skipped**: guard знаходиться
перед TEST, тому їх немає в TcUnit results до увімкнення.

- `EnableRemoteFileTest`: задати реальний RemoteAmsNetId, ADS route і writable
  RemoteFilePath на віддаленому target. Тест перевіряє передачу адреси ресурсу
  дочірнім write/read, seek і readback; не налаштовує route самостійно.
- `EnableShortWriteTest`: підготувати окремий target/каталог з квотою або media,
  який повертає `cbWrite < cbWriteLen` **без bError**, задати ShortWriteFilePath та
  за потреби ShortWriteAmsNetId. Тест додає до файла до 64 KiB; він сам не заповнює
  диск і не створює квоту. Open failure, bError або повний write не відтворюють
  потрібний сценарій і дають failure підготовки, а не доказ дефекту short-write.

Файлові cancellation cases мають явно спостерігати bBusy (acquisition case —
ResourceAcquiring). Якщо операція завершилася без спостереження цього стану,
тест повідомляє, що сценарій не відтворено; це не автоматично дефект бібліотеки.
Watchdogs 5–20 секунд завершують тест з failure; після file timeout запитується
Cancel і метод продовжує Execute cleanup, поки suite викликається runner.
Watchdog не є фізичним abort ADS і не гарантує cleanup, якщо runner зупинено.

## Виконані перевірки

`docs/audit/check-task-tests.ps1` виконано: 45 XML source files Tests parsed;
407 object IDs унікальні; Compile includes існують, немає дублів та пропущених
реєстрацій; 53 нові методи викликаються suites, мають TEST_FINISHED; suites
інстанційовані в controller; Timers placeholder присутній. `git diff --check`
не виявив проблем. Це структурна перевірка, а не ST type checking або виконання
assertions. Нові XML відформатовано зі збереженням CDATA та IDs.

## Впорядкування після зауважень власника

Нові ST declarations/implementations приведено до оформлення наявних тестів:
табуляція для вкладених блоків, порожні рядки між логічними групами,
окремий рядок для кожної операції та розгорнуті IF/FOR. Короткі локальні
назви замінено на task, timer, taskQueue, fileContentManager, resourceManager,
firstTask/secondTask, executionIndex тощо. Невикористані шаблонні instances
та змінні видалено; ConfiguredResourceManager/ProcessingResult у fixtures
пояснюють їх призначення. Також відформатовано два змінені існуючі методи.
53 різні сценарії збережено; кількість тестів не зменшено за рахунок покриття.
Object IDs та production-код збережено. До структурної перевірки додано
контроль однолітерних декларацій, кількох statements на одному рядку та
нерозгорнутих IF/FOR. ST compilation/runtime після оформлення не виконано.

## Обмеження й наступні покращення

- ResourceAcquired=FALSE перевіряє завершення cleanup attempt. Воно не доводить
  фізичне закриття handle при best-effort close failure. Не вимагати FAILURE
  основної файлової операції тільки через close error — це контракт власника.
- Не відтворено реальний close failure/log message, ADS timeout із пізнім
  виконанням, багаторазове виснаження handle pool, online change чи всі комбінації
  public setters. Fake exceptions не перевіряють текст/кількість повідомлень logger.
- DirectoryTest: додати deadline та завершення при failure у CheckInvalidDirectory;
  замінити залежність від W:\ на керований відсутній шлях; налаштовуваний test root;
  якщо каталог уже існує, не завершувати create/remove case без перевірок;
  підтвердити існування після create і відсутність після remove. Працювати тільки
  з каталогом, який тест створив сам. Наявні directory tests ще можуть зависати.
- LoggerTest: перевіряти readback, порядок/кількість записів, flush і ротацію;
  перейти від очікування певної кількості cycles до deadline; ізолювати шляхи.
- Після першого manual run записати TwinCAT/TcUnit versions, library resolution,
  PLC target, cycle time, settings, кількість executed tests і failure details.
  Лише тоді можна позначати відповідні runtime сценарії перевіреними.
