# Signal-Controlled Intersection Automation – Technical Guide

This guide walks through the `Intersection` demo application in `Sources/TwinCAT.OpenFramework.Samples/Intersection/`, built using `TwinCAT_OpenFramework_Automation` (`TOF_Automation`), `TwinCAT_OpenFramework_Devices_IO` (`TOF_Devices_IO`), `TwinCAT_OpenFramework_IO_Models` (`TOF_IOModels`), and `TwinCAT_OpenFramework_Timers` (`TOF_Timers`).

---

## 1. Enumeration and Range Types

### 1.1. `INTERSECTION_MODE`
Defines the controller operating mode: `OFF`, `WORKING`, `FLASHING_YELLOW`.

### 1.2. `INTERSECTION_LIGHTS_STATE`
Defines the signal phase of the four traffic lights: `ALL_OFF`, `ALL_YELLOW`, `GROUP1_GREEN_GROUP2_RED`, `GROUP1_RED_GROUP2_GREEN`.

### 1.3. `TRAFFIC_LIGHT_COLOR`
Defines the color state of a single traffic light: `NO_COLOR`, `RED`, `YELLOW`, `GREEN`.

### 1.4. `SPEED_CORRECTION_PERCENT`
Subrange `SINT` defining the switching-interval speed correction percentage (`-20..+20`, bounded by `IntersectionConstants`).

---

## 2. Implement the `TrafficLight` Composite Device

`TrafficLight` groups three `TOF_Devices_IO.DigitalOutput` devices (`_RedLight`, `_YellowLight`, `_GreenLight`) inside a `TOF_Automation.CompositeAutomationComponent<3>` implementing `ITrafficLight`.

Key members:
* **Properties**: `ActiveLight`, `BoundToIO`, `Children` (returns `_Children` by reference), `RedLight` / `YellowLight` / `GreenLight` (`IReadOnlyDigitalOutput`), `ClassName` (from `VAR_STAT _ClassName`), `NamespaceName`, `SelfSize`.
* **Methods**:
  * `BindToIO(redLightRawValue, yellowLightRawValue, greenLightRawValue)` — links the three `DigitalOutput` devices to raw `BOOL` I/O variables from `TerminalModels`.
  * `TrySetLight(color, rejectReason) : BOOL` — asks `Parent.RequestActionPermission(...)` (with `TrySetLightActionDescriptor`) whether changing the light is allowed, updates the three outputs, catches any exceptions so it never throws, and returns `FALSE` if `TOF_Core.DynamicMemoryManager.HasAllocationFailed` reports an out-of-memory error.

---

## 3. Implement the Controller: `IntersectionController`

`IntersectionController` extends `TOF_Automation.AutomationController<12>` implementing `IIntersectionController`. It coordinates 12 child components (`_Devices`), three `TOF_Timers.Timer` instances (`_RedGreenLightTimer`, `_YellowLightTimer`, `_FlashingYellowLightTimer`), and a `DemoExceptionHandlingPolicy`:

* **6 `TOF_Devices_IO.DigitalInput` buttons**: `_ResetButton`, `_TurnOnButton`, `_TurnOffButton`, `_SetYellowFlashingModeOnButton`, `_SetYellowFlashingModeOffButton`, `_AdjustSpeedButton`.
* **1 `TOF_Devices_IO.AnalogInput`**: `_SwitchSpeedAdjuster` scaled `-20..+20` via `StaticRangeAnalogValueConverter`.
* **4 `TrafficLight` composites**: `_TrafficLight1`..`_TrafficLight4` (grouped into `_SignalGroup1` = `{1, 3}` and `_SignalGroup2` = `{2, 4}`).
* **1 `DemoExceptionGenerator`**: `_DemoExceptionGenerator` (`"WatchdogDevice"`, configured with `_DemoExceptionHandlingPolicy` in `FB_init`).

