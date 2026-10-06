# TaskQueue: статичний review 2026-10-04

Прочитано поточні TaskQueue, StandardTaskQueue, FileContentManager, релевантні
Task lifecycle paths, FileContentTask, List.RemoveAt/Clear, TaskSequenceTest та
enqueue/reset callers SimpleTextFileLogger. Код не змінено, ST compilation і
runtime tests не виконано. Нижче — докази за кодом, не runtime reproduction.

## Q1 — Використання Original замість Final

TaskQueue:162–166 оцінює child.OriginalStopReason. За актуальним контрактом
child може мати Original=WORK_DONE, Final=FAILURE через throwing release.
Черга видалить таку child як успішну та продовжить наступну роботу.
Пропозиція: читати FinalStopReason для WorkDone, Value і Message разом.
Це не змінює best-effort file close, який не породжує FAILURE.

## Q2 — Відмова child.Start пропускає роботу

TaskQueue:150 ігнорує BOOL/refuseReason Start. Якщо підготовка child відмовляє,
вона залишається READY. Гілка READY на 158–159 одразу видаляє її зі списку.
Черга може успішно завершитися без виконання цього елемента.
Пропозиція: при Start=FALSE завершувати queue з ERROR і повідомленням відмови;
не видаляти child як успішну. READY для вже selected child теж не є успіхом.

## Q3 — Reset не узгоджує current і стан children

OnReset:129–132 викликає Reset для children у списку, але не очищує _CurrentTask.
Після cancel/failure A залишається current і в списку. Queue.Reset переводить A
у READY, Queue.Start запускає parent; наступний OnRunning викликає A.Execute,
не A.Start. READY branch видаляє A, пропускаючи повторне виконання.

Окремо ігнорується результат child.Reset: якщо вона відмовила, queue все одно
може перейти в READY. Мінімальний напрямок: перевіряти Reset results, передавати
відмову через existing OnReset exception/refuseReason mechanism і очищувати
current після успішної підготовки. Частковий reset не потребує автоматичного
rollback, але не повинен оголошуватися повністю успішним.

Спершу уточнити семантику: Reset повторює залишок черги чи очищує його?
Уже успішні children видаляються, тому Reset не повторює початкову послідовність.
Для повторення залишку FileContentManager потребує окремої інтеграційної уваги:
FileContentTask.OnReset очищує borrowed handle reference, а призначення відбувається
в Enqueue. Самого обнулення current недостатньо для повторного використання
таких children без відновлення їхньої конфігурації. Не міняти це автоматично.

## Q4 — ClearWaitingTasks

На рядку 46 зворотний цикл не має BY -1. За документацією Beckhoff default step
дорівнює +1: https://infosys.beckhoff.com/content/1033/tc3_plc_intro/2528280971.html
Для списку з трьох елементів цикл 2 TO 1 не виконається. Для списку з одного
елемента цикл 0 TO 1 видаляє current під індексом 0, потім RemoveAt(1) кидає
out-of-range exception. List.RemoveAt має явну перевірку меж.

Навіть із BY -1 логіка потребує визначення фактичної current:
- RUNNING не гарантує _CurrentTask<>0. До запуску першої child або між children
  всі елементи очікують; збереження індексу 0 залишає одну waiting task.
- Поза RUNNING список очищується, але _CurrentTask лишається. Після cancel/failure
  подальший старт може виконувати обробку вже вилученої child; при видаленні
  старої current removeCurrentTask видаляє індекс 0 вже нового списку.

Пропозиція: зберігати тільки фактично поточну задачу під час виконання; якщо її
немає, очищати весь список. При очищенні завершеної черги скидати й current.
Для зворотного циклу вибрати межі та лічильник, які допускають завершення циклу
без виходу за subrange DINT_INDEX, особливо коли видаляється також індекс 0.

## Що залишити простим

External cancellation уже передається current і просуває її до завершення перед
parent release; pending children при цьому не стартують. Borrowed storage
не видаляє самі task objects. Ці рішення доречні.

Корисно документувати: lifetime children забезпечує caller; після enqueue
виконанням керує queue; дозволені стани enqueue та duplicates мають явний
контракт. PendingTaskCount зараз включає current, що лишається в списку.
Не додавати scheduler, нові стани, retry policies чи численні guards без потреби.

Порядок невеликих кроків: Q1, Q2, узгодження reset policy і Q3, Q4.
Перед визнанням працездатності потрібні ручні сценарії кожного запису, зокрема
ClearWaitingTasks для 0/1/2/3 елементів і RUNNING без current.

