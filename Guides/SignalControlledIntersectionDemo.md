# Signal-Controlled Intersection Automation – Technical Guide

## 1. Enumeration Definitions

### 1.1. SIGNAL_CONTROLLED_INTERSECTION_MODE  
Defines the general control mode of the intersection.

### 1.2. SIGNAL_CONTROLLED_INTERSECTION_STATE  
Defines the current state of the intersection. Based on this state, the logic activates appropriate signals on four traffic lights. 
The values `ALL_YELLOW`, `_1_3_YELLOW_AND_2_4_YELLOW`, and `_2_4_YELLOW_AND_1_3_YELLOW` are similar because they turn on yellow on all traffic lights, but carry additional information to determine the next state transition.

### 1.3. TRAFFIC_LIGHT_COLOR  
Defines the state of a single traffic light.

---

## 2. Implement the TrafficLight Device

The TrafficLight device consists of three standard internal `DigitalOutput` devices (for red, yellow, and green). It inherits from the abstract class `TOF_Automation.OutputDevice<3>`, indicating that it includes 3 internal subdevices.

Inheritance requires implementation of:
- Three abstract properties: `ClassName`, `Size`, `SubDevices`
- One abstract method: `OnUpdateOutputsFromState`
- One custom method: `SetLight`

#### 2.1. ClassName  
Required by the framework, returns the name of the current class (function block). Used for exception reporting.

#### 2.2. Size  
Used by the framework to manage dynamic memory.

#### 2.3. SubDevices  
Returns a reference to the array containing actual internal devices (digital outputs for turning on the light indicators).

#### 2.4. OnUpdateOutputsFromState  
Responsible for passing internal virtual device data to terminals or external objects. At the traffic light level, this does nothing. Actions are already implemented in `Devices.IO` library.

#### 2.5. SetLight  
Method to control the traffic light by passing a color to activate.

---

## 3. Implement the Automation Module: `SignalControlledIntersectionAutomationUnit`

This module contains logic for interaction between six devices:
  - ON/OFF input
  - Mode switch (standard vs blinking yellow)
  - Four traffic lights
It inherits from `TOF_AutomationEngine.AutomationUnit<6>`.
It Implements abstract members: `ClassName`, `Size`, `Devices`, `StartRequest`
Overrides: `StopRequest`, `OnInitialize`, `OnStop`, `OnRun`

#### 3.1. StartRequest  
Signals the engine to enter RUN state. Returns the value of the ON/OFF switch.

#### 3.2. StopRequest  
Signals the engine to enter STOPPED state. Returns the inverted value of the ON/OFF switch.

#### 3.3. OnRun  
Method called cyclically while in RUN state. Contains core traffic light logic.

#### 3.4. OnInitialize  
Used during initialization phase. Returns `TRUE` once initialization is complete. In this case, sets timer values in one cycle.

#### 3.5. OnStop  
Called cyclically in STOPPED state. Turns off all traffic lights.

---

## 4. Implement the Automation Runner: `SignalControlledIntersectionAutomationRunner`

This runner manages automation modules. It controls one instance of `SignalControlledIntersectionAutomationUnit` and inherits from `TOF_AutomationEngine.AutomationRunner<1>`.

Implements:
- `ClassName`
- `Size`
- `AutomationUnits` – returns array of controlled automation units (1 element)
- `FB_Init` – enables simulation mode (for demo project without real terminals)

---

## 5. MAIN Program Setup

In the `MAIN` program:
- Create instance of `SignalControlledIntersectionAutomationRunner`
- Call its `Run` method

---

## Conclusion

That’s all you need. Everything is straightforward once you understand the framework ideology. Visualizations are just auxiliary components for demonstration and verification.
