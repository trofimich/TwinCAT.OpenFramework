# План повного аудиту

Baseline та початковий обсяг — [README](README.md), [coverage](coverage.md). Задачі нижче ще не виконані, крім завершеного початкового дослідження A00. Залежності визначають порядок; сильні preliminary findings допускають коротку перевірку раніше завершення всієї бібліотеки.

## Правила для кожної задачі

За замовчуванням аудит не редагує PLC-код. Результат: перелік прочитаних файлів/методів, контракти й інваріанти, знахідки з file/line і конкретним сценарієм, рівнем упевненості та виконаними перевірками. Нові підозри перевіряти за callers, descendants і tests, а не лише за локальним фрагментом. Не змішувати стиль/побажання з behavioral bugs.

Завершення бібліотеки означає огляд усіх включених executable implementations, контрактів і ресурсних шляхів; вибіркова перевірка не позначається повним аудитом. Фіксувати unresolved questions та runtime checks, що залишилися. Виправлення оформлювати окремими задачами після regression scenario; якщо source змінюється, записувати новий baseline і перевіряти залежних споживачів.

## Порядок і конкретні задачі

| ID | Обсяг | Залежності | Ризик / результат | Статус |
|---|---|---|---|---|
| A00 | Документація, 16 проєктів, архітектурні шляхи | — | Карта, inventory, preliminary findings | Завершено в межах початкового дослідження |
| A01 | XAE build/test baseline і library resolution | A00 | Довести, що tests перевіряють поточні sources; отримати build/test diagnostics | Не почато; generic MSBuild attempt failed |
| A02 | Core: Object, Memory, generics, exceptions | A00; A01 для runtime | Найвищий fan-out, pointers/ownership/exceptions; OF-002, OF-007 | Не почато |
| A03 | AutomationRunner + initialization контракт branch/leaf | A00; A02 | OF-001, OF-003, early-return/cleanup, initialization timeout/null | Не почато |
| A04 | Решта Core та Comparision | A02 | Conversion/buffers/time/log facade; ordering/equality/hashing correctness | Не почато |
| A05 | Collections, усі п'ять типів та enumerators | A02, A04 | Boundary/ownership/growth/sort/mutation; OF-007 | Не почато |
| A06 | Tasks, TaskQueue, StandardTaskQueue та Timers | A02, A05 | Acquire/process/release, cancel/failure/reset/restart; OF-004 | Не почато |
| A07 | Решта Automation + IO.Models + Devices.IO | A03, A04, A05; A06 для sample timers | IO order, stop/disable/reset, permissions/events/plugins, numeric mapping | Не почато |
| A08 | Workflow, всі activities і variables | A02, A04, A05 | Dynamic ownership, start/resume/suspend/cancel/rethrow | Не почато |
| A09 | FileSystem | A06 | File/directory operations, buffers/partial IO, cleanup; OF-006 | Не почато |
| A10 | Loggers та EventLogger | A09; A04 | Rotation/backpressure/encoding, service errors, recursive logging | Не почато |
| A11 | JSON | A02, A04 | RTTI/static memory contract, bounds, invalid JSON | Не почато |
| A12 | Tests/Samples, end-to-end paths | A01, A07, A08, A09, A10, A11 | Regression suites і behavior per cycle; OF-005 | Не почато |
| A13 | Cross-library runtime/stress/platform checks | A01, A02, A05–A12 | WCET, memory, online change/restarts, permitted task model | Не почато |
| A14 | Documentation contracts + Temporary migration inventory | A04–A12 | Узгоджена документація; legacy scope окремо від core | Не почато |

A03 навмисно піднято перед повним аудитом інших бібліотек: runner визначає, чи взагалі виконаються перевірки. IO.Models має незалежний dependency root; його layout можна перевірити до A07, але integration mapping потребує Devices.IO. A11 також можна виконати раніше A09/A10 після A04.

## Детальні пакети робіт

### A01 — відтворювана збірка

Відкрити solution через XAE у придатному до збірки середовищі; зберегти compiler/build versions. Зафіксувати фактичні resolved версії всіх placeholders, їх source/library origin і checksum бібліотек. Зібрати та встановити бібліотеки в dependency order, не підміняючи нові sources попередніми binary exports. Перевірити кожен `.plcproj`, включно з Tests/Samples, а не лише верхньорівневий `.tsproj`. Отримати TcUnit результати поточного baseline в ізольованому test runtime. Вихід: точні команди/процедура, logs, successes/failures і список недоступних перевірок.

### A02 — Core memory та exceptions

Розбити на: (1) IObject/SelfAddress/SelfSize і __DELETE/FB_exit, (2) GENERIC_VALUE/factory/copy/clone/adopt, (3) exception cloning/inner exceptions/registrar/cleanup. Побудувати ownership matrix: stack/static/dynamic, borrowed/owned, copy/move/adopt, container lifetime vs cycle lifetime. Перевірити self-assignment, aliasing, null, allocation failure, repeated release, retention за межі циклу. Визначити контракт single-task use та online-change behavior. Вихід: reproduction для OF-002/007 і список lifetime invariants.

