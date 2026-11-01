# OpenFramework: Working Rules & Guidelines

These rules apply across the entire project, including tests and samples.
New direct clarifications from the owner take precedence. Prior plans and notes do not constitute permission
to re-apply previously described changes.

Target platform: TwinCAT 3.1 Build 4026. TwinCAT behavior described below is confirmed by the owner and may not yet
be reflected in Beckhoff documentation; do not override it based on documentation or assumptions.

## Terms

- **Owner**: the project author who issues instructions, approves plans and contracts, and performs verifications.
- **Agreed plan / agreed contract**: a plan or contract explicitly confirmed by the owner in chat or recorded
  as a decision in `docs/audit/`.
- **Try method**: any method whose name starts with `Try`, regardless of casing or visibility.
- **Terminal OOM**: a failed dynamic allocation after which the application must not continue normal execution.
- **Fatal allocation latch**: the application-wide state of `DynamicMemoryManager` set on terminal OOM
  (`RaiseAllocationFailure`) and raised by `RaiseIfAllocationFailed`. Task cleanup does not reset it;
  only application reinitialization clears it.
- **`ERROR`**: the Core function block (`Data/Errors/ERROR`) that stores a copied error state independently
  of transient exception objects.

## Language & Communication

- Always converse and communicate with the owner in Ukrainian, unless explicitly requested otherwise.
- Code, comments, identifiers, commit messages, and DocGen documentation must strictly be written in English.
- Working notes and audit journals in `docs/` are maintained in Ukrainian as part of local workspace documentation.

## Documentation and Contracts

- Document new types (FB/class, interface, DUT, etc.), methods, properties, and functions directly next to their
  declaration. When modifying existing ones, update DocGen or add missing descriptions within the scope of the modified
  type or member.
- Format: `(*! ... *)` or `//!` with XML tags `<summary>`, `<description>`, `<param>`. Do not mix DocGen with
  Markdown/rST, and do not add empty sections.
- `<summary>` explains purpose. `<description>` details essential preconditions, results, invariants, state transitions,
  ownership/lifetime, failure conditions and reporting mechanisms, post-failure state, Try/lifecycle guarantees,
  and constraints on inheritance, callbacks, and cross-task usage. Do not paraphrase syntax.
- Distinguish documented guarantees from observed behavior and assumptions. Do not invent a contract based on the
  current implementation.
- For non-obvious constants, document meaning and application. For bitmasks, document which bits are isolated or
  cleared, which representation the mask applies to, and how the result is used.
- Implementation explanations and license notices are standard ST comments. License is MIT (`LICENSE.txt`);
  preserve authorship.
- Standard TwinCAT comments next to system parameters of the `FB_init` method
  (`bInitRetains: BOOL; // TRUE: the retain variables are initialized (reset warm / reset cold)`
  and `bInCopyCode: BOOL; // TRUE: the instance will be copied to the copy code afterward (online change)`)
  must never be moved into the DocGen block as `//!<param name="bInitRetains">...` or `(*! <param ... *)`.
  They must always remain standard TwinCAT inline comments directly next to the respective variables in `VAR_INPUT`.
- Format function block headers in the following order: license block, then DocGen block with `<summary>` and other
  required contract tags, then a blank line, then attributes, followed immediately by the `FUNCTION_BLOCK` declaration.
  Place all block attributes, including `{attribute 'no_explicit_call' := 'do not call this function block directly'}`,
  together after DocGen, not before it or between comment blocks.
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
- Adhere to SOLID and modern design principles: single responsibilities, encapsulation, explicit dependencies,
  and low coupling. Avoid caller dependency on internal structure of nested objects; pass required dependencies
  explicitly. Account for testability, maintainability, contracts, and TwinCAT/ST constraints.
- Choose the simplest understandable code for the agreed contract. Patterns and abstractions must solve a concrete
  problem and simplify maintenance; do not add them purely for formal compliance. Do not add helpers, flags,
  or fallback paths "just in case" (for `TRY/CATCH`, see "Exceptions and Lifecycle"). Explain necessary complexity,
  its cost, and its impact on compatibility; do not hide issues.
- Names of types, members, and variables must explain their role and behavior. Distinguish configuration, current
  state, and observation; name specific actions or failure causes if a generic word obscures meaning (for example,
  `ThrowOnGetMessage` instead of `FailMessage`). Use specific domain terms: `directory`, not `workspace`.
  Do not rename clear identifiers merely for stylistic uniformity.
- Cross-task guarantees exist only where they are documented next to the API. Without such a guarantee, treat an object
  as used by a single task; call-local storage alone does not establish concurrency safety. When adding state shared
  between tasks, document which operations are synchronized and which require external synchronization.

## Structured Text Style

- Implement state machines based on typed enumerations (`TYPE ... ENUM`), never numerical variables with constant sets.
  State names must explain the step or phase.
