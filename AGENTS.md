# OpenFramework: Working Rules & Guidelines

These rules apply across the entire project, including tests and samples. The owner's latest explicit instruction
takes precedence.

Target platform: TwinCAT 3.1 Build 4026. Platform behavior stated here is owner-confirmed and may not yet appear in
Beckhoff documentation; do not override it based on documentation or assumptions.

## Terms

- **Owner**: the project author who issues instructions, approves plans and contracts, and runs all verifications.
- **Agreed plan / agreed contract**: a work plan or behavior guarantee approved by the owner in chat or recorded as a
  decision in `docs/audit/`. A contract alone does not authorize implementation.
- **Try method**: any method whose name starts with `Try`, regardless of casing or visibility.
- **Terminal OOM**: a failed dynamic allocation after which normal execution cycles must not continue.
- **Fatal allocation latch**: the application-wide flag set by `DynamicMemoryManager.RaiseAllocationFailure` on
  terminal OOM before raising (`RaiseIfAllocationFailed` throws while it is set; cleared only by application
  reinitialization, never manually).

## Language & Communication

- Communicate with the owner in Ukrainian unless explicitly asked otherwise.
- Write all code, comments, identifiers, commit messages, and DocGen strictly in English.
- Maintain local working notes and audit journals in `docs/` in Ukrainian.

## Documentation and Contracts

- Follow [Choosing APIs](Guides/ChoosingAPIs.md) for application code and usage examples, updating it when supported
  tasks or recommended APIs change. Keep signatures and detailed contracts beside declarations, not in the guide.
- Add or update DocGen only beside new or modified public library APIs, protected members available to descendants, and
  enclosing types whose contract changes.
- Use standard ST comments (not DocGen) for private/internal declarations, implementation variables and explanations,
  license notices (MIT per `LICENSE.txt`; preserve authorship), and the `Tests`, `Samples`, and `HowTo` projects.
  Document relevant contracts or behavior where a reader needs them.
- DocGen format: `(*! ... *)` or `//!` with XML tags `<summary>`, `<description>`, `<param>`. Do not mix in
  Markdown/rST or add empty sections.
- `<summary>` states purpose and suffices for straightforward declarations. Add `<description>` when detail is needed:
  cover applicable preconditions, results, invariants, state transitions, ownership/lifetime, failure conditions and
  reporting mechanisms, post-failure state, Try/lifecycle guarantees, and inheritance, callback, or cross-task
  constraints. Do not paraphrase syntax.
- Use richer DocGen markup where it helps callers:
  - `<ol>` for ordered steps; `<table>` to compare cases or outcomes.
  - `<c>` for inline ST; `<example><code>...</code></example>` for short usage examples.
  - `$Name` for related APIs (qualified outside the current element); `<seealso uri="...">` inside `<description>` for
    published guides or full examples.
  - `<note type="information">` inside `<description>` for subtle ownership, lifetime, or timing rules.
- Distinguish documented guarantees from observed behavior and assumptions; never invent contracts from current code.
- Document meaning and usage for non-obvious constants; for bitmasks, state the target representation, isolated or
  cleared bits, and how the result is used.
- Keep standard `FB_init` system parameter comments inline in `VAR_INPUT` with exact wording:
  `bInitRetains: BOOL; // TRUE: the retain variables are initialized (reset warm / reset cold)`
  `bInCopyCode: BOOL; // TRUE: the instance will be copied to the copy code afterward (online change)`
- Order top-level object headers (`FUNCTION_BLOCK`, `PROGRAM`, `FUNCTION`, `INTERFACE`, `TYPE`, `GVL`) as: license
  block, blank line, declaration comment, blank line, optional attributes (no trailing blank line), declaration.
- Align wrapped continuation lines in DocGen and comments with the surrounding block.

## Architecture & Design

- Handle missing dependencies by agreed role: a missing mandatory operand is a configuration error; a missing optional
  action is a no-op; a missing optional local handler delegates failure to the outer handler (neither success nor
  indefinite waiting). An empty composition is not equivalent to a null element inside it.
- Keep `Configure` and setters consistent on allowed dependencies and parent relationships. Validate required arguments
  before mutating state (rollback of callback exceptions is not implied).
