# Обсяг дослідження

Доповнення: [повторний review OF-001–OF-006](recheck-2026-10-02.md) за поточними правками власника. Детально перечитано п'ять змінених реалізацій у межах первинних сценаріїв, Task cancellation/release paths, повні TaskQueue/StandardTaskQueue, resource interfaces, FileContentManager.Enqueue/ResourceManager та FileContentTask. TaskSequenceTest і FileContentManagerTest прочитані як callers; runtime не запускався. SHA-256 14 переглянутих sources є в recheck snapshot. OF-007 у цей обсяг не входить.

Дата: 2026-10-02; baseline — [README](README.md). Це журнал початкового читання, не звіт про повний аудит.

## Як тлумачити рівні

- **Документація прочитана**: текстові описи опрацьовані; зображення/скриншоти не перевірялися візуально.
- **Метадані прочитані**: весь XML `.plcproj` розібраний, property groups/references/resolutions/Compile зіставлені. Це не семантична перевірка кожного включеного source.
- **Вибірково детально**: прочитані декларації та наведені конкретні method implementations, зіставлені між собою для execution/ownership paths. Інші методи того ж файла можуть залишатися неперевіреними.
- **Огляд**: витягнуто структуру, declarations, method names або test registration; повна behavior correctness не оцінена.
- **Автоматично інвентаризовано**: XML parsing, object declarations і file existence. Не означає, що всі 597 файлів були семантично прочитані.

## Документація та проєктні файли

Прочитані: `README.md`, `TECHNICAL_DESCRIPTION.md`, `TO_DO.txt`, `Tags.txt`; усі чотири concept documents у `Concepts/`, guide `Guides/SignalControlledIntersectionDemo.md`, `Sources/TwinCAT.OpenFramework.JSON/ReadMe.txt`, `Sources/TwinCAT.OpenFramework.EventLogger/ReadMe.txt`, `.gitignore`.

Досліджені `.sln` project/configuration structure, `.tsproj` усі PLC entries, task configurations і simulation entry; прочитані обидва `.TcTTO`. Усі 16 `.plcproj` розібрані повністю як metadata. License header присутній у багатьох declarations; юридичний аудит `LICENSE.txt` не виконувався.

## Детально прочитані вибрані шляхи

Шляхи всіх об'єктів доступні в [source-catalog.csv](source-catalog.csv); назви нижче стосуються поточного основного проєкту, а не legacy copies у Temporary.

