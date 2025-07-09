```markdown

\# Signal-Controlled Intersection Automation – Technical Guide



\## 1. Enumeration Definitions

```



```

1.1. SIGNAL\_CONTROLLED\_INTERSECTION\_MODE – defines the general control mode of the intersection.



1.2. SIGNAL\_CONTROLLED\_INTERSECTION\_STATE – defines the current state of the intersection.

&nbsp;    Based on this state, the logic activates appropriate signals on four traffic lights.

&nbsp;    The values ALL\_YELLOW, \_1\_3\_YELLOW\_AND\_2\_4\_YELLOW, and \_2\_4\_YELLOW\_AND\_1\_3\_YELLOW are similar because

&nbsp;    they turn on yellow on all traffic lights, but they carry additional information to determine

&nbsp;    the next state transition.



1.3. TRAFFIC\_LIGHT\_COLOR – defines the state of a single traffic light.

```



\## 2. Implement the TrafficLight Device



```

The TrafficLight device consists of three standard internal DigitalOutput devices (for red, yellow, and green).

It inherits from the abstract class TOF\_Automation.OutputDevice<3>, indicating that it includes 3 internal subdevices.



Inheritance requires implementation of:

\- three abstract properties: ClassName, Size, SubDevices

\- one abstract method: OnUpdateOutputsFromState



Also implemented: SetLight (custom method).



2.1. ClassName – required by the framework, returns the name of the current class (function block).

&nbsp;    Used for exception reporting.



2.2. Size – used by the framework to manage dynamic memory.



2.3. SubDevices – returns a reference to the array containing actual internal devices

&nbsp;    (digital outputs for turning on the light indicators in this case).



2.4. OnUpdateOutputsFromState – responsible for passing internal virtual device data to terminals or external objects.

&nbsp;    At the traffic light level, this does nothing.

&nbsp;    On the DigitalOutput level, these actions are already implemented in Devices.IO library.



2.5. SetLight – method to control the traffic light by passing a color to activate.

```



\## 3. Implement the Automation Module: SignalControlledIntersectionAutomationUnit



```

This module contains logic for interaction between six devices:

\- ON/OFF input

\- Mode switch (standard vs blinking yellow)

\- Four traffic lights



It inherits from TOF\_AutomationEngine.AutomationUnit<6>.



The class must implement:

\- ClassName

\- Size

\- Devices

\- StartRequest



Additionally, overrides:

\- StopRequest

\- OnInitialize

\- OnStop



3.1. ClassName – see section 2.1.



3.2. Size – see section 2.2.



3.3. Devices – returns a reference to an array filled with real devices

&nbsp;    (2 digital inputs and 4 traffic light instances).



3.4. StartRequest – signals the engine to enter RUN state.

&nbsp;    Simply returns the value of the ON/OFF switch.



3.5. StopRequest – signals the engine to enter STOPPED state.

&nbsp;    Simply returns the inverted value of the ON/OFF switch.



3.6. OnRun – method called by the engine cyclically while in RUN state.

&nbsp;    Contains core traffic light logic.



3.7. OnInitialize – used during initialization phase.

&nbsp;    Returns TRUE once initialization is complete.

&nbsp;    In our case, it sets timer values in one cycle. In other cases, may take several cycles.



3.8. OnStop – called cyclically in STOPPED state. Turns off all traffic lights.

```



\## 4. Implement the Automation Runner: SignalControlledIntersectionAutomationRunner



```

The runner manages automation modules.

In our case, it controls one instance of SignalControlledIntersectionAutomationUnit.

Inherits from TOF\_AutomationEngine.AutomationRunner<1>.



Implements:

\- ClassName (see 2.1)

\- Size (see 2.2)

\- AutomationUnits – returns array of controlled automation units (1 element in our case)

\- FB\_Init – used to enable simulation mode (since this is a demo project without real terminals)

```



\## 5. MAIN Program Setup



```

In the MAIN program:

\- Create instance of SignalControlledIntersectionAutomationRunner

\- Call its Run method

```



\## Conclusion



```

That's all you need.

As you can see, everything is simple – once you understand the framework ideology.

Visualizations are just auxiliary components for demonstration and verification.

```