- One statement per line. Format `IF/ELSIF/ELSE/END_IF`, loops, `CASE`, and `TRY/CATCH` multiline, even for a single
  `RETURN` or call.
- For multiline `IF` conditions, place `THEN` on a separate line indented to match `IF`.
- In comparisons with boundaries and special values, use constants of the corresponding framework types.
  Add missing constants to the appropriate type along with a description of their purpose.
- Separate independent groups of declarations and algorithm steps with blank lines, not every variable or operation.
- ST code is indented with tabs. Take indentation, casing, and formatting cues from consistent surrounding owner
  patterns; condensed agent constructions are not the reference standard.
- In property getters, an early `RETURN` without assigning a result returns the default/initial value of the type.
  Do not add local `defaultValue` variables and assignments purely to duplicate this default initialization.
- Limit line length of ST statements to 120-140 characters. When a call or expression exceeds this boundary or has
  many parameters, format it across multiple lines: place each argument on its own indented line, and place
  the closing parenthesis `);` on a separate line indented to match the level of the call.
- Method, function, and function block calls must explicitly specify parameter names using `:=`
  (e.g. `fb.Method(param1 := val1, param2 := val2)`). Exceptions:
  - Built-in single-argument type conversions and standard operators (`ADR`, `SIZEOF`, `TO_*`, `__QUERYINTERFACE`,
    `__ISVALIDREF`).
  - Variadic-style string helper functions designed for concise multi-fragment concatenation (`Concat255`,
    `ConcatFit255`, `Append255`, `AppendFit255` when passing sequential text fragments).

### Naming Conventions

- Classes/FBs and interfaces use PascalCase without type prefixes (`List`, `AutomationRunner`); interface names start
  with `I` (`IAutomationComponent`).
- Enumerations and structures use UPPER_SNAKE_CASE for type names and enumeration values (`OPERATIONAL_STATE`,
  `ERROR_MESSAGE`). Some data-holder FBs follow the same style (`ERROR`, `GENERIC_VALUE`); follow the pattern
  of the surrounding area.
- Public, protected, and internal methods and properties use PascalCase; private methods use camelCase
  (`cleanupTaskMemory`).
- Private fields of classes/FBs use the `_` prefix with PascalCase (`_AllocationFailed`); local variables and
  parameters use camelCase without the prefix.
- Do not use Hungarian notation or type-denoting prefixes (`p`, `b`, `s`, `str`, `n`, `i`, `a`, etc.) for variables,
  parameters, or pointers. Use clear semantic names describing purpose: `data`, `targetWords`, `currentLength`,
  `newMemory` (not `pData`, `pWords`, `nLen`, `pNewMemory`).
  - Short single-letter variables are permitted exclusively as simple integer loop counters (`i`, `j`, `k`).
  - The only permitted exception with type prefixes is standard TwinCAT runtime system parameters in `FB_init`
    (`bInitRetains`, `bInCopyCode`).
- Do not rename third-party APIs.

## Exceptions and Lifecycle

### Exception Usage

- Use exceptions purposefully: to interrupt an operation and propagate a failure that the contract does not represent
  as a regular outcome. Regular results—including allowable absence, pending states, or Try failures—must be expressed
  via designated API return values or states. The criterion is the contract, not event frequency.
