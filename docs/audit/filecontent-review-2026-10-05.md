# FileContentManager review — 2026-10-05

Статичний review; PLC-код не змінено, ST compilation і runtime не виконано.
У FileSystem знайдено один прямий нащадок TaskQueue: FileContentManager.
Детально прочитано FileContentManager, FileHandleResourceManager, FileHandleResource,
FileContentTask/IFileContentTask, сім конкретних file-content tasks, FileContentManagerTest.
Звірено Task/TaskQueue cancellation/reset, integration paths SimpleTextFileLogger;
інші filesystem tasks та весь logger не проходили повного аудиту.

## FSQ-1: child STOPPED до завершення ADS operation

Висока впевненість у статичному переході; наслідки I/O не відтворені.
У семи конкретних children тільки OnRunning просуває FB_File* і перевіряє bBusy.
OnCancelling не перевизначено: Task base повертає TRUE, ResourceManager=0.
Cancel під час bBusy → наступний child.Execute переводить child у STOPPED,
не викликаючи її файловий FB. Queue бачить STOPPED і починає close parent handle.
Немає гарантії завершення read/write перед close/повторним використанням буфера.
Пропозиція: callbacks cancellation просувають тільки вже почату операцію до
NOT bBusy, не запускаючи нову; використати existing readyToStop без нових станів.

## FSQ-2: cancel під час pending open

FileHandleResourceManager.ReleaseResource:210 при !_FileHandleAcquired викликає
_FileOpen(FALSE) один раз і повертається. Task бачить ResourceAcquired=FALSE і
може завершитися, хоча open response ще не опрацьована; flag встановлюється
тільки в AcquireResource. Статично відсутнє очікування pending open і закриття
пізно отриманого handle. Фактичний витік — ризик, runtime не підтверджений.
Потрібно окремо узгодити очікування pending acquire у межах existing resource
contract; не змінювати ResourceAcquired на busy без аналізу його семантики.
Це pending-operation issue, не спростований best-effort close contract OF-006.

## FSQ-3: READY child після вилучення неможливо просто додати повторно

Висока впевненість, статичний сценарій:
Enqueue(B) прив'язує resource → ClearWaitingTasks до запуску B (або queue cancel
і Reset з B у залишку) → B лишається READY з прив'язкою → B.Reset no-op →
повторний Enqueue(B) кидає FileHandleResource already assigned.
Докази: FileContentManager.Enqueue:76, FileContentTask.OnReset:67,
SetFileHandleResource:79, Task.Reset READY branch. Доступний явний detach через
SetFileHandleResource з invalid reference, але звичайний Reset/re-enqueue не працює.
Пропозиція для обговорення: дозволити rebind у READY (ownership забезпечує caller),
забороняючи зміну resource активної задачі. Не змінювати Task.Reset для всіх задач.

## FSQ-4: partial write оголошується WORK_DONE

WriteBytesToFile.OnRunning:143 завершує задачу за NOT bBusy без порівняння
cbWrite і cbWriteLen. Beckhoff прямо описує partial write без bError/nErrId,
наприклад на повному носії. ActuallyWrittenBytes доступне caller, але queue
видаляє задачу як успішну; SimpleTextFileLogger перевіряє лише FinalStopReason
і очищує send buffer перед наступною порцією. Висока впевненість у можливості
непоміченої втрати записів за такого результату FB; runtime не відтворено.
Мінімально: ERROR при cbWrite<>cbWriteLen після завершення, без auto retry.
Source: https://infosys.beckhoff.com/content/1033/tcplclib_tc2_system/30986763.html

## FSQ-5: remote target не передається children

Manager.AmsNetId налаштовує open/close, але Enqueue передає лише resource.
Child має окремий sNetId через AmsNetId; FileHandleResource не містить target.
Caller може вручну узгодити обидва значення, тому це conditional integration issue.
У SimpleTextFileLogger налаштовується manager.AmsNetId, але не _WriteBytesTask.AmsNetId:
remote open і write потрапляють на різні targets. Висока впевненість у wiring
mismatch, runtime remote сценарій не виконувався. Треба узгодити єдине джерело
target для відкритого handle; зміни manager config під час RUNNING заборонити контрактом.
Source: https://infosys.beckhoff.com/content/1033/tcplclib_tc2_system/30977547.html

## Менші зауваження та validation

ReleaseResource:230 помилково маркує close failure як AcquireResource/AcquireResource.Done;
не додає nErrId. Best-effort logging без зміни FinalStopReason — погоджений контракт.
Enqueue(0) мовчки нічого не робить, на відміну від базового EnqueueTask.
FileContentManagerTest завершується за PendingTaskCount=0, не зупиняючи manager:
StopWhenNoPendingTasks має default FALSE, тому close path не перевіряється.
STOPPED/FAILURE з pending task також не завершує тест явним failed assertion;
Task вже перехоплює exceptions, зовнішній TRY тесту цього не виправляє.

