# Робочі матеріали OpenFramework

Упорядковано 2026-10-16. Контракти насамперед живуть біля декларацій;
тут — короткий контекст рішень, відкриті питання та статус перевірок.

- [Архітектура](architecture.md)
- [Core: Object, interfaces, memory, Actions, Events, System](core-contracts.md)
- [Tasks і FileSystem](tasks-contracts.md)
- [Exceptions E1–E9](exceptions-status.md)
- [Primitives: статичний огляд і питання контрактів](primitives-review.md)
- [Відкриті питання й межі](findings.md)
- [Перевірки](validation.md)
- [Ручний запуск Task tests](task-tests-2026-10-05.md)
- [Формат DocGen](docgen-migration.md)
- [Попередній ширший огляд Core](core-classes-overview.md) — кандидати поза завершеним scope, не поточна специфікація.

Прибрано дубльовані хронологічні журнали, відкатаний T00–T10 план і скрипти,
старі JSON/CSV inventories/check results та snapshot pointer.
CompiledLibraries/audit також видалено: docgen-before містив 438 резервних
копій джерел; runs — 707 файлів snapshots/проміжних бібліотек і manifest/logs;
T00 — 634 файли старого baseline та retired fixtures; UsermodeRuntime —
10 файлів пробної конфігурації/Boot/routes/event database. У корені audit було
8 допоміжних migration/review scripts. Це приблизно 46 MiB службових матеріалів,
не релізні бібліотеки. CompiledLibraries/v1.0.* залишені.

Sources, тести, Guides, Concepts і релізи під час прибирання не змінювалися.
Збережені рішення не є новим дозволом реалізувати всі пропозиції.