- Deleting a missing value can be a no-op even in an empty collection; document behavior next to the API.
- Invalid arguments, mandatory preconditions, and terminal OOM must be checked. Do not relax validations or replace
  agreed exceptions with error codes en masse.
  User explanation: [Rational Exception Handling](Concepts/Exceptions/ExceptionsConcept.md#when-to-use-exceptions).
- Do not add `TRY/CATCH` "just in case". When adding `Throw` or `TRY/CATCH`, explain its purpose: why a regular outcome
  is insufficient, where failure is handled, or what no-throw contract is enforced. Do not create an exception merely
  to immediately convert an expected outcome into a status code via `CATCH`.
- Catching must perform a defined action: recovery, cleanup, conversion into a result/diagnostic, or rethrowing with
  context. If continuation after an exception is permitted, define the component state following the aborted
  operation: catching by itself does not restore valid state.
- The `__TRY ... __FINALLY ... __ENDTRY` construct without a `__CATCH` section is not supported by the compiler.
- In all TwinCAT versions, the `__FINALLY` block is not executed if a secondary exception occurs inside `__CATCH`.

### Try Methods and Terminal OOM

- Try methods must never leak exceptions, including from nested calls and callbacks. This is a target contract,
  not a guarantee of existing code conformance. Analyze allocations, resources, state, and ownership after failure:
  `CATCH` alone is insufficient if it leaves state corrupt or resources leaked.
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
  in `FB_init` to construct a default name without lazy initialization or readiness flags. Always inspect actual
  storage and dependencies of the getter.
- In `FB_init`, parameter default values are syntactically permitted, but the compiler does not allow using them
  to omit arguments at call sites. Do not declare misleading defaults in the declaration; explicitly pass all
  additional parameters at every initialization site, including null references for optional dependencies.
- In `PROGRAM`, `FB_init` and `FB_exit` methods are not called automatically by the runtime upon start or unloading.
  Encapsulate program resource cleanup and initialization in a nested FB instance (resource manager) or invoke them
  explicitly.

### Memory and Ownership

- TwinCAT does not perform stack unwinding upon exceptions (CODESYS CDS-94841): the runtime resets the stack
  pointer directly to the `__CATCH` frame without calling `FB_exit` for intermediate stack-allocated instances.
  Never declare local FBs (`VAR` in `METHOD`) that rely on `FB_exit` for cleanup (e.g. freeing heap memory or closing
  handles) in call paths that can raise or propagate exceptions. Such FBs may only be instantiated on the heap under
  lifecycle management, as persistent instance fields (`VAR` of an FB/`PROGRAM`), or locally within the method
  hosting `__TRY/__CATCH` that intercepts the exception and completes via normal exit. Throwing paths must strictly
  use passive types, plain strings (`ERROR_MESSAGE`), or FBs with trivial/empty `FB_exit`.
- `__DELETE(ptr)` automatically invokes `FB_exit` only when the pointer is typed as a concrete function block
  (`POINTER TO FB_Type`). When deleting through `PVOID` or an interface, the runtime only frees memory, and `FB_exit`
  is NOT invoked (risk of resource and handle leaks).
- If `FB_exit` violates its contract during `TryRelease`, the helper returns `FALSE` and clears the passed
  pointer/interface. This does not guarantee deallocation and does not nullify aliases; do not use or re-delete
  a partially destroyed object via other references.
- Assigning FB instances by value (`fb_B := fb_A`) performs a bitwise `MEMCPY` without calling `FB_init` or `FB_exit`.
  If the FB contains pointers, references, or interfaces, copying creates hazardous aliases (shallow copy) and violates
  ownership models (risk of double-free or unexpected mutations); avoid copying such objects by value.
- To make such copying a compile-time error, new FBs that own pointers, references, or interfaces may declare
  `{attribute 'no_assign'}`. Do not add it to existing types without owner approval: it breaks call sites that copy
  instances.

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

### Compiler and Typing Rules

- Before issuing or writing ST code, verify it against TwinCAT typing and compiler rules:
  - Exact signature identity between `INTERFACE`, base FB, and derived classes (types,
    `VAR_INPUT`/`VAR_OUTPUT`/`VAR_IN_OUT CONSTANT` sections, parameter names).
  - Binding `REFERENCE TO` via `REF=` and checking validity via `__ISVALIDREF` (never compare references to 0).
  - `__QUERYINTERFACE` converts only between interfaces. To obtain a pointer to an FB, use `THIS` (pointer to the own
    instance; `THIS^` is the instance itself) or `__QUERYPOINTER` (from an interface).
  - No duplicate field declarations with the same name (notably `_ClassName`) if already declared in a base FB.
- In a property getter of type `REFERENCE TO`, always use the `REF=` operator (never `:=`); otherwise, dereferencing
  an uninitialized reference causes an exception (Access Violation / Page Fault) and triggers an emergency PLC crash.
- A `REFERENCE TO` property cannot be made truly read-only: direct assignment `fb.Prop := val` dereferences the
  reference and mutates the target object even in the absence of a setter.
- For method parameters of type `REFERENCE TO`, the compiler does not allow passing literals (except string literals)
  or direct method calls (`Method(ref := GetVal())` will not compile); values must be passed via an intermediate
  local variable.
- Default parameter values (optional method arguments) are not supported by the compiler for `ANY` types
  (`ANY_TYPE`, `ANY_STRING`, etc.) or for `VAR_IN_OUT CONSTANT` sections; all such arguments must be passed explicitly
  in the call.
- Pass diagnostic strings longer than 255 characters via `VAR_IN_OUT CONSTANT`; `STRING(255)`/`WSTRING(255)` remain
  `VAR_INPUT`. Do not revert APIs that already pass strings by reference.
- In `PROGRAM`, `VAR_STAT` sections are invalid; keep `_ClassName` in `VAR`.

### Source Files and Projects

- TwinCAT source files are XML with CDATA: preserve structure and object IDs. Edit `.plcproj` files surgically without
  re-serializing the entire XML.
- TwinCAT source files (`.TcPOU`, `.TcDUT`, `.TcIO`, `.TcGVL`, etc.) use UTF-8 with BOM and CRLF line endings.
  Do not strip BOM when editing; new source files must be created with UTF-8 BOM and CRLF.
  Edit `.plcproj` files surgically without re-serializing the entire XML, preserving their encoding and structure.
- A new object file (`.TcPOU`, `.TcDUT`, `.TcIO`, `.TcGVL`) starts with `<?xml version="1.0" encoding="utf-8"?>` and
  `<TcPlcObject Version="1.1.0.1">`. Generate a new unique GUID for the object and for every nested element with an
  `Id` (methods, properties, accessors, folders); never reuse IDs copied from other files.
- Place a new file in the folder of its subsystem and register it in the library `.plcproj`
  as `<Compile Include="relative\path"><SubType>Code</SubType></Compile>`; add `<Folder Include="...">` entries for new
  folders.
- Preserve TwinCAT Referenced Library entries: square brackets in `Resolution` and `DefaultResolution` indicate
  references to the PLC project. Do not remove them, normalize library identity, or change `VirtualLibrary`,
  `PlaceholderReference`, or `PlaceholderResolution` without explicit instruction.
- Actual library resolution is not identical to source files. Do not activate target/hardware for reading or auditing.
  XML parsing does not imply ST compilation.

## Tests and Samples

- Unit tests use TcUnit and live in `Sources/TwinCAT.OpenFramework.Tests/Tests/<Area>/`. A test suite is an FB named
  `<Subject>Test` that extends `TcUnit.FB_TestSuite`.
- Usage examples belong to `TwinCAT.OpenFramework.Samples` and `TwinCAT.OpenFramework.HowTo`; their intended split is
  described in `docs/audit/tests-and-examples-review.md`.
- New behavior and fixed defects must be covered by tests in the same change. Include these tests in the proposed plan;
  approval of the plan authorizes them. If a scenario cannot be covered by TcUnit, state this in the plan and propose
  a manual verification for `docs/audit/validation.md`. Test runs are performed by the owner.

## What "Perform an Audit..." Means

- An "audit" request means a comprehensive analysis of the specified project scope from the perspective of an architect
  and experienced engineer, resulting in a structured report and actionable recommendations.
- First, define the audit boundaries and the list of objects. Cover all objects within these boundaries: function
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
- After completing an item of the current agreed plan, automatically proceed to the next one: analyze it and implement
  authorized changes without an extra "should I continue?" prompt. Do not stop simply because a single step completed.
- Coordinate new behavioral changes separately. If intent, contract, behavior, or style is ambiguous, ask a concrete
  question before dependent edits and continue independent agreed work meanwhile. Do not invent requirements or
  personal standards, and do not re-ask previously settled decisions.
- Preserve owner changes. Cross-check contracts and older file/line references against current code. Revisit agreed
  decisions only upon new facts or explicit instructions, explaining the rationale.
- Search and read relevant fragments; expand reading along dependencies. Do not re-read current files unnecessarily,
  but never skip mandatory materials or sacrifice analysis completeness to conserve context.
- Verifications are performed by the owner. Without explicit authorization, do not launch compilation, TcUnit/runtime,
  XML validation, check scripts, or DocGen generation. Reading and searching are permitted. Old verifications do not
  confirm new revisions of code.
- Git: without a direct instruction from the owner, do not add changes to the staging area, commit (including amend),
  or push. Do not discard or rewrite owner changes (`reset`, `checkout`, `restore`, `stash`). Read-only commands
  (`status`, `diff`, `log`, `show`) are permitted.
- In chat, report concisely: results, compatibility, what remains unverified, and what decisions are required;
  maintain the full audit report in the dedicated thematic journal. Show code only for a specific problem or
  architectural choice.

## Local Documentation

`docs/` is stored locally and is excluded from Git. The governing rules are set forth above; working materials
in `docs/audit/` provide context for decisions and continuation of the audit.

- Record new confirmed general rules in `AGENTS.md`, and specific contracts next to declarations and in the thematic
  journal. In the journal, concisely maintain audit findings, current step, decisions, changes, open questions,
  verifications, and next action; do not duplicate history.
- When transitioning to a new chat, continue using the plan and journal without re-auditing completed work or requiring
  a new chat after each step. Do not stop authorized work merely to shorten context.
- Read `docs/audit/architecture.md` before making architectural changes.
- To continue audits, consult `docs/audit/README.md`, `docs/audit/current-state.md`, `docs/audit/findings.md`,
  `docs/audit/validation.md`, and the respective thematic summary: Core — `docs/audit/core-contracts.md`,
  Tasks and FileSystem — `docs/audit/tasks-contracts.md`, exceptions — `docs/audit/exceptions-status.md`;
  other topics and their journals are indexed in `docs/audit/README.md`.
- DocGen reference: `docs/audit/docgen-migration.md`.

If required local materials are missing, clarify the missing context for dependent work. Governing rules remain
in effect even in the absence of `docs/`.