| Бібліотека | Вибірково детально: конкретні об'єкти/методи | Лише огляд / залишок |
|---|---|---|
| Core | IObject, IEnumerable, IEnumerator, ILogger, IResourceManager — declarations усіх members. Object.FB_init/FB_exit. Memory.TryReleaseDynamicMemory/TryReleaseDynamicObject. DynamicMemoryManager.CleanupMemory/cooperativeCleanupMemory/RegisterAutoDisposedObject. MemoryCleanupHelper.FB_Exit, AutoDisposeRegistrar.FB_Init. ExceptionManager.Throw/GetLastException/Cleanup. Exception declaration, GeneralException.InternalThrow, StandardException.Throw/Clone. GENERIC_VALUE.Release/Reset/CopyTo/TryChangeValueByAnyType. GenericValueFactory.FromParts/FromObjectValue/FromObjectReference. System.Execute. LogManager.Execute | StringBuilder declaration/method list, інші services/primitives/interfaces та повні descendants exceptions — каталог/огляд; конверсії, strings, events/actions/statistics ще не детально перевірені |
| Comparision | ByteArrayComparer.Compare. IdenticalDataPredicate.Check/SetReferenceValueByAny/SetReferenceValueByAnyType/FB_exit | Інші comparers, SameDataPredicate та їх callers/tests ще не повністю прочитані |
| Collections | List declaration, ClassName getter, FB_init/AllocateMemory/AppendGeneric/SetGeneric/RemoveAt/Clear | InsertGeneric/Sort/Swap, ByteList/Dictionary/UniqueDataSet/Queue і enumerators — інвентаризовані, без повного аналізу |
| Tasks | ITask declarations. Task.Execute/handleRunning/Start/Cancel/Reset/setRunningState/safeCallOnBeforeStop. TaskQueue.OnRunning/OnBeforeStop/OnReset/Clear/InternalEnqueue/removeCurrentTask | Task remaining callbacks, properties/state wrappers, getTaskByIndex — неповна перевірка; StandardTaskQueue declaration і відсутність own callbacks оглянуті |
| Timers | Timer declaration, OnRunning/OnStopped/OnReset | Restart/SetIntervalAndRestart/properties та ITimer — каталог/огляд |
| Automation | IAutomationComponent/IParentAutomationComponent/IChildAutomationComponent declarations. AutomationRunner.Execute/FB_init. AutomationComponent.ProcessException. BranchAutomationComponent.Execute/Initialize/doWork/doStop, порожні base hooks/abstract Validate. AutomationController.OnBeforeExecute/OnAfterExecute/Validate/TryGetChildByIndex. CompositeAutomationComponent.FB_init/ProcessInput/ProcessOutput. LeafAutomationComponent.Initialize/Execute; InputLeaf.ProcessInput, OutputLeaf.ProcessOutput. Runner/OperationalState enum declarations | Enable/Disable/Reset, policies, events, permissions, plugins/HMI details, topology validation та всі інші callbacks ще не повністю перевірені |
| IO.Models | EL3001, ANALOG_INPUT_INT_CHANNEL declarations | Інші terminal/channel DUT — каталог; layout, output models і actual EtherCAT mapping не перевірені |
| Devices.IO | DigitalInput.OnProcessInput; DigitalOutput declaration/BindToIO/OnProcessOutput | AnalogInput/Output/converters/status, contact polarity й повні properties — каталог/огляд |
| Workflow | IWorkflow/IActivity declarations. Workflow declaration/Execute/RegisterChild/DisposeDynamicChildren/SetRootActivity. Activity declaration/Execute/RequestStart/RequestCancel. SequenceActivity declaration/OnRunning/OnStopping/selectNextTask | Root properties, variables lookup, suspend, all other composite/leaf activities/Workflows transition helper — неповний огляд, не аудит |
| FileSystem | FileHandleResourceManager declaration/AcquireResource/ReleaseResource/FB_exit. FileContentManager declaration/ResourceManager getter. ReadBytesFromFile.OnRunning | Інші file/directory tasks, path utilities, buffers, FileContentTask integration — каталог/огляд |
| Loggers | SimpleTextFileLogger declaration/Execute/tryLogNewMessages. EventLogger.TryLogMessage | InternalTryLogMessage, TryLogError/Exception, filters/defaults, logger state/rotation properties — не повний аудит |
| EventLogger | EventLoggerMessage.InternalTrySend, ReadMe | Send contract/descendants, EventEntry/source info lifecycle та весь adapter — огляд |
| JSON | AutomaticJsonSerializer declaration/InternalCreateJsonFromStructure/InternalFillStructureFromJson/TryCreateJsonFromStructure; ReadMe limitation | RPC wrappers, VarInfo variants, format options, IJsonExtender та решта Try wrappers — огляд |
| Tests | MAIN declaration/body, TestAutomationController declaration/OnBeforeChildrenWorking. DynamicListTest declaration/body/AppendGeneric/RemoveAt. TaskSequenceTest declaration/body/TestSequence. ExceptionTest declaration/body | Усі suite registrations/test call counts автоматично інвентаризовані. Решта 21 suites не прочитана построково; assertions каталог не є test execution |
| Samples | MAIN declaration/body. IntersectionController.OnBeforeChildrenInitializing/OnBeforeChildrenWorking/TurnOff, IO binding excerpt і TurnOffButton getter. DemoWorkflowController.OnBeforeChildrenWorking. DemoWorkflow декларація/усі його method implementations | TrafficLight, MoveFromToActivity, creation of complete workflow graph, HMI, visualization XML, terminal mapping — без детальної behavior verification |
| Temporary | Метадані, папки Communication/Database/StateMachine, Communicator declaration із legacy TC.ToolkitObject | Решта legacy-коду не аудована; немає твердження про його компільованість або функціональну коректність |

## Що залишається поза цим висновком

Повний method-by-method аудит, visual QA `.TcVIS`, binary library contents/version equivalence, target activation, hardware IO, PLC runtime/online change і TcUnit execution. Немає числової оцінки семантичного покриття: багато методів у XML збережено всередині одного файла, тому кількість прочитаних файлів сама по собі вводила б в оману.

Після кожної наступної задачі додавати до цього журналу precise methods/paths, commit, виконані перевірки і залишковий обсяг. Файли, знайдені пошуком або автоматично прочитані XML parser, не підвищувати до рівня «детально перевірено» без аналізу реалізації.

## Доповнення T00–T10

Детально звірені змінені Task, TaskQueue, ITask та status wrappers, optional
interfaces, FileHandleResourceManager, нові fake fixtures і 22 test methods.
Звірені Timer callbacks/Restart, FileContentManager/FileContentTask own/borrow,
logger rotation/queue production і всі textual callers змінених status API у Sources.
Інші бібліотеки не проходили повторного повного аудиту. Existing file/logger
suites лишаються ручними integration checks; нового повного аудиту їх assertions
або PLC execution не виконано. Деталі: itask-execution-journal.md.

## Поточні тести Task — 2026-10-05

Для поточної реалізації прочитано й звірено lifecycle Task/TaskQueue/Timer,
FileContentManager та сім file-content operations із наявними тестами
TaskSequenceTest, FileContentManagerTest, DirectoryTest і LoggerTest.
Додано 53 тестові методи в п'яти suites, керовані resource/task fixtures
і реальні файлові integration cases. У двох випадках потрібне спеціально
підготовлене середовище; типово вони вимкнені. Це написане покриття сценаріями,
не виміряне coverage або виконані TcUnit assertions. Інші suites не аудовано
повністю. Деталі та залишкові прогалини: task-tests-2026-10-05.md.