## Q1 виправлено окремим кроком — 2026-10-04

У TaskQueue.OnRunning усі три читання child result (WorkDone, Value, Message)
переведено з OriginalStopReason на FinalStopReason. Child із WORK_DONE/FAILURE
тепер дає queue ERROR і final message замість видалення як успішної.
XML та незмінність решти методів перевірено; ST/runtime не запускалися.
## Q2 виправлено окремим кроком — 2026-10-04

OnRunning перевіряє child.Start, передає refuseReason в stopReasonMessage і
повертає ERROR без видалення child при відмові. Неочікуваний READY для поточної
child теж дає ERROR, а не видалення як успішної. Наступний елемент не стартує.
Перевірено XML, guard Start=FALSE/RETURN, відсутність remove в READY branch і
незмінність інших methods. ST compilation/runtime не запускалися.
## Q3 попереднє рішення — замінене наступним уточненням

Власник підтвердив: Reset має зберігати залишок і готувати його до повторного
запуску. OnReset перевіряє Reset кожної задачі. Відмова передається через
StandardException до наявного Task.safeCallOnReset: queue.Reset повертає FALSE
із повідомленням child та залишає parent у STOPPED. Уже скинуті children не
відкочуються; наступний Reset може повторити спробу.
Після успішного проходу _CurrentTask := 0; список та порядок не змінюються.
Наступний запуск викликає Start першої задачі залишку. Уже успішно завершені
й видалені задачі не повертаються до черги.

Перевірено XML parsing, збереження всіх object IDs та незмінність інших методів
на цьому кроці. Статично звірено передачу помилки з Task.safeCallOnReset і
перехід у READY лише після його успіху. ST compilation і runtime не виконано.
Ручні сценарії: cancel A при waiting B → Reset → Start A, потім B;
відмова Reset A/B → FALSE і STOPPED; повтор після усунення відмови;
порожній залишок → успішний Reset без звернення до child.

FileContentManager потребує окремої перевірки конфігурації залишених задач:
FileContentTask.OnReset очищує borrowed handle, який призначався під час Enqueue.
Поточна зміна готує lifecycle; вона не відновлює конфігурацію файлових задач.
FileSystem у цьому кроці не змінено.

## Уточнення Q4 після правки власника

Власник додав BY -1 і змінив лічильник на DINT. ClearWaitingTasks не змінювався
під час виправлень Q1–Q3. Залишився сценарій RUNNING без _CurrentTask:
індекс 0 зберігається, хоча всі задачі ще очікують. Старий сценарій перенесення
stale current через успішний Reset усувається Q3; старий опис Q4 слід читати
з урахуванням цього. Повне виправлення Q4 не підтверджене runtime.

## Q3 чинне рішення: Reset очищує чергу — 2026-10-04

За новим погодженням власника OnReset виконує лише _SubTasks.Clear() та
_CurrentTask := 0. Цикл child.Reset і StandardException видалено. Об'єкти children
не видаляються і не скидаються; для повторного запуску caller готує й додає їх
заново. Попередні сценарії повтору залишку та відмов child.Reset більше не
описують контракт черги. Відновлення файлової конфігурації збереженого залишку
більше не потрібне, оскільки залишок не зберігається.

Контракт базового Task не змінений: Reset у READY не викликає OnReset і не
очищує список; для цього є ClearWaitingTasks. Reset у RUNNING відхиляється.
Перевірено XML, незмінність object IDs і відсутність змін поза OnReset у POU.
Компіляція ST та runtime не виконані. Ручна перевірка: після зупинки черги з
залишком викликати Reset — PendingTaskCount=0, стани children незмінні;
додати підготовлену задачу і запустити; окремо перевірити READY no-op.

## Q4 виправлено; контракт Enqueue уточнено — 2026-10-04

ClearWaitingTasks очищує весь список і _CurrentTask, якщо черга не RUNNING
або current відсутня. Лише RUNNING із current зберігає індекс 0 і видаляє решту.
Це охоплює проміжок перед першою child та між children. BY -1 і DINT збережені.
Статично розглянуто порожній список, 1 та кілька елементів: без current список
очищується; із current зберігається тільки вона. Об'єкти tasks не видаляються.

У EnqueueTask і публічному StandardTaskQueue.Enqueue задокументовано READY,
відсутність повторного додавання, lifetime borrowed object і керування lifecycle
чергою до вилучення. Нових runtime guards не додано: це передумови caller.
Перевірено XML, IDs і обмеження змін трьома погодженими методами.
ST compilation та runtime/TcUnit не виконувалися.