- Give each component one responsibility, encapsulate state, and pass dependencies explicitly without forcing callers
  to traverse nested objects.
- Expose externally needed values (including for ADS clients) through the public API. Use properties when an FB
  implements any interface (even if used only with `__QUERYINTERFACE`), and `VAR_OUTPUT` only for direct outputs on FBs
  without interfaces.
- Use a property only for a parameterless, cheap, side-effect-free value (attribute, state, metadata), and a method if
  an operation takes parameters, computes or allocates non-trivially, mutates state, or may fail. Mark state getters
  (including on `INTERFACE` properties) with `{attribute 'monitoring' := 'call'}` and FB backing fields with
  `{attribute 'hide'}`.
- Use the simplest testable design satisfying the agreed contract. Add abstractions, helpers, flags, or fallbacks only
  for a concrete need, explaining their cost and compatibility impact.
- Treat objects as single-task unless cross-task guarantees are documented beside the API; call-local storage alone
  does not establish concurrency safety. For shared cross-task state, document synchronized vs externally synchronized
  operations.

## Structured Text Style

- Build state machines on typed enumerations (`TYPE ... ENUM`) whose state names describe the step or phase, never on
  numeric variables with constant sets.
- One statement per line. Format `IF/ELSIF/ELSE/END_IF`, loops, `CASE`, and `TRY/CATCH` multiline, even for a single
  `RETURN` or call.
- Use blank lines to separate control flow blocks from adjacent statements in the same body/branch, and independent
  groups of declarations or algorithm steps (not every variable or statement).
- In multiline `IF` and `ELSIF` conditions, break before the logical operator, indent continuations by one tab, and put
  `THEN` on its own line aligned with `IF`/`ELSIF`.
- Compare boundaries and special values against constants of the corresponding framework type (adding documented
  constants where missing); literal `0` is allowed in ordinary size, count, and index comparisons when exact type is
  immaterial.
- Indent new and modified ST code with tabs, and follow project-wide conventions for uncovered cases.
- In property getters and `FUNCTION` bodies, an unassigned early `RETURN` yields the return type's default value; do
  not add redundant `defaultValue` locals or assignments (assign `FunctionName := ...` for non-default results).
- Format simple `TYPE` aliases and subranges on a single line (`TYPE NAME : TargetType; END_TYPE`), using named
  constants rather than magic literals for capacities and bounds. Format `STRUCT`, `UNION`, and `ENUM` declarations
  multiline (`TYPE NAME :`, keyword or `(`, tab-indented members, closing keyword/`);`, `END_TYPE`), and wrap
  multi-target `INTERFACE ... EXTENDS` lists one base interface per tab-indented line.
- Keep ST statements, comments, and DocGen within 120 characters per line (up to 140 only when wrapping hurts
  readability). Multiline calls may split earlier: put each argument on its own indented line, align `)` with the call,
  and end standalone calls with `);`.
- Use declared named arguments in method, function, and FB calls, including Beckhoff and third-party libraries (`:=`
  for inputs, `=>` for outputs, e.g. `MEMCPY(destAddr := ..., srcAddr := ..., n := ...)`). Exceptions:
  - Built-in operators and single-argument conversions without named parameters (`ADR`, `SIZEOF`, `XSIZEOF`, `TO_*`,
    `__QUERYINTERFACE`, `__QUERYPOINTER`, `__ISVALIDREF`, `__NEW`, `__DELETE`, `SEL`, `LIMIT`, `MIN`, `MAX`, `MUX`,
    `SHL`, `SHR`, `ROL`, `ROR`, `LOWER_BOUND`, `UPPER_BOUND`).
  - Variadic-style string concatenation helpers when passing sequential fragments (`Concat255`, `ConcatFit255`,
    `Append255`, `AppendFit255`).

### Naming Conventions

- Names must express role and behavior: distinguish configuration, current state, and observation, and name specific
  actions or failure causes when generic words obscure meaning (e.g. `ThrowOnGetMessage`, not `FailMessage`). Use
  `directory` for a file system directory.
- Do not rename clear identifiers for stylistic uniformity, third-party APIs, or existing public APIs solely for style
  without owner approval (remaining deviations are tracked in `docs/audit/`).