Порядок обговорення: FSQ-1/2 (асинхронне завершення), FSQ-3 (повторне використання),
FSQ-4 (повний запис), FSQ-5 (remote target), logging і відповідні runtime tests.

## FSQ-1: перший погоджений крок виконано — 2026-10-05

Додано OnCancelling у WriteBytesToFile, ReadBytesFromFile, WriteString255ToFile,
ReadString255FromFile, SetPositionInFile, GetPositionInFile і CheckEndOfFile.
Кожний hook викликає свій файловий FB з bExecute=FALSE лише якщо bBusy=TRUE,
після виклику повертає readyToStop := NOT fb.bBusy. Новий запит не запускається.
Без pending operation зупинка дозволена одразу. Поки bBusy зберігається, child
залишається RUNNING, а existing TaskQueue.OnCancelling затримує parent release.
Це очікування відповіді FB (включно з timeout/error), а не відкат файлової операції
або гарантія відсутності side effects на target після ADS timeout. Причину
EXTERNAL_CANCEL не змінюємо; додаткової обробки результату I/O цей крок не додає.

Звірено з прикладом Beckhoff: після запуску FB_FileRead/FB_FileWrite викликаються
з bExecute=FALSE до скидання bBusy:
https://infosys.beckhoff.com/content/1033/tcplclib_tc2_system/710612235.html

Виконано: XML parsing семи файлів, збереження старих IDs, відсутність duplicate
IDs у кожному файлі, точна перевірка незмінності тексту поза доданим методом,
git diff --check для змінених file-content tasks. Статично простежено шляхи:
не почато → ready; busy зберігається → wait; busy скинувся → ready → parent release.
ST compilation та runtime/TcUnit НЕ виконані.

Ручна перевірка: для кожного з семи FB скасувати queue після фактичного bBusy=TRUE;
до bBusy=FALSE child має залишатися RUNNING, parent не повинен починати close,
наступна child не стартує. Перевірити також cancel між child.Start і першим
child.Execute (жодного I/O), завершення з error/timeout та Reset/re-enqueue після
повного зупинення. Без спостереженого busy сценарій очікування не вважати перевіреним.
FSQ-2–5 і test cleanup лишаються наступними окремими кроками.

## FSQ-2: погоджений крок виконано — 2026-10-05

Додано FileContentManager.OnCancelling: спочатку SUPER^.OnCancelling чекає
поточну child, потім FileHandleResourceManager.FinishPendingAcquire чекає open.
FinishPendingAcquire викликає _FileOpen(FALSE) тільки при bBusy=TRUE. Якщо
цей виклик завершив open успішно і hFile>0, встановлює _FileHandleAcquired=TRUE.
Повертає NOT bBusy. Не запускає open і не кидає exception для bError відповіді:
на error/timeout без отриманого handle дозволяє завершення cancellation.
Причина завершення лишається EXTERNAL_CANCEL.

Статично простежено:
- Cancel до першого AcquireResource: bBusy=FALSE, нового open немає, release
  без acquired handle завершується без close.
- Pending open: readyToStop=FALSE, Task лишає cancellation flag і не виконує
  AcquireResource/ReleaseResource, тому нової rising edge не створює.
- Pending open повернув handle: flag acquired встановлено; Task виходить з
  cancellation wait та з RESOURCE_ACQUIRING переходить у RESOURCE_RELEASING,
  існуючий ReleaseResource закриває handle і тримає flag до завершення close.
- Pending open повернув bError: handle не приймається, cancellation завершується.
- Cancel після придбання: FinishPendingAcquire не змінює acquired flag;
  збережено звичайне очікування child і close.

ResourceAcquired не означає pending/busy: його getter і public IResourceManager
не змінювалися. ReleaseResource і best-effort logging policy теж не змінені.
Виправлено шлях cancellation через FileContentManager; standalone callers
FileHandleResourceManager повинні самі викликати FinishPendingAcquire перед
release, якщо зупиняються під час pending acquire.
ADS timeout не гарантує фізичного скасування операції на сервері; handle, який
не було отримано у відповіді, цей код не може закрити.

Перевірено XML, old IDs, відсутність duplicate IDs у кожному файлі, точну
незмінність тексту поза двома новими methods і git diff --check цих файлів.
ST compilation/runtime НЕ виконані. Ручні сценарії: Cancel до першого open,
під час фактичного open.bBusy, open success/error/timeout після Cancel,
close.bBusy після пізнього success; перевірити відсутність запуску children і
повторне використання після Reset. FSQ-3–5 лишаються окремими кроками.

## FSQ-3: погоджений крок виконано — 2026-10-05

