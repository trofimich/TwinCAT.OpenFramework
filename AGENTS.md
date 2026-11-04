# OpenFramework: Working Rules & Guidelines

These rules apply across the entire project, including tests and samples.
The owner's latest explicit instruction takes precedence.

Target platform: TwinCAT 3.1 Build 4026. TwinCAT behavior described below is confirmed by the owner and may not yet
be reflected in Beckhoff documentation; do not override it based on documentation or assumptions.

## Terms

- **Owner**: the project author who issues instructions, approves plans and contracts, and performs verifications.
- **Agreed plan / agreed contract**: an owner-approved plan of work or behavior guarantee. Owner approval may be confirmed
  in chat or recorded as a decision in `docs/audit/`. A contract alone does not authorize implementation.
- **Try method**: any method whose name starts with `Try`, regardless of casing or visibility.
- **Terminal OOM**: a failed dynamic allocation after which the application must not continue normal execution.
- **Fatal allocation latch**: the application-wide flag that `DynamicMemoryManager.RaiseAllocationFailure` sets on
  terminal OOM before raising the failure. `RaiseIfAllocationFailed` raises an exception if the flag is set.
  Only application reinitialization clears the flag.
- **`ERROR`**: the Core function block (`Data/Errors/ERROR`) that stores a copied error state independently
  of transient exception objects.

## Language & Communication

- Communicate with the owner in Ukrainian unless explicitly asked to use another language.
- Code, comments, identifiers, commit messages, and DocGen documentation must strictly be written in English.
- Working notes and audit journals in `docs/` are maintained in Ukrainian as part of local workspace documentation.

## Documentation and Contracts

- Document each new or modified type, method, property, or function next to its declaration. When changing a member,
  update or add its DocGen. Update the type's DocGen as well if the member change affects the type's contract.
  Documentation of unrelated members is outside the scope of that change.
- Format: `(*! ... *)` or `//!` with XML tags `<summary>`, `<description>`, `<param>`. Do not mix DocGen with
  Markdown/rST, and do not add empty sections.
- `<summary>` explains purpose. In `<description>`, cover the applicable preconditions, results, invariants, state transitions,
  ownership/lifetime, failure conditions and reporting mechanisms, post-failure state, Try/lifecycle guarantees,
  and constraints on inheritance, callbacks, and cross-task usage. Do not paraphrase syntax.
- Distinguish documented guarantees from observed behavior and assumptions. Do not invent a contract based on the
  current implementation.
- For non-obvious constants, document meaning and application. For bitmasks, document which bits are isolated or
  cleared, which representation the mask applies to, and how the result is used.
- Implementation explanations and license notices are standard ST comments. License is MIT (`LICENSE.txt`);
  preserve authorship.
- Keep the standard `FB_init` system parameter comments inline in `VAR_INPUT`, using the original wording:
  `bInitRetains: BOOL; // TRUE: the retain variables are initialized (reset warm / reset cold)`
  `bInCopyCode: BOOL; // TRUE: the instance will be copied to the copy code afterward (online change)`
- Order FB and PROGRAM headers as follows: license block, DocGen block, blank line, all attributes, then
  immediately the `FUNCTION_BLOCK` or `PROGRAM` declaration.
- Keep line length of comments and DocGen blocks within 120 characters (maximum 140 when breaking degrades readability).
  Wrap long sentences in `<summary>`, `<description>`, and implementation comments across multiple lines indented
  with the surrounding block.

## Architecture & Design

- Treat the absence of a dependency according to its agreed role: a missing mandatory operand is a configuration error;
  a missing optional action is a no-op; a missing optional local handler delegates the failure to the outer handler
  and is neither success nor indefinite waiting. An empty composition is not equivalent to a null element within it.
- If an API provides both `Configure` and setters, they must be consistent regarding allowable dependencies and parent
  relationships. Validate required arguments before mutation; this does not guarantee rollback of exceptions raised
  from callbacks.
- Give each component one responsibility, encapsulate its state, and pass dependencies explicitly. Callers should
  not need to navigate nested objects to obtain a dependency.
- Use the simplest design that satisfies the agreed contract and supports testing. Introduce abstractions, helpers,
  flags, or fallback paths only for a concrete need. Explain their cost and compatibility impact.