- `UPPER_SNAKE_CASE`: type aliases, structs, unions, enum types/values, and data-record/descriptor FBs that neither
  directly nor indirectly inherit from `Object` (e.g. `ERROR`, `READ_ONLY_ERROR`, `GENERIC_VALUE`).
- `PascalCase`: all other FBs/classes without type prefixes (`List`, `AutomationRunner`); interfaces with a leading `I`
  named for a client-facing role noun or `-able` capability without implementation details (`IAutomationComponent`);
  public, protected, and internal methods and properties.
- `_PascalCase` for private FB/class fields (`_AllocationFailed`); `camelCase` for private methods and properties
  (`cleanupTaskMemory`, `currentState`), local variables, and parameters.
- No Hungarian or type prefixes (`p`, `b`, `s`, `str`, `n`, `i`, `a`, etc.) on variables, parameters, or pointers; use
  semantic names (`data`, `targetWords`, `currentLength`, `newMemory`). Single-letter names (`i`, `j`, `k`) are allowed
  only for simple integer loop counters. Preserve TwinCAT lifecycle parameter names (`bInitRetains`, `bInCopyCode` in
  `FB_init` and `FB_exit`).
- Name executable members (methods, actions, functions, including private/test helpers `test*`, `check*`, `assert*`)
  with a verb or verb phrase, never a bare noun (`GetConfigurationValueType`, not `ConfigurationValueType`). Describe
  the contracted action and side effects rather than internal mechanisms unless contracted. Use one verb family per
  meaning:
  - `Get`: returns an existing value or deterministic mapping; invalid input may raise.
  - `Find`: searches; absence is an expected outcome reported via the return value.
  - `Try<Verb>`: obeys the Try contract (never raises).
  - `Create` allocates/constructs; `Parse`/`Format` convert between text and values; `Read`/`Write` consume or produce
    stream/document/cursor data; `Validate`/`Check` verify; `Request<Action>` asks for a refusable lifecycle transition.
  - Side-effect-free `BOOL` predicates start with `Is`, `Has`, `Can`, `Are`, `Should`, or use third-person verbs
    (`Contains`, `Equals`).
  - Framework hooks and event handlers use `On<Event>`, including `OnBefore<Phase>` and `OnAfter<Phase>` (never bare
    `Before*`/`After*`); members that initiate an action never start with `On`.
  - Conversions: `To<Target>` when the owner or single argument defines the source (`ToString`, `ToError`);
    `As<Target>` to read the stored value as another type (`AsBool`); `Convert<Source>To<Target>` when the source must
    be named (never bare `<Source>To<Target>`).
  - `From<Source>` is restricted to factory/value-helper programs whose type name supplies the noun
    (`GenericValueFactory.FromIntValue`), and fluent `That*` / `ToBe` chains to the Testing assertion API.
  - Follow helper prefixes (`Internal`, `safeCall`) directly with a verb (`InternalAppend`).
- Name properties, `VAR_OUTPUT` values, and state variables with a noun, adjective, or state predicate (`State`,
  `Busy`, `HasError`), not an action; boolean options and policy instances are allowed (`UsePersistentMemory`,
  `AllowAll`).
- Use affirmative names for boolean variables, parameters, properties, and predicates (`IsReady`, `IsEnabled`, not
  `IsNotReady`, `NoError`) to avoid double negatives with `NOT`.
- Name events (types, identifiers, enum values) as past-tense facts (`StateChanged`), event raisers with verbs
  (`BroadcastEvent`), and state-machine transition conditions by the holding condition (`DoorClosed`,
  `IsTimeoutElapsed`) rather than the action performed.
- `INamed.Name` display names use `WSTRING` (80 chars) across the API, including constructor name inputs, backing
  storage, and per-test reporter name parameters (longer inputs truncate per IEC rules). Composed paths and diagnostic
  messages keep their separately documented capacities.

## Exceptions and Lifecycle

### Exception Usage