### A03 — runner та initialization

Таблиця переходів INITIALIZING/RUNNING/INVALID та INITIALIZING/WORKING/STOPPED/INVALID. Null first/middle/last, pending+failed combinations, timeout, invalid child, missing Parent/Children, disabled component. Перевірити exception code propagation в outer catches, гарантованість cycle epilogue й readiness SystemDataValid. Вихід: regression scenarios OF-001/003 і контракт обов'язкового cleanup.

### A04 — Core services і Comparision

STRING/WSTRING capacities/terminators, split/join/search empty inputs, signed/unsigned extremes, temporal conversions і system readiness, random boundaries, error records, event/action policies. Comparers: antisymmetry/transitivity/equality, strings різної capacity, WSTRING byte ordering, null/empty ANY, pointer/object semantics і float NaN/infinity. Перевірити logger/filter як базові залежності, зокрема відмову logger всередині exception/disposal.

### A05 — Collections

Для List, ByteList, Dictionary, UniqueDataSet, Queue: static capacity 0/1/N boundary, empty/full transitions, dynamic growth, capacity=length, invalid indexes, insert/remove first/last, replacement того ж borrowed/owned descriptor, duplicate keys, validator failures та відкат. Enumerators: empty/end/reset, lifetime Current, mutation під час iteration. Перевірити ростові копії FB descriptor, allocation counters і cleanup після exceptions. Вихід: matrix operations × ownership × static/dynamic і regression gaps у TcUnit.

### A06 — Tasks і Timers

Окремо перевірити original та final stop reasons. Cancel під час acquire/process/release, release failure, Start refusal, Reset refusal, повторне використання task, duplicate enqueue, Clear активної queue, child start failure, empty persistent vs finite queue. Timer: zero/negative/positive interval (де тип дозволяє), trigger duration, restart while running/stopped. Вихід: цикл-за-циклом trace OF-004 з fake resource manager та test для timeout cleanup.

### A07 — Automation та IO

Перевірити trace input → controller logic → child logic → output; порахувати calls для одного leaf і nested composite за цикл. Умови Enable/Disable, Stop/Reset, exception severity, child error policies, safe output behavior після early return. Parent/children topology, invalid references, cycles у дереві, plugin references. Events: bubbling/broadcast порядок, permissions deny/allow. IO: exact DUT mapping, polarity/contact type, analog range endpoints, clipping/reversed ranges/division-by-zero, status flags. Результат: documented IO freshness/edge semantics і стан outputs на кожному lifecycle path.

### A08 — Workflow

Activity і composite base contract до конкретних Sequence/IfElse/While/WaitAndPick/TryCatch. Immediate completion, resume після suspend, cancel під час nested activity, child failures і exception rethrow; root replacement/disposal, dynamic registration duplicates, shared children, variable shadowing та missing variable. Перевірити callback ordering за Samples і дизайн-контрактом. Вихід: transition matrix й ownership graph.

### A09–A11 — адаптери

FileSystem: ADS/file errors, busy edges, partial/zero-byte read/write, path limits, late open completion після cancel, close errors, deletion/online change. Loggers: bounded/unbounded backlog, file rotation while writer busy, failed messages, encoding/BOM, event creation/send failure, recursion при errors. JSON: buffer boundaries, escaped/unicode strings, unsupported/static/dynamic structures, missing/extra fields і partial destination modification on failure. Вихід кожного пакета: чітка різниця між framework defect, external service failure та documented limitation.

### A12–A14 — інтеграція та завершення

Зіставити всі бібліотеки із suites, знайти непокриті контракти, додати regression tests у наступних задачах виправлення. End-to-end: runner initialization failure, task cancellation during file IO, logger failure during exception cleanup, workflow nested failure/suspend/restart. A13 вимірює allocations/peaks і cycle execution за визначеної workload, stack depth, restarts/online change та дозволені architectures. Не тестувати unsupported parallel mode як вимогу без узгодження контракту. Temporary інвентаризувати щодо старих dependencies/TC namespace та міграції; не включати його якість у висновок про новий runtime без явної потреби. A14 приводить docs до перевірених контрактів і завершує загальну оцінку.

## Шаблон наступної задачі

> Виконай A02 з docs/audit/plan.md для поточного baseline. Не змінюй PLC-код. Детально прочитай усі відповідні контракти, реалізації, callers і tests. Перевір OF-002 та OF-007. Онови findings.md і coverage.md з точними файлами/методами, доказами й залишковими runtime checks. Зберігай різницю між статичним висновком і реально виконаним тестом. Якщо потрібний test harness чи fix, опиши конкретну наступну задачу, не позначаючи її виконаною.