- Names of types, members, and variables must explain their role and behavior. Distinguish configuration, current
  state, and observation; name specific actions or failure causes if a generic word obscures meaning (for example,
  `ThrowOnGetMessage` instead of `FailMessage`). For a file system directory, use `directory`.
  Do not rename clear identifiers merely for stylistic uniformity.
- Cross-task guarantees exist only where they are documented next to the API. Without such a guarantee, treat an object
  as used by a single task; call-local storage alone does not establish concurrency safety. When adding state shared
  between tasks, document which operations are synchronized and which require external synchronization.

## Structured Text Style

- Implement state machines based on typed enumerations (`TYPE ... ENUM`), never numerical variables with constant sets.
  State names must explain the step or phase.
- One statement per line. Format `IF/ELSIF/ELSE/END_IF`, loops, `CASE`, and `TRY/CATCH` multiline, even for a single
  `RETURN` or call.
- Separate a control flow block from adjacent statements in the same body or branch with a blank line.
- In multiline `IF` and `ELSIF` conditions, break before the logical operator and indent the continuation by one tab.
  Put `THEN` on its own line aligned with `IF` or `ELSIF`.
- In comparisons with boundaries and special values, use constants of the corresponding framework types.
  A literal `0` is allowed in ordinary size, count, and index comparisons when its exact type does not matter.
  Add missing constants to the appropriate type along with a description of their purpose.
- Separate independent groups of declarations and algorithm steps with blank lines, not every variable or operation.
- Indent ST with tabs. Apply the same style rules to new and modified code across libraries, tests, and samples.
  For cases these rules do not cover, follow a consistent project-wide convention. If comparable cases differ or
  no convention is established, ask the owner and record the agreed general rule here.
- In property getters, an early `RETURN` without assigning a result returns the default/initial value of the type.
  Do not add local `defaultValue` variables and assignments purely to duplicate this default initialization.
- Keep ST statements within 120 characters per line. Allow 121–140 only when wrapping would reduce readability.
  Always wrap lines longer than 140 characters. Calls with many arguments may be split earlier.
  In a multiline call, indent each argument on its own line and align the closing parenthesis with the call.
  End a standalone call with `);`.
- Use named arguments in method, function, and FB calls, including Beckhoff and third-party libraries.
  Use `:=` for inputs and `=>` when connecting outputs. Match the declared names, for example
  `MEMCPY(destAddr := ..., srcAddr := ..., n := ...)` and `TEST(TestName := ...)`. Exceptions:
  - Built-in operators and single-argument conversions without named parameter support (`ADR`, `SIZEOF`, `XSIZEOF`,
    `TO_*`, `__QUERYINTERFACE`, `__QUERYPOINTER`, `__ISVALIDREF`, `__NEW`, `__DELETE`, `SEL`, `LIMIT`, `MIN`, `MAX`,
    `MUX`, `SHL`, `SHR`, `ROL`, `ROR`, `LOWER_BOUND`, `UPPER_BOUND`).
  - Variadic-style string helper functions designed for concise multi-fragment concatenation (`Concat255`,
    `ConcatFit255`, `Append255`, `AppendFit255` when passing sequential text fragments).

### Naming Conventions

- Use UPPER_SNAKE_CASE for type aliases, structures, unions, enumeration types, and enumeration values.
- Use UPPER_SNAKE_CASE for an FB only when it represents a data record or descriptor and neither directly nor
  indirectly inherits from `Object` (e.g. `ERROR`, `READ_ONLY_ERROR`, `GENERIC_VALUE`). Use PascalCase without
  type prefixes for all other classes/FBs (e.g. `List`, `AutomationRunner`).
- Use PascalCase for interfaces with a leading `I` (e.g. `IAutomationComponent`).
- Use PascalCase for public, protected, and internal methods and properties.
  Use camelCase for private methods and properties (e.g. `cleanupTaskMemory` and `currentState`).
- Private fields of classes/FBs use the `_` prefix with PascalCase (`_AllocationFailed`); local variables and
  parameters use camelCase without the prefix.
