# Виконання T00–T10

2026-10-02. Власник змінив умову виконання: реалізувати доступну роботу без
автоматичної збірки/runtime, додати тести до наявного Tests, запуск виконає власник.
Наведені нижче зміни не є підтвердженими TwinCAT compiler або runtime.

| Етап | Внесений результат | Статус перевірки |
|---|---|---|
| T00 | Baseline source snapshot, дослідження XAE, встановлення окремого UM Runtime; сім регресійних сценаріїв перенесено в Tests | Старий baseline мав CheckAllObjects=true і exports Core/Comparision/Collections/Tasks. Окремий fixture build не пройшов library resolution. Runtime тести не виконані |
| T01 | Lifecycle, результати та таблиця переходів у itask-contract.md | Документація звірена з реалізацією |
| T02 | Контракт STOPPED/callbacks; exception logging завершення; тести кратності callbacks | Static review; compiler/runtime очікуються |
| T03 | Перевірки queue ownership: null, self, duplicate, READY, приймання роботи; Clear guard; Start/Reset refusal handling | Static review та написані тести; compiler/runtime очікуються |
| T04 | Own/borrow контракт; snapshot manager на Start; optional IResourceCleanupStatus; pending open просувається до результату перед close | Static review та fake tests; фактичний ADS open/close обов'язково перевірити вручну |
| T05 | requestStop → OnStopRequested → OnStopping/CanStop → OnBeforeStop → release → STOPPED/OnAfterStop для всіх причин | Static review та тести cancel/done/abort/error/exception; compiler/runtime очікуються |
| T06 | Read-only CancellationRequested протягом child wait і release; скидання при STOPPED/Reset | Static review та написані тести |
| T07 | ITaskState/ITaskStopReason live views; wrappers більше не залежать від concrete Task; незалежний test adapter | Static review та adapter tests; потрібна перевірка ST interface assignments |
| T08 | ITaskResourceDiagnostics для ResourceManager/RunningSubstate; ITask більше їх не вимагає | Callers звірено; QueryInterface tests написано |
| T09 | Політика bounded Execute, timeout/recovery без forced STOPPED; fake hang/recovery test | Документація і static review; вимірювання часу не виконано |
| T10 | Звірені Tasks/Timers/FileSystem/Loggers/Tests/Samples; Timer integration test, Tests dependency на Timers; migration/manual checklist | XML/includes/registration перевірено; native build, PLC/file/logger інтеграції залишено власнику |

Етапи виконувалися в цьому порядку. T01–T04 визначили контракт до об'єднання
stop paths. T06–T08 змінюють public API після зміни lifecycle. Окремих commits
не створювали; зміни залишено в робочому дереві для review.
За початковими критеріями план ще не має повної верифікації: реалізація
та документація підготовлені, перевірки виконання залишаються відкритими.

## Важливі рішення

- Перший прийнятий stop фіксує OriginalStopReason. Cleanup exception додає
  окремий failure, не підміняючи первинну причину. Queue читає FinalStopReason
  child, щоб cleanup failure не виглядав успішною роботою.
- Release exception більше не означає автоматичного STOPPED: Execute повторює
  cleanup. Якщо manager не відновиться, задача лишиться RUNNING. Це навмисна
  зміна поведінки; recovery/timeout належить manager або власнику виконання.
- Best-effort close залишається допустимим: FileHandleResourceManager логує
  close error і завершує відповідальність без exception; результат роботи
  через сам цей лог не змінюється.
- Legacy manager без IResourceCleanupStatus використовує ResourceAcquired=false
  як підтвердження завершення release. Для pending операцій manager має реалізувати
  новий optional interface або забезпечити стару достатню гарантію самостійно.
- Нових READY/RUNNING/STOPPED станів чи cancellation підстанів немає.
- Library versions та встановлені production exports не змінені. Публікація
  нового комплекту і підтвердження resolutions відкладені до ручної збірки.

## Інструменти та фактичні результати

- Usermode Runtime встановлено через TcPkg: TC170x.UsermodeRuntime.XAR 4026.27.0,
  TwinCAT.XAR.UserModeRuntime 1.27.1. Installation exit code 0 збережено в
  t00-runtime-install-status.json; plan/result поруч.
- Запущений ізольований instance OpenFrameworkAudit, NetId 199.42.42.250.1.1,
  перебував у Config. Конфігурацію PLC не активували. Instance зупинено командою x.
  Встановлений пакет залишено; штатний target проєкту не змінено.
- Native fixture build мав LastBuildInfo=2 через нерозв'язані Core/Tasks 65000;
  вивід compiler збережено в t00-fixture-native-build.json. Порожній ErrorList
  попередніх спроб не означав відсутність compiler errors.
- Попередні exports/version 1.0.10.65000 — baseline у тимчасовому repository,
  не відповідають новим змінам. Тимчасові registrations видалено.
- Поточна статична перевірка: check-itask-static.ps1 і
  itask-static-validation.json. Вона перевіряє XML, Compile paths, IDs у зміненому
  scope та registration 22 тестів. Це не ST compilation і не виконання assertions.

Далі див. [ручну перевірку та міграцію](itask-manual-validation.md).
