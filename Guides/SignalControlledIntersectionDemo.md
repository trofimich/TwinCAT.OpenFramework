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

## 3. Implement the controller: `IntersectionController`

This module contains logic for interaction between seven devices:
  - ON/OFF input
  - Mode switch (standard vs blinking yellow)
  - Switch speed adjuster
  - Four traffic lights
It inherits from `TOF_AutomationEngine.AutomationController<7>`.
It implements public properties: `Children`, `ClassName`, `NamespaceName`, `OperationalStateName`, `SelfSize`
Overrides: `OnBeforeChildrenInitializing`, `OnBeforeChildrenStopped`, `OnBeforeChildrenWorking`, `OnGetExceptionSeverity`, `OnOperationalStateChanged`
Also some constants and variables for intersection devices modeling and control organization.

#### 3.1. OnBeforeChildrenInitializing  
Called cyclically by engine in `INITIALIZING` operational state. Initializes internal timers and bind devices to hardware (I/O terminal) models.

#### 3.2. OnBeforeChildrenStopped  
Called cyclicallyd by engine in `STOPPED` operational state. Turns off all traffic lights.

#### 3.3. OnBeforeChildrenWorking  
Called cyclicallyd by engine in `WORKING` operational state. Implements core traffic light logic.

#### 3.4. OnGetExceptionSeverity  
Called automatically by engine to resolve severity for exception. Used to demonstrate exception mechanism.

#### 3.5. OnOperationalStateChanged  
Called automatically by engine after operational state change. Used for internal logic.

---

## 4. Implement I/O model: `Terminals`

This class contain model of physical equipment:
#### 4.1. DI_1 - digital output termial (EL1018).  
#### 4.2. DO_2 - digital input terminal (EL2409).
#### 4.3. AI_3 - analog input terminal (EL3001).

---

## 5. Visualization elements (optional)

#### 5.1. TrafficLight - control to represent single traffic light
#### 6.2. Intersection - control to represent whole intersection

---

## 6. MAIN Program Setup

In the `MAIN` program:
- Create instance of `IntersectionController` 
- Create instance of `AutomationRunner`
- Create array of `IAutomationComponent` and assign 'IntersectionController' instance to it
- Call `Runner.Execute(_AutomationControllers);` where `Runner` is instance of `IntersectionController` and `_AutomationControllers` is array of `IAutomationComponent`.

---

## Conclusion

That’s all you need. Everything is straightforward once you understand the framework ideology. Visualizations are just auxiliary components for demonstration and verification.
