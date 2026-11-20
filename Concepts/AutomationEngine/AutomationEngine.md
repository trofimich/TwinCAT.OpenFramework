# AutomationEngine Concept (`TOF_Automation`)

## 1. General Description

`TwinCAT.OpenFramework.Automation` (`TOF_Automation`) helps you organize machines and production lines into a clear tree of reusable parts instead of tangled, hard-coded state machines. It gives every machine part the same lifecycle states, separates reading/writing hardware I/O from machine logic, handles errors and action permissions across the tree, supports simulation, and keeps HMI plugins running even when a unit is disabled.

---

## 2. Architecture: `AutomationRunner -> AutomationController -> Branches & Leaves`

The framework splits every machine into two layers using a fixed tree of static function blocks:

* **Branches (`AutomationController`, `CompositeAutomationComponent`):** coordinate machine logic and child parts.
* **Leaves (`LeafAutomationComponent`, I/O devices):** talk directly to hardware inputs and outputs.

---

## 3. Core Entities

### 3.1. `AutomationRunner`

The top-level runner you call once per PLC task cycle (`TOF_Automation.AutomationRunner`):

* Takes an array of root `IAutomationComponent` objects in `FB_init(components := ...)` (keep that array alive and unchanged while the runner exists).
* Initializes and runs all root components in one owning PLC task (`Execute()` takes no arguments; do not call `Execute()` again from inside a component callback).
* Automatically runs `TOF_Core.System.Execute()`, services `TOF_Core.LogManager.ExecuteCurrentTaskLogger()`, checks the global out-of-memory flag via `DynamicMemoryManager.RaiseIfAllocationFailed()`, and cleans up temporary exceptions at the end of every cycle.
* States (`AUTOMATION_RUNNER_STATE`): `INITIALIZING`, `RUNNING`, or `INVALID` (if setup or root initialization failed; see `InitializationErrorMessage`).

### 3.2. `AutomationComponent`

The base class shared by every node in the machine tree (`TOF_Automation.AutomationComponent` extending `TOF_Core.Object`):

* Operational states (`OPERATIONAL_STATE`):
  * `INITIALIZING` — startup state after PLC start; checks required dependencies and runs `Initialize()` until ready or `InitializationTimeout` expires (`T#0S` automatically uses `Parameters.InitializationTimeout`).
  * `WORKING` — normal cyclic operation after startup succeeds.
  * `STOPPED` — entered via `Stop(reason)` (works `WORKING -> STOPPED` even if `Enabled = FALSE`) or when an error policy stops the component; requires `Reset()` while `Enabled = TRUE` to return to `WORKING`.
  * `INVALID` — failed setup state entered if required dependencies, tree wiring, or initialization fail (cannot be recovered at runtime).
* **Safe recovery**: if a component's own reset step (`OnReset`, `OnBeforeChildrenReset`, `OnAfterChildrenReset`) or automatic recovery step (`OnRecover`) throws an error, the component always records a `CRITICAL` error and stays in (or moves to) `STOPPED` — it does not ask `ExceptionHandlingPolicy` whether to ignore it.
* **Events**: `BroadcastEvent` (top-down) and `BubbleEvent` (bottom-up) pass events through the tree immediately, even when a node is stopped or `Enabled = FALSE`. Setting `stopPropagation := TRUE` stops forwarding along that branch.

### 3.3. `BranchAutomationComponent`

Base class for parent nodes that manage child components (`IParentAutomationComponent`):

* **`AutomationController<N>`** — top-level controller for a machine or unit (holds `N` children; `N = 0` empty arrays are valid on TwinCAT 3.1 Build 4026). Supports `IAutomationControllerPlugin` plugins (such as `HmiAutomationComponentElement`), whose `OnBeforeControllerExecute` / `OnAfterControllerExecute` methods keep running in `WORKING` and `STOPPED` even when `Enabled = FALSE`. Runs `ProcessInput` on enabled children before machine logic (`OnBeforeExecute`) and `ProcessOutput` after (`OnAfterExecute`).
* **`CompositeAutomationComponent<N>`** — mid-level sub-machine block (must receive its `Parent` in `FB_init`). Groups related devices into one unit and forwards `ProcessInput`, `ProcessOutput`, and `BubbleEvent`.
* Checks before startup that no slot in `Children` is empty, no child appears twice, and every child's `Parent` matches this branch. Runs `OnAfterChildrenInitializing` only after all children finish initializing, and extends its own `InitializationTimeout` so it waits at least as long as its slowest child.
* Reacts to critical child errors via `IChildCriticalErrorHandlingPolicy` (`SetErrorAndStop`, `SetErrorAndContinue`, `Ignore`) and checks hierarchical permissions via `IActionPermissionPolicy` (`RequestActionPermission`). With `SetErrorAndContinue`, the parent keeps its copied non-critical error and waits to call `OnRecover` until every enabled child has cleared its critical error.

### 3.4. `LeafAutomationComponent`

End-point node with no children (`IChildAutomationComponent`, must receive its `Parent` in `FB_init`):

* `InputLeafAutomationComponent` (`ProcessInput` / `OnProcessInput`)
* `OutputLeafAutomationComponent` (`ProcessOutput` / `OnProcessOutput`)
* `InputOutputLeafAutomationComponent` (both input and output phases)
* Ready-made I/O devices (`DigitalInput`, `DigitalOutput`, `AnalogInput`, `AnalogOutput`) live in `TwinCAT.OpenFramework.Devices.IO` (`TOF_Devices_IO`), with simulation support (`ISimulatable`, `IConfigurableSimulatable`, `IChildSimulatable`, `IChildConfigurableSimulatable`, `SIMULATION_MODE_OVERRIDE`).

---

## 4. Static Child Arrays via `VAR_GENERIC CONSTANT`

Controllers and composites set their child count at compile time using `VAR_GENERIC CONSTANT _ChildCount : TOF_Core.INT_LENGTH := 0`:

* Child arrays (`ARRAY [0.._ChildCount - 1] OF IChildAutomationComponent`) are sized at compile time (including `N = 0` on Build 4026) with no dynamic memory allocation.
* Each child receives its `Parent` in `FB_init` and sits in one fixed slot in its parent's `Children` array.
* Components can be nested as deeply as your machine design requires, limited only by the PLC task's call stack and cycle time.

---

## 5. Static Automation vs. Dynamic Workflow

* Use **`AutomationController` + typed `ENUM` state machines + `Tasks`** for fixed physical equipment, cycle-by-cycle I/O control, and HMI screens.
* Use **`TOF_Workflow.Workflow`** for flexible sequences or recipes loaded/changed at runtime (such as JSON files). See [Workflow Construction Guide](../../Guides/WorkflowConstruction.md).

---

## 6. Hierarchy Diagram & Example

![Automation object hierarchy](AutomationObjectHierarchy.png)

Complete demo application: `TwinCAT.OpenFramework.Samples` (`Intersection` and `Workflow`).
Walkthrough: [Signal-Controlled Intersection Demo Guide](../../Guides/SignalControlledIntersectionDemo.md).