Key lifecycle and cyclic members:
* **`FB_init(name, plugins)`**: assigns `_DemoExceptionHandlingPolicy` to `_DemoExceptionGenerator` and registers the HMI plugin array via `AssignPlugins(plugins := plugins)` (keep that array alive while the controller runs).
* **`OnBeforeChildrenInitializing`**: sets timer intervals from `IntersectionConstants` and calls `bindIO()` to link child devices to `TerminalModels`.
* **`OnBeforeChildrenStopped`**: watches `_ResetButton` so a physical reset button can call `Reset()` while `STOPPED`.
* **`OnBeforeChildrenWorking`**: updates the timers, reads buttons and speed adjuster, and runs `processNormalMode()` or `processBlinkingYellowMode()`.
* **`OnOperationalStateChanged`**: turns all traffic lights off when entering `OPERATIONAL_STATE.STOPPED`.
* **Commands & Statuses**: `TurnOn`, `TurnOff`, `SetYellowFlashingModeOn`, `SetYellowFlashingModeOff`, `SetSwitchingSpeedCorrectionPercent`, `ThrowExceptionInDemoExceptionGenerator`, `Mode`, `LightsState`, `OperationalStateName`.

---

## 4. Implement the HMI Plugin: `HmiIntersectionController` & `HmiTrafficLight`

`HmiIntersectionController` extends `TOF_Automation.HmiAutomationComponentElement` and implements `TOF_Automation.IAutomationControllerPlugin`:

* **`OnBeforeControllerExecute`**: calls `ProcessAutomationComponentCommands(automationComponent := controller)` first so `Enable`, `Disable`, and `Reset` HMI commands still work even while the controller is disabled. Machine-control commands (`TurnOn`, `TurnOff`, flashing mode, speed correction, and manual traffic-light overrides via `HmiTrafficLight`) only run when `controller.Enabled` is `TRUE`.
* **`OnAfterControllerExecute`**: calls `UpdateAutomationComponentStatuses(automationComponent := controller)` and refreshes intersection and per-light statuses on every serviced cycle (`WORKING` and `STOPPED`).

---

## 5. Implement I/O Terminal Models: `TerminalModels`

`PROGRAM TerminalModels` holds the `TOF_IOModels` I/O structures used by `IntersectionController.bindIO()`:
* **`DI_1` (`TOF_IOModels.EL1018`)** — 8-channel digital input terminal (buttons).
* **`DO_2` (`TOF_IOModels.EL2409`)** — 16-channel digital output terminal (traffic light lamps).
* **`AI_3` (`TOF_IOModels.EL3001`)** — single-channel standard INT16 analog input terminal (requires standard status-plus-INT16 PDO).

*(Note: `TerminalModels` uses basic terminal structures without EtherCAT bus status fields. For an example showing `WcState` and channel-status checks with `_EX` models, see `Sources/TwinCAT.OpenFramework.HowTo/IO/IOModelsExample.TcPOU` and [IO Models Guide](IOModels.md).)*

---

## 6. `MAIN` Program Setup

In `Sources/TwinCAT.OpenFramework.Samples/MAIN.TcPOU`, declare the HMI plugin, plugin array, controllers, and root array **before** `AutomationRunner`:

```iecst
PROGRAM MAIN
VAR_OUTPUT
	IntersectionHMI : HmiIntersectionController;
END_VAR
VAR
	{attribute 'hide'}
	_IntersectionPlugings : ARRAY [0..0] OF TOF_Automation.IAutomationControllerPlugin := [IntersectionHMI];
END_VAR
VAR_OUTPUT
	IntersectionController : IntersectionController("IntersectionController", _IntersectionPlugings);
	DemoWorkflowController : DemoWorkflowController("DemoWorkflowController");
END_VAR
VAR
	{attribute 'hide'}
	_AutomationControllers : ARRAY [0..1] OF TOF_Automation.IAutomationComponent :=
	[
		IntersectionController,
		DemoWorkflowController
	];

	{attribute 'hide'}
	_LogFilter : LogFilter;
	{attribute 'hide'}
	_LogFilterInitialized : BOOL;
END_VAR
VAR_OUTPUT
	Runner : TOF_Automation.AutomationRunner(components := _AutomationControllers);
END_VAR
```

On the first cycle, `MAIN` installs `_LogFilter` via `TOF_Core.LogManager.Filter := _LogFilter;`, then calls `Runner.Execute();` once per task cycle. Keep `_AutomationControllers`, `_IntersectionPlugings`, and all referenced instances alive and in fixed order for the lifetime of `Runner`.