FileContentTask.SetFileHandleResource тепер перевіряє State.Ready замість
заборони повторного призначення valid reference. У READY можна призначити,
замінити або очистити borrowed reference. У RUNNING і STOPPED метод кидає
StandardException до зміни reference; STOPPED спершу потребує Reset.
Одна перевірка стану замінює старий guard, без нових flags або змін Task.Reset.
IFileContentTask має той самий задокументований контракт.

Статичний сценарій FSQ-3: Enqueue(B) → вилучення waiting B через ClearWaitingTasks
або parent Reset → B лишається READY → повторний Enqueue(B) замінює прив'язку
й додає задачу без FileHandleResource already assigned. Працює для того самого
або іншого manager. Завершена B вимагає власного Reset перед повторним Enqueue.

READY не доводить, що B вже вилучена з іншої черги. Контракт явно покладає на
caller попереднє вилучення; duplicate enqueue та одночасне володіння різними
чергами не дозволені. Нових queue-membership перевірок не додано.
Єдиний знайдений source caller — FileContentManager.Enqueue.

Перевірено XML, збереження IDs, точну незмінність поза SetFileHandleResource
у двох файлах, git diff --check. ST compilation/runtime НЕ виконано.
Ручні сценарії: повторний enqueue READY після ClearWaitingTasks та queue.Reset;
перенесення вилученої READY задачі до іншого manager; RUNNING відхиляє valid/invalid
reference без зміни binding; STOPPED відхиляє до Reset, після Reset приймає.
FSQ-4 та FSQ-5 залишаються наступними окремими кроками.

## FSQ-5: єдиний target для file handle — 2026-10-05

Додано read-only FileHandleResource.AmsNetId, який читає _FileOpen.sNetId.
У семи конкретних file-content tasks у наявному початковому блоці OnRunning
поруч із hFile додано fb.sNetId := _FileHandleResource.AmsNetId. Перевірка
valid resource виконується до обох присвоєнь. Жодного нового callback немає.
Так remote open/close і дочірній запит використовують адресу одного ресурсу;
порожня адреса локального target також копіюється, перезаписуючи стару remote.
Передавання відбувається на старті I/O, а не Enqueue, тому конфігурація адреси
після Enqueue, але до parent.Start враховується. На reuse з іншою прив'язкою
адреса копіюється заново після child.Reset і повторного Enqueue.

AmsNetId child залишається у public API, але його окремо задане значення
перезаписується target ресурсу перед I/O; це задокументовано в FileContentTask.
FileContentManager.AmsNetId має коментар: налаштовувати до Start, не змінювати
до STOPPED. Resource getter є live view, а не snapshot адреси open.
Logger-код не змінювався: його manager.AmsNetId тепер доходить до WriteBytes FB.

Перевірено XML всього file-content scope, унікальність IDs; для кожної з семи
operations текстова різниця на цьому кроці — лише одне присвоєння перед hFile;
існуючі IDs збережено. git diff --check scope пройдено. ST compilation і
local/remote runtime-тести НЕ запускалися.
Ручні перевірки: local; remote manager без child.AmsNetId; навмисно інша адреса
child (має бути замінена ресурсом); Enqueue до налаштування manager.AmsNetId;
reuse remote→local після повної зупинки/Reset/rebind. Перевірити фактичні
sNetId open/child/close, не лише успішний стан задачі.

FSQ-4 (перевірка кількості записаних байтів) станом на цей крок лише запропоновано,
у код не внесено. FSQ-5 не усуває ризик partial write.

## FSQ-4: перевірка повноти запису внесена — 2026-10-05

WriteBytesToFile.OnRunning після NOT bBusy порівнює cbWrite з cbWriteLen.
Нерівність дає processingState=ERROR та повідомлення з очікуваною й фактичною
кількістю байтів; рівність дає DONE. Наявний bError/exception path не змінено.
Task перетворює ERROR на FAILURE, TaskQueue передає final failure/message
і не видаляє child як успішну. Автоматичного дописування/повтору/відкату немає;
вже записані байти залишаються. OnCancelling цього кроку не змінювався:
скасування зберігає EXTERNAL_CANCEL, очікуючи завершення запиту.

Це реалізує раніше запропоноване виправлення; попередні позначки «FSQ-4 лише
запропоновано» тепер історичні. Статично звірено: busy — кількість не оцінюється;
1000/1000 — DONE, 1000/600 і 1000/0 — ERROR; 0/0 — DONE за відсутності bError.
Це аналіз гілок, не виконані тести. XML, незмінність IDs, точна незмінність поза
completion block і git diff --check пройдено. ST compilation/runtime не виконано.
Ручна перевірка потребує фактичного або керовано змодельованого short write
без bError: перевірити child/parent FAILURE, обидва числа в повідомленні,
відсутність запуску наступної child та проходження close. Окремо повний запис,
нульовий запит і звичайний ADS error. Усі FSQ-1–5 мають реалізовані правки,
але їхня runtime validation ще не завершена; це не повний аудит FileSystem.