- Do not use Hungarian notation or type-denoting prefixes (`p`, `b`, `s`, `str`, `n`, `i`, `a`, etc.) for variables,
  parameters, or pointers. Use clear semantic names describing purpose: `data`, `targetWords`, `currentLength`,
  `newMemory` (not `pData`, `pWords`, `nLen`, `pNewMemory`).
  - Short single-letter variables are permitted exclusively as simple integer loop counters (`i`, `j`, `k`).
  - Preserve TwinCAT-defined lifecycle parameter names, including `bInitRetains` and `bInCopyCode` in `FB_init`
    and `bInCopyCode` in `FB_exit`.
- Do not rename third-party APIs.
- Display names governed by `INamed.Name` use `WSTRING` (80 characters) throughout the API, including constructor
  name inputs, backing storage, and individual test-name reporter parameters. Longer input follows ordinary IEC
  truncation. Composed paths and diagnostic messages keep their separately documented capacities.

## Exceptions and Lifecycle

### Exception Usage

- Use the API's return value or state for expected outcomes such as allowable absence, pending work, or Try failure.
  Use an exception to interrupt an operation and propagate a failure outside those outcomes, regardless of frequency.
- Deleting a missing value can be a no-op even in an empty collection; document behavior next to the API.
- Invalid arguments, mandatory preconditions, and terminal OOM must be checked. Do not relax validations or replace
  agreed exceptions with error codes en masse.
  User explanation: [Rational Exception Handling](Concepts/Exceptions/ExceptionsConcept.md#when-to-use-exceptions).
- When adding `Throw` or `TRY/CATCH`, explain why propagation, handling, or a no-throw guarantee is required.
  Do not throw solely to catch an expected outcome and convert it to a status code.
- Catching must perform a defined action: recovery, cleanup, conversion into a result/diagnostic, or rethrowing with
  context. If continuation after an exception is permitted, define the component state following the aborted
  operation: catching by itself does not restore valid state.
- The `__TRY ... __FINALLY ... __ENDTRY` construct without a `__CATCH` section is not supported by the compiler.
- In all TwinCAT versions, the `__FINALLY` block is not executed if a secondary exception occurs inside `__CATCH`.

### Try Methods and Terminal OOM

- No exception may escape a Try method, including exceptions from nested calls and callbacks. Review resource cleanup,
  ownership, and post-failure state. Existing implementations must be assessed against this target contract.
- On terminal OOM, a Try method returns failure and leaves the fatal allocation latch set.
- Each task must call `DynamicMemoryManager.RaiseIfAllocationFailed` at its task boundary, outside Try methods and
  recoverable handlers. `AutomationRunner` does this for the tasks it runs; tasks without `AutomationRunner` must do
  it explicitly. Do not clear the latch or allow subsequent execution cycles to continue after terminal OOM.

### Lifecycle Methods

- `FB_init`, `FB_exit`, `FB_reinit`, and helpers called by them must complete without exceptions; do not create or
  raise exceptions and do not use throwing paths as routine failure handling in lifecycle methods.
- TwinCAT calls the base `FB_init` implicitly and passes the parameters with matching names, including when a derived
  class extends the parameter list. Therefore, the absence of duplicate parameter copying or an explicit
  `SUPER^.FB_init` call for base parameters is not an error.
- In the base `FB_init`, do not compute data via overridable methods or properties that read instance fields of the
  derived class (they may not be initialized yet).
- Initialized `VAR_STAT` fields (notably `_ClassName := __POUNAME()`) are ready before the base `FB_init` executes.
  A `ClassName` property that merely returns such a static field without side effects or exceptions can safely be used
  in `FB_init` to construct a default name without lazy initialization or readiness flags.
- In `FB_init`, parameter default values are syntactically permitted, but the compiler does not allow using them
  to omit arguments at call sites. Do not declare misleading defaults in the declaration; explicitly pass all
  additional parameters at every initialization site, including null references for optional dependencies.
- In `PROGRAM`, `FB_init` and `FB_exit` methods are not called automatically by the runtime upon start or unloading.
  Encapsulate program resource cleanup and initialization in a nested FB instance (resource manager) or invoke them
  explicitly.

### Memory and Ownership

- TwinCAT skips `FB_exit` for intermediate stack instances when an exception leaves their method (CODESYS CDS-94841).
  A method may use a local FB that relies on `FB_exit` for cleanup only if it exits normally, catching any exceptions
  that could otherwise escape. If an exception can escape, keep cleanup-dependent FBs in persistent FB/PROGRAM fields
  or on the heap under lifecycle management. Use passive locals such as `ERROR_MESSAGE` or FBs with trivial `FB_exit`.
- `__DELETE(ptr)` automatically invokes `FB_exit` only when the pointer is typed as a concrete function block
  (`POINTER TO FB_Type`). When deleting through `PVOID` or an interface, the runtime only frees memory, and `FB_exit`
  is NOT invoked (risk of resource and handle leaks).
- If `FB_exit` violates its contract during `TryRelease`, the helper returns `FALSE` and clears the passed
  pointer/interface. This does not guarantee deallocation and does not nullify aliases; do not use or re-delete
  a partially destroyed object via other references.
- FB assignment by value performs a bitwise copy without calling `FB_init` or `FB_exit`. Pointers, references, and
  interfaces become aliases. Avoid copying unless the type documents support for it. Document any non-copyable
  contract at the declaration. It applies even without an attribute.
- Use `{attribute 'no_assign'}` when copying breaks ownership, address bindings, or internal relationships. A borrowed
  dependency alone is insufficient. For base types, assess the impact on descendants and library users. Preserve valid
  APIs. If a hard error obstructs required usage, Build 4026 offers `{attribute 'no_assign_warning'}`. Review warnings,
  uphold the non-copyable contract, and have the owner verify the affected scenario before relying on this alternative.
- Obtain owner approval before adding or removing `no_assign` on an existing type or replacing it with
  `no_assign_warning`. Do not change enforcement automatically or in bulk.

### Exception Objects

- Exception objects created in `Clone` must be registered explicitly via
  `DynamicMemoryManager.RegisterAutoDisposedObject` after `__NEW` and the null guard, before copying payload.
  Plain `__NEW` does not transfer ownership to the manager.
- Registration happens outside lifecycle methods; automatic registrars in `FB_init` and deferred OOM registrars
  are not used. Registered dynamic exceptions are owned by `DynamicMemoryManager` until task cleanup; static instances
  remain caller-owned.
- When creating a new exception type or adding payload, verify that `Clone` preserves the concrete type and all of its
  payload data; do not assume an inherited `Clone` is automatically suitable.
- Do not retain references to exceptions after task cleanup and do not pass them across tasks. For long-term
  diagnostics, copy the state into `ERROR`.

## TwinCAT

### Declarations and Metadata

- Mark every new function block and program with
  `{attribute 'no_explicit_call' := 'do not call this function block directly'}`.
- Every new program must provide `ClassName` and `NamespaceName` properties.
- In function blocks, declare `_ClassName : STRING := __POUNAME();` in `VAR_STAT`, never in instance `VAR`.
  In `PROGRAM`, use `VAR` because `VAR_STAT` sections are invalid.
- Before completing changes that add or modify object metadata, inspect every affected declaration: storage
  section, initialization, getter dependencies, and inherited field names. Check existing templates against
  these rules before reuse.

### Compiler and Typing Rules

- When writing or proposing ST, inspect declarations and call sites for the following typing rules:
  - Match the signature of each implemented interface member or overridden base member, including parameter names,
    types, and parameter sections. For additional parameters in a derived `FB_init`, follow Lifecycle Methods.
  - Check `REFERENCE TO` validity via `__ISVALIDREF`; never compare references to 0.
  - `__QUERYINTERFACE` converts only between interfaces. To obtain a pointer to an FB, use `THIS` (pointer to the own
    instance; `THIS^` is the instance itself) or `__QUERYPOINTER` (from an interface).
  - No duplicate field declarations with the same name (notably `_ClassName`) if already declared in a base FB.
  - IEC identifiers are case-insensitive. Parameters and locals shadow same-named instance members. Qualify the
    intended member with `THIS^.` (e.g. `THIS^.Name`), because implicit conversions can let the wrong expression compile.
- Bind `REFERENCE TO` via `REF=`. In a reference property getter, `:=` dereferences the uninitialized result,
  causing an Access Violation / Page Fault and an emergency PLC crash.
- A `REFERENCE TO` property cannot be made truly read-only: direct assignment `fb.Prop := val` dereferences the
  reference and mutates the target object even in the absence of a setter.
- For method parameters of type `REFERENCE TO`, the compiler does not allow passing literals (except string literals)
  or direct method calls (`Method(ref := GetVal())` will not compile); values must be passed via an intermediate
  local variable.
- For `VAR_INPUT` parameters of type `ANY` or `ANY_<type>`, pass variables, not literals, constants, or properties.
  Materialize expressions and function/method results in intermediate variables before passing them to these inputs.
  An explicit type prefix on a literal does not remove this restriction. It applies to every such parameter,
  including both `actual` and `expected` in assertion APIs.
- Default parameter values (optional method arguments) are not supported by the compiler for `ANY` types
  (`ANY_TYPE`, `ANY_STRING`, etc.) or for `VAR_IN_OUT CONSTANT` sections; all such arguments must be passed explicitly
  in the call.
- For new diagnostic string parameters, use `VAR_INPUT` for `STRING(255)` and `WSTRING(255)`.
  Use `VAR_IN_OUT CONSTANT` when the declared capacity exceeds 255 characters.
  Preserve existing API signatures that already pass strings by reference.
- Subclasses of generic function blocks (`VAR_GENERIC CONSTANT`, e.g. `CompositeAutomationComponent<N>`)
  must not redeclare `VAR_GENERIC CONSTANT`. They specialize the base class (`EXTENDS Base<N>`) and directly use
  the inherited generic constant identifier (e.g. `_ChildCount`) to dimension internal arrays
  and member signatures (`ARRAY [0.._ChildCount - 1]`).
- On TwinCAT 3.1 Build 4026, a generic array declared as `ARRAY [0..N - 1]` is empty when `N = 0`, as confirmed
  by the owner. Do not introduce dummy elements or special storage solely to avoid this bound.

### Source Files and Projects

- Preserve XML structure, CDATA, and existing object IDs. Use UTF-8 with BOM and CRLF for new and edited TwinCAT
  source files (`.TcPOU`, `.TcDUT`, `.TcIO`, `.TcGVL`, etc.).
- Edit `.plcproj` entries in place, preserving encoding and structure without re-serializing the XML.
- A new object file (`.TcPOU`, `.TcDUT`, `.TcIO`, `.TcGVL`) starts with `<?xml version="1.0" encoding="utf-8"?>` and
  `<TcPlcObject Version="1.1.0.1">`. Generate a new unique GUID for the object and for every nested element with an
  `Id` (methods, properties, accessors, folders); never reuse IDs copied from other files.
- Place each new object in its subsystem folder and register it in the owning PLC project's `.plcproj`
  as `<Compile Include="relative\path"><SubType>Code</SubType></Compile>`; add `<Folder Include="...">` entries for new
  folders.
- Preserve TwinCAT Referenced Library entries: square brackets in `Resolution` and `DefaultResolution` indicate
  references to the PLC project. Do not remove them, normalize library identity, or change `VirtualLibrary`,
  `PlaceholderReference`, or `PlaceholderResolution` without explicit instruction.
- Actual library resolution is not identical to source files. Do not activate target/hardware for reading or auditing.
  XML parsing does not imply ST compilation.

## Tests and Samples

- Unit tests live in `Sources/TwinCAT.OpenFramework.Tests/Tests/<Area>/`. Name each suite `<Subject>Test`.
- The project is gradually migrating from TcUnit to `TwinCAT.OpenFramework.Testing`. Extend an existing suite
  using its current framework unless its migration is part of the agreed work.
- Connect each new suite to its execution path. For TcUnit, extend `TcUnit.FB_TestSuite` and instantiate the suite
  in `TestAutomationController`. For OpenFramework.Testing, create individual `SingleCycleTest` or `MultiCycleTest`
  descendants and register test/group instances through the `ITestElement` array passed to
  `TestRunner<N>.Configure(children := ...)`.
- TcUnit stops invoking a suite once all its tests are finished. Do not rely on later suite calls after the
  last `TEST_FINISHED()` to drain resources or remove artifacts. Complete cleanup attempts before reporting
  test completion, or provide a cleanup driver independent of the finished suite. Report cleanup failures
  without replacing the original test failure; never treat completion as proof of physical native release.
- Usage examples belong to `TwinCAT.OpenFramework.Samples` and `TwinCAT.OpenFramework.HowTo`; their intended split is
  described in `docs/audit/tests-and-examples-review.md`.
- New behavior and fixed defects must be covered by tests in the same change. Include these tests in the proposed plan;
  approval of the plan authorizes them. If the framework used for the change cannot cover a scenario, state the
  limitation in the plan and propose a manual verification for `docs/audit/validation.md`.

## What "Perform an Audit..." Means

- Define the audit boundaries. List and examine every object in scope, including function
  blocks, programs, functions, interfaces, types, methods, properties, global data, constants, internal helpers, tests,
  and samples. Trace dependencies, inheritance, callbacks, and call sites as deeply as required to verify contracts and
  behavior; do not limit review to public APIs or selective file inspection.
- Verify the existence, completeness, and consistency of contracts against the "Documentation and Contracts" section
  and check code compliance. Record missing or ambiguous contracts separately.
- Assess whether the design solves the stated problem, whether APIs and algorithms are appropriate, and whether
  "Architecture & Design" rules are followed. Justify architectural remarks with specific consequences.
- Look for defects in normal, edge-case, and error scenarios: invalid state transitions, invariant violations, resource
  and memory leaks, improper failure handling, object interaction issues, and, where applicable, cross-task concurrency
  and execution timing. Also evaluate the quality of existing tests and samples, identifying coverage gaps for critical
  scenarios.
- In the report, state scope and limitations, overall assessment of design and implementation, and order findings by
  criticality. For each finding, provide the current code location, core issue, scenario or proof, consequences, and
  a specific recommendation accounting for backward compatibility. Separate confirmed defects from risks, open
  questions, and optional improvements.
- Conclude the report with prioritized next actions, decisions required from the owner, and recommended verifications.
  Explicitly state what was not inspected or verified; do not label a partial audit as complete, and never equate
  reading code with executing tests or confirming runtime behavior.

## Execution Workflow & Verification

- An audit request authorizes analysis and reporting only; code modifications and contract changes require separate
  authorization.
- Work in small, completed steps: do not modify agreed contracts en masse, do not broaden refactoring scope, and do not
  reformat code outside the request.
- Continue unfinished steps of the current owner-approved plan across chats without asking again. A prior plan or
  journal entry does not authorize reapplying a completed or reverted change. Obtain a new owner instruction for that.
- Coordinate new behavioral changes separately. If intent, contract, behavior, or style is ambiguous, ask a concrete
  question before dependent edits and continue independent agreed work meanwhile. Do not invent requirements or
  personal standards, and do not re-ask previously settled decisions.
- Preserve owner changes. Cross-check contracts and older file/line references against current code. Revisit agreed
  decisions only upon new facts or explicit instructions, explaining the rationale.
- Read the required materials and follow dependencies as far as the agreed scope requires.
- Verifications are performed by the owner. Without explicit authorization, do not launch compilation,
  test suites (TcUnit or OpenFramework.Testing), the PLC runtime, XML validation, check scripts, or DocGen generation.
  Reading and searching are permitted. Previous results apply only to the revision verified.
- Git: without a direct instruction from the owner, do not add changes to the staging area, commit (including amend),
  or push. Do not discard or rewrite owner changes (`reset`, `checkout`, `restore`, `stash`). Read-only commands
  (`status`, `diff`, `log`, `show`) are permitted.
- In chat, summarize results, compatibility, pending verification, and decisions required. Show code only for a specific
  problem or architectural choice. For audit reports, follow the audit and local documentation sections.

## Local Documentation

`docs/` is stored locally and is excluded from Git. The governing rules are set forth above; working materials
in `docs/audit/` provide context for decisions and continuation of the audit.

- Record confirmed general rules in `AGENTS.md` and specific contracts next to declarations and in the thematic journal.
  Keep the full audit report in that journal, together with current decisions, changes, open questions, verification
  status, and the next action. Resume from the recorded unfinished step without duplicating history.
- Read `docs/audit/architecture.md` before making architectural changes.
- To continue audits, consult `docs/audit/README.md`, `docs/audit/current-state.md`, `docs/audit/findings.md`,
  `docs/audit/validation.md`, and the respective thematic summary: Core — `docs/audit/core-contracts.md`,
  Tasks and FileSystem — `docs/audit/tasks-contracts.md`, exceptions — `docs/audit/exceptions-status.md`;
  other topics and their journals are indexed in `docs/audit/README.md`.
- DocGen reference: `docs/audit/docgen-migration.md`.

If required local materials are missing, clarify the missing context for dependent work. Governing rules remain
in effect even in the absence of `docs/`.