- Use return values or state for expected outcomes (allowable absence, pending work, Try failure); use exceptions to
  interrupt and propagate failures outside those outcomes, regardless of frequency. Check invalid arguments, mandatory
  preconditions, and terminal OOM — do not relax validations or bulk-replace agreed exceptions with error codes.
  See [Rational Exception Handling](Concepts/Exceptions/ExceptionsConcept.md#when-to-use-exceptions).
- Justify new `Throw` or `TRY/CATCH` usage (propagation, handling, or no-throw guarantee). Never throw solely to catch
  an expected outcome and convert it to a status code.
- Every `CATCH` must recover, clean up, convert into a result/diagnostic, or rethrow with context. If execution
  continues after catching, define the post-exception component state — catching alone does not restore invariants.
- `__TRY ... __FINALLY ... __ENDTRY` without `__CATCH` fails to compile, and `__FINALLY` does not run if a secondary
  exception occurs inside `__CATCH`.

### Try Methods and Terminal OOM

- No exception may escape a Try method, including from nested calls or callbacks. Assess resource cleanup, ownership,
  and post-failure state against this contract.
- On terminal OOM, a Try method returns failure with the fatal allocation latch left set.
- Call `DynamicMemoryManager.RaiseIfAllocationFailed` at every task boundary outside Try methods and recoverable
  handlers (`AutomationRunner` does this for tasks it runs; other tasks must call it explicitly).

### Lifecycle Methods

- `FB_init`, `FB_exit`, `FB_reinit`, and their helpers must complete without creating or raising exceptions and must
  not use throwing paths for routine failures.
- TwinCAT calls base `FB_init` implicitly and forwards matching parameter names even when a derived FB extends the
  parameter list; omitting explicit `SUPER^.FB_init` or duplicate base-parameter copying is expected.
- In base `FB_init`, do not call overridable methods or properties that read uninitialized derived instance fields.
  Initialized `VAR_STAT` fields (`_ClassName := __POUNAME()`) are already ready, so a side-effect-free `ClassName`
  getter returning `_ClassName` is safe in `FB_init` without lazy flags.
- In `FB_init`, parameter defaults compile on declarations but cannot be omitted at call sites. Do not declare
  defaults; pass all extra arguments explicitly at every initialization site, including null references for optional
  dependencies.
- The runtime does not invoke `FB_init` or `FB_exit` automatically on `PROGRAM` start or unload; manage program
  resources via a nested FB instance or explicit calls.
- Online Change relocation runs `FB_exit(bInCopyCode := TRUE)` (old instance) -> `FB_init(..., bInCopyCode := TRUE)`
  (new instance, before copy) -> bitwise field copy -> `FB_reinit()`. Design FBs assuming relocation unless
  documented as non-relocatable:
  - In `FB_exit`, guard heap buffers, dynamic children, and retained state behind `IF NOT bInCopyCode`; if a native
    resource cannot survive bitwise copy (`FB_TcMessage`), release it and reset its tracking flag (`_Created := FALSE`)
    so execution lazily recreates it.
  - In `FB_init`, guard initial configuration, side effects, and internal self-address/sub-object bindings behind
    `IF NOT bInCopyCode` (writes to ordinary fields are overwritten by copy anyway).
  - Use `{attribute 'no_copy'}` on borrowed dependencies assigned solely from `FB_init` inputs (validators,
    comparers, `parent`, fixed strategy references) that must reflect relocated targets; assign them unconditionally
    in `FB_init`, and never apply `{attribute 'no_copy'}` to heap pointers or runtime-mutated fields.
  - When an FB stores internal addresses (`ADR(_Static*)`, `REF=` to own/fallback fields, interfaces to embedded
    sub-objects, or raw pointers to own nodes), implement `FB_reinit()` to rebind them after copy, and call
    `SUPER^.FB_reinit()` in derived `FB_reinit()` overrides.

### Memory and Ownership

- TwinCAT skips `FB_exit` for intermediate stack FBs when an exception escapes their method (CODESYS CDS-94841). Use a
  cleanup-dependent local FB only if the method catches all escaping exceptions; otherwise keep it in a persistent
  FB/PROGRAM field or managed heap storage, restricting locals to passive types (`ERROR_MESSAGE`) or FBs with trivial
  `FB_exit`.
- `__DELETE(ptr)` calls `FB_exit` only via a concrete `POINTER TO FB_Type`; deleting via `PVOID` or an interface frees
  memory without `FB_exit`, risking resource/handle leaks.
- Store `__NEW(DerivedFB)` in `POINTER TO DerivedFB` (assigning to `POINTER TO BaseFB` fails with C0032), and check for
  null/OOM before dereferencing into an interface (`itf := derivedPtr^`) or base reference.
- If `FB_exit` violates its contract during `TryRelease`, the helper clears the passed pointer/interface and returns
  `FALSE` without guaranteeing deallocation or clearing aliases; never use or re-delete that partially destroyed object
  via other references.
- Value assignment of FBs performs a bitwise copy without `FB_init` or `FB_exit`, aliasing pointers, references, and
  interfaces. Avoid copying unless documented as supported, and document any non-copyable contract at the declaration
  (it applies even without attributes).
- Apply `{attribute 'no_assign'}` when copying breaks ownership, address bindings, or internal relationships (a
  borrowed dependency alone is insufficient), assessing impact on descendants and callers while preserving valid APIs;
  if a hard error blocks required usage, Build 4026 provides `{attribute 'no_assign_warning'}` (review resulting
  warnings). Obtain owner approval before adding, removing, or switching `no_assign` / `no_assign_warning` on existing
  types; never change them in bulk.

### Exception Objects

- In `Clone`, register dynamic exceptions via `DynamicMemoryManager.RegisterAutoDisposedObject` right after `__NEW` and
  the null guard, before copying payload (plain `__NEW` does not transfer ownership).
- Register outside lifecycle methods (no `FB_init` or deferred OOM registrars). `DynamicMemoryManager` owns registered
  dynamic exceptions until task cleanup; static instances remain caller-owned.
- When adding an exception type or payload, verify that `Clone` preserves the concrete type and all payload rather than
  assuming an inherited `Clone` suffices.
- Never retain exception references past task cleanup or pass them across tasks; copy error state into the Core `ERROR`
  FB (`Data/Errors/ERROR`) for independent long-term diagnostics.

## TwinCAT

### Declarations and Metadata

- Mark every new FB and `PROGRAM` (never `FUNCTION`) with
  `{attribute 'no_explicit_call' := 'do not call this function block directly'}`.
- Provide `ClassName` and `NamespaceName` properties on every new `PROGRAM`.
- Declare `_ClassName : STRING := __POUNAME();` in `VAR_STAT` for FBs (never instance `VAR`), and in `VAR` for
  `PROGRAM` (where `VAR_STAT` is invalid); `FUNCTION` declarations do not use `_ClassName`. Check reused templates
  against all metadata and inheritance rules.
- Extend `IObject` (or `__SYSTEM.IQueryInterface` when `IObject` is intentionally outside the contract) on every new
  root `INTERFACE` so `__QUERYINTERFACE` works, mark internal-only interfaces with `{attribute 'hide'}`, and keep
  interface property `<Get>`/`<Set>` nodes bodyless (empty `<Declaration>` only).
- Mark new `ENUM` types with `{attribute 'qualified_only'}`, `{attribute 'strict'}`, and `{attribute 'to_string'}` by
  default; omit `strict` and `to_string` only for bitflags or duplicate-value (aliased) enums.
- Add no attributes by default to `STRUCT`, `UNION`, or `TYPE` aliases; add `{attribute 'enable_dynamic_creation'}`
  or `{attribute 'pack_mode' := ...}` only when required by heap allocation or binary layout.
- Mark new GVLs with `{attribute 'qualified_only'}`.

### Compiler and Typing Rules

- Match signatures of implemented interface and overridden base members exactly, including parameter names, types, and
  sections (see Lifecycle Methods for derived `FB_init`).
- Do not redeclare fields already defined in a base FB (notably `_ClassName`).
- IEC identifiers are case-insensitive, and parameters/locals shadow instance members; qualify intended members with
  `THIS^.` (`THIS^.Name`), as implicit conversions can let shadowed expressions compile.
- `__QUERYINTERFACE` converts only between interfaces; obtain an FB pointer via `THIS` (`THIS^` is the instance) or
  `__QUERYPOINTER` from an interface.
- Assign an interface returned by a call to a typed local variable before comparing it with another interface or `0`.
- `REFERENCE TO` rules:
  - Check validity via `__ISVALIDREF`; never compare references to `0`.
  - Bind via `REF=`. In a reference property getter, `:=` dereferences the uninitialized return reference and crashes
    the PLC (Access Violation / Page Fault).
  - A `REFERENCE TO` property cannot be made truly read-only: `fb.Prop := val` dereferences and mutates the target even
    without a setter.
  - `REFERENCE TO` method parameters reject non-string literals and direct call results (`Method(ref := GetVal())` does
    not compile); pass an intermediate local variable.
- For `VAR_INPUT` parameters of type `ANY` or `ANY_<type>` (including `actual` and `expected` in assertions), pass
  variables — never literals (even type-prefixed), constants, properties, or direct call results.
- Default parameter values are unsupported for `ANY`/`ANY_<type>` and `VAR_IN_OUT CONSTANT`; pass those arguments
  explicitly.
- For new diagnostic string parameters, use `VAR_INPUT` for `STRING(255)` / `WSTRING(255)` and `VAR_IN_OUT CONSTANT`
  above 255 characters; preserve existing by-reference API signatures.
- An out-of-range literal passed to a subrange parameter (`DINT_INDEX`) fails at compile time; to test a runtime guard,
  assign the invalid value to a local of the underlying integer type and pass that local.
- Generic FBs (`VAR_GENERIC CONSTANT`):
  - Initialize every declaration in `VAR_GENERIC CONSTANT`, even when all instances pass explicit arguments. Build 4026
    can report zero `FB_init` inputs for a specialization relying on inherited custom inputs; for reusable tests varying
    only by fixture mode, use a non-generic test configured via `FB_init`.
  - Derived generic FBs must not redeclare `VAR_GENERIC CONSTANT`; specialize the base (`EXTENDS Base<N>`) and use the
    inherited constant (`_ChildCount`) directly in internal arrays and signatures (`ARRAY [0.._ChildCount - 1]`).
  - Generic arrays `ARRAY [0..N - 1]` are empty when `N = 0`; do not add dummy elements or special storage to avoid
    this bound.

### Source Files and Projects

- Use UTF-8 with BOM and CRLF for TwinCAT source files (`.TcPOU`, `.TcDUT`, `.TcIO`, `.TcGVL`, etc.), preserving XML
  structure, CDATA, and existing IDs. Edit `.plcproj` in place without re-serializing XML.
- Start new object files with `<?xml version="1.0" encoding="utf-8"?>` and `<TcPlcObject Version="1.1.0.1">`,
  generating new unique GUIDs for the object and every nested element with an `Id` (methods, properties, accessors,
  folders). Place each object in its subsystem folder and register
  `<Compile Include="relative\path"><SubType>Code</SubType></Compile>` (plus `<Folder Include="...">` for new folders)
  in `.plcproj`.
- Preserve Referenced Library entries in `.plcproj`: keep square brackets in `Resolution` and `DefaultResolution`
  (project references) and do not alter library identity, `VirtualLibrary`, `PlaceholderReference`, or
  `PlaceholderResolution` without explicit instruction.
- Actual library resolution differs from source files, and valid XML does not imply ST compilation.
- For I/O models, derive data types, field widths, and mailbox/CoE support from the exact device revision and selected
  PDOs — never from ADC resolution or EL/EP prefixes alone.

## Tests and Samples

- Place unit tests in `Sources/TwinCAT.OpenFramework.Tests/Tests/<Area>/` named `<Subject>Test`. Build general
  regression suites on `TwinCAT.OpenFramework.Testing` (`SingleCycleTest` or `MultiCycleTest`) and register every new
  test or group in the fixed `ITestElement` arrays exposed by `Children` on `TestRunner<N>` and `TestGroup<N>`. Test
  the testing framework itself with `TestRunnerContractTest` (advanced directly by `TestAutomationController`) so
  fixture runners are evaluated independently.
- Before adding or reviewing a scenario, identify its documented contract, required initial state, concrete target
  regression, and nearby coverage or boundary gaps.
- Make scenarios runnable on a fresh fixture and repeatable after runner reset by restoring mutable fixture state and
  shared services between runs (steps within one multi-step scenario may depend on earlier steps). Document if
  application reinitialization or a dedicated task is required.
- Derive expected values from the contract and explicit inputs; observe timing, serialization, and external effects
  independently when reusing implementation logic could reproduce the same defect.
- Fail if required observations are skipped, and add positive controls for fault injection when an unexecuted operation
  could otherwise pass. Bound cyclic waits, verify completion before reading final results, check failure paths and
  invariants, and report the scenario and failed condition in diagnostics.
- Finish cleanup before reporting test completion (or use an independent cleanup driver), report cleanup failures
  without masking the original failure, and verify physical native release independently when contracted.
- Cover new behavior and fixed defects with tests in the same change (include them in the plan; plan approval
  authorizes them). If the framework cannot cover a case, note the limitation in the plan and propose a manual check
  for `docs/audit/validation.md`. Record notable coverage decisions and authorized isolated mutation-check results in
  the thematic journal.
- Never call `FB_init` or `FB_exit` explicitly in ST tests (`FB_init` re-runs implicit compiler zero-initialization,
  and explicit `FB_exit` calls are unsupported); exercise `FB_reinit()` and explicit `Rebind`/`OnReinit*` paths in
  unit tests, and record `bInCopyCode = TRUE` copy-relocation checks in `docs/audit/validation.md`.
- Place usage examples in `TwinCAT.OpenFramework.Samples` and `TwinCAT.OpenFramework.HowTo` per the split in
  `docs/audit/tests-and-examples-review.md`.

## What "Perform an Audit..." Means

- Define scope boundaries and inspect every in-scope declaration, internal helper, test, and sample. Trace
  dependencies, inheritance, callbacks, and call sites as deeply as needed — never limit review to public APIs or spot
  checks.
- Check contract existence, completeness, consistency, and code compliance per "Documentation and Contracts" (noting
  missing or ambiguous contracts separately), and evaluate design, APIs, and algorithms per "Architecture & Design"
  with concrete consequences.
- Inspect normal, edge, and error paths for invalid state transitions, broken invariants, resource/memory leaks,
  mishandled failures, object-interaction bugs, and cross-task concurrency/timing issues; assess test/sample quality
  and critical coverage gaps.
- Report scope, uninspected/unverified areas, overall assessment, and findings by criticality (location, issue,
  scenario/proof, impact, backward-compatible recommendation), separating confirmed defects from risks, open questions,
  and optional improvements. End with prioritized next actions, required owner decisions, and recommended
  verifications — never call a partial audit complete or equate static review with test/runtime execution.

## Execution Workflow & Verification

- An audit request authorizes analysis and reporting only; code and contract changes require separate authorization.
- Work in small, completed steps: leave unrelated code/formatting untouched, avoid bulk contract edits or scope creep,
  and coordinate new behavioral changes separately.
- Continue unfinished steps of the active agreed plan across chats without duplicating journal history; never reapply
  completed or reverted changes without a new owner instruction.
- Preserve owner changes and cross-check older file/line or contract references against current code. Do not invent
  requirements/standards or reopen settled decisions without new facts or explicit instructions (with stated
  rationale); when intent, contract, behavior, or style is ambiguous or conflicts, ask a concrete question before
  dependent edits while continuing independent agreed work.
- Without explicit owner authorization, do not run compilation/builds, test suites, the PLC runtime, target/hardware
  activation, XML validation, check scripts, or DocGen generation (reading and searching are permitted; prior
  verification results apply only to the verified revision).
- Git: read-only commands (`status`, `diff`, `log`, `show`) are allowed; without direct owner instruction, never stage,
  commit (including amend), push, or discard/rewrite changes (`reset`, `checkout`, `restore`, `stash`).
- In chat, summarize results, compatibility, pending verifications, and required decisions, showing code only for a
  specific problem or design choice.

## Local Documentation

`docs/` is local and excluded from Git. `AGENTS.md` remains binding even when `docs/` is absent; clarify missing
context when dependent work relies on absent local files.

- Record confirmed general rules in `AGENTS.md`; in the thematic journal, record agreed contracts, full audit reports,
  applied changes, current decisions, and verification status.
- Read `docs/audit/architecture.md` before architectural changes.
- For audit continuation, consult `docs/audit/README.md` (topic/journal index), `docs/audit/current-state.md`,
  `docs/audit/findings.md`, `docs/audit/validation.md`, and thematic summaries: Core — `docs/audit/core-contracts.md`,
  Tasks/FileSystem — `docs/audit/tasks-contracts.md`, exceptions — `docs/audit/exceptions-status.md`.
- DocGen reference: `docs/audit/docgen-migration.md`.
