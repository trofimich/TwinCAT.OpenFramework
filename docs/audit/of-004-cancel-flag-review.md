# OF-004: перевірка CancelRequested / CanStop

Дата: 2026-10-02. Нижче збережено історичний review правок власника до виправлення агентом. Посилання на рядки в історичному review відповідають тій версії. Попередній recheck snapshot також описує попередню версію.

## Поточний статус після погодженого виправлення

За запитом власника змінено Task.TcPOU і TaskQueue.TcPOU без нового стану:

- Task.Cancel викликає OnCancelRequested один раз на прийнятий запит. TaskQueue передає Cancel поточній running child.
- Task.handleRunning під час pending cancellation викликає OnCancelling, потім перевіряє CanStop. Якщо child ще running, повертається без звичайного OnRunning.
- TaskQueue.OnCancelling виконує тільки current child; не запускає наступних завдань і не переносить stop reason child у parent.
- Коли child вже не running, parent викликає OnBeforeStop і починає власний release. Для parent без resource після STOPPED/OnAfterStop додано RETURN.
- Нові safe wrappers журналюють exceptions; виняток callback не обходить CanStop.
- Збережено попередні object IDs; додано IDs для нових methods. Назву старого TaskQueue.OnBeforeStop змінено на OnCancelRequested.

Виконано: XML parsing 14 файлів бібліотеки Tasks, перевірку відсутності повторних method names та object IDs у цій бібліотеці, git diff --check і статичний review порядку cancellation. Помилок цих перевірок не знайдено.

Не виконано: ST compilation і runtime/TcUnit regression. Відомий попередній MSBuild blocker описано у validation.md; його не обходили і збірку цього виправлення не запускали. Статус OF-004: **виправлення внесено й статично перевірено; runtime підтвердження очікується**. Regression cases наприкінці документа залишаються задачами для execution.

## Правильний напрямок

Cancel записує `_CancelRequested` та EXTERNAL_CANCEL. Composite залишається RUNNING / PROCESSING, поки CanStop=false; OnRunning продовжує виконувати child. Це відповідає погодженому контракту без нового підстану. Але запит child та завершення parent наразі розташовані неправильно.

## 1. Child не отримує запит Cancel, поки вона сама не зупинилася

[Task.Cancel:83](../../Sources/TwinCAT.OpenFramework.Tasks/Task/Task.TcPOU#L83) лише записує запит. [Task.handleRunning:193](../../Sources/TwinCAT.OpenFramework.Tasks/Task/Task.TcPOU#L193) викликає safeCallOnBeforeStop на :196 тільки за `_CancelRequested AND_THEN CanStop`.

[TaskQueue.CanStop:42](../../Sources/TwinCAT.OpenFramework.Tasks/TaskQueue/TaskQueue.TcPOU#L42) повертає false, поки current child.State.Running. При цьому єдиний child.Cancel для цього lifecycle path знаходиться в [TaskQueue.OnBeforeStop:94](../../Sources/TwinCAT.OpenFramework.Tasks/TaskQueue/TaskQueue.TcPOU#L94).

Trace: parent.Cancel → pending request → child running, CanStop=false → callback не викликається → child.Cancel не надходить → parent.OnRunning продовжує звичайну роботу child. Якщо child завершиться сама, parent дочекається; якщо child має працювати до Cancel, parent чекатиме без кінця.

Конкретна композиція: StandardTaskQueue із FileContentManager як current child; FileContentManager із StopWhenNoPendingTasks=false залишається RUNNING навіть після спорожнення своєї черги. Parent.Cancel не передає child запит, отже та не починає звільнення handle. Це статичний сценарій, не фактично виконаний тест.

## 2. Після STOPPED продовжується processing

[Task.handleRunning:206](../../Sources/TwinCAT.OpenFramework.Tasks/Task/Task.TcPOU#L206) встановлює STOPPED для cancel у PROCESSING без acquired parent resource. Після OnAfterStop немає RETURN або перевірки State. Код переходить до другого CASE на :213; підстан залишається PROCESSING. На :243 викликається OnRunning вже після зупинки.

Trace без child: queue має pending task, але _CurrentTask=0; Start, потім Cancel до першого Execute. CanStop=true, parent переводиться у STOPPED, але TaskQueue.OnRunning на :123–126 запускає першу pending child. Подальші parent.Execute викликають OnStopped, а child лишається RUNNING без виконання parent. Це знову створює незавершений child lifecycle.

Для звичайної leaf task також можливі додатковий OnRunning після Cancel і перезапис EXTERNAL_CANCEL на результат OnRunning на Task:246, повторний stop callback. Це наслідки одного fall-through, а не окремий аудит leaf behaviors.

## Напрямок мінімального виправлення без нових станів

- Запит зупинки child передавати **до очікування CanStop**, один раз на прийнятий Cancel. Можна окремим OnCancelRequested callback, або зміною моменту виклику OnBeforeStop з урахуванням усіх його descendants. Не викликати callback кожного циклу й повторно при завершенні того самого cancel.
- Продовжувати child.Execute під час очікування, залишаючи parent RUNNING / PROCESSING. Не запускати нових children під час cancellation.
- Після встановлення STOPPED і OnAfterStop завершувати handleRunning або перевіряти, що State усе ще RUNNING перед другим CASE. RESOURCE_RELEASING можна обробляти за поточним алгоритмом, поки parent лишається RUNNING.
- Зберігати EXTERNAL_CANCEL за прийнятим контрактом і скидати pending flag при завершенні/reset; окремо визначати пріоритет child failure під час cancel.

Потрібні runtime regression cases: child із delayed release; child, що не завершується без Cancel; parent без resource; parent із власним resource; Cancel одразу після Start до першого Execute; кілька pending children; повторний Cancel. Це перелік для подальшої перевірки, не результати виконання.
