# Signal-Controlled Intersection Automation – Technical Guide

This description shows how to create simple application using `TwinCAT_OpenFramework_Automation` library

## 1. Enumeration Definitions

### 1.1. INTERSECTION_MODE  
Defines the general control mode of the intersection.

### 1.2. INTERSECTION_STATE  
Defines the current state of the intersection. Based on this state, the logic activates appropriate signals on four traffic lights. 
The values `ALL_YELLOW`, `_1_3_YELLOW_AND_2_4_YELLOW`, and `_2_4_YELLOW_AND_1_3_YELLOW` are similar because they turn on yellow on all traffic lights, but carry additional information to determine the next state transition.

### 1.3. TRAFFIC_LIGHT_COLOR  
Defines the state of a single traffic light.

---

## 2. Implement the TrafficLight Device

The TrafficLight device consists of three standard `DigitalOutput` sub-devices (for red, yellow, and green light). It inherits from the abstract class `TOF_Automation.CompositeDevice<3>`, where `<3>` indicates that it includes 3 subdevices.

Implementation consists of:
- Properties: `BoundToIO`, `Children`, `ClassName`, `NamespaceName`, `SelfSize`
- Methods: `BindToIO`, `SetLight`

#### 2.1. BoundToIO  
Required by `IIOBindable` interface. Indicates if all lights (digital outputs) are mapped to I/O models (terminal variables).

#### 2.2. Children  
Required by ancestor (`CompositeDevice`). Returns a reference to the array containing sub-devices (digital outputs for turning on the lights).

#### 2.3. ClassName  
Required by the framework. Returns the name of the current class (function block). Used for exception reporting.

#### 2.4. NamespaceName  
Required by the framework. Returns the namespace of the current class (function block). Used for exception reporting.

#### 2.5. SelfSize  
Required by the framework. Used in case of dynamic memory management.

#### 2.6. BindToIO  
Creates mapping from lights (digital outputs) to I/O terminal variables.

#### 2.7. SetLight  
Method to control the traffic light by passing a color to activate.

---

## 3. Implement the Automation Module: `SignalControlledIntersectionAutomationController`

This module contains logic for interaction between six devices:
  - ON/OFF input
  - Mode switch (standard vs blinking yellow)
  - Four traffic lights
It inherits from `TOF_AutomationEngine.AutomationController<6>`.
It Implements abstract members: `ClassName`, `Size`, `Devices`, `StartRequest`
Overrides: `StopRequest`, `OnInitialize`, `OnStop`, `OnRun`, `OnFault`

#### 3.1. StartRequest  
Signals the engine to enter RUN state. Returns the value of the ON/OFF switch.

#### 3.2. StopRequest  
Signals the engine to enter STOPPED state. Returns the inverted value of the ON/OFF switch.

#### 3.3. OnInitialize  
Used during initialization phase. Returns `TRUE` once initialization is complete. In this case, sets timer values in one cycle.

#### 3.4. OnRun  
Method called cyclically while in RUN state. Contains core traffic light logic.

#### 3.5. OnStop  
Called cyclically in STOPPED state. Turns off all traffic lights.

#### 3.6. OnFault
Called cyclically in FAULTED state. Turns off all traffic lights.

---

## 4. Implement the Automation Runner: `SignalControlledIntersectionAutomationRunner`

This runner manages automation modules. It controls one instance of `SignalControlledIntersectionAutomationController` and inherits from `TOF_AutomationEngine.AutomationRunner<1>`.

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
