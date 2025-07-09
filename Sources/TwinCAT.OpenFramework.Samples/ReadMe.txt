To automate a signal-controlled intersection, the following steps were implemented:

1. Create the Required Enumerations
	1.1. SIGNAL_CONTROLLED_INTERSECTION_MODE
		Defines the general control mode of the intersection.

	1.2. SIGNAL_CONTROLLED_INTERSECTION_STATE
		Represents the current state of the intersection, which determines which signals should be activated on the four traffic lights.
		States like ALL_YELLOW, _1_3_YELLOW_AND_2_4_YELLOW, and _2_4_YELLOW_AND_1_3_YELLOW are similar in that they activate yellow lights on all traffic lights. 
		However, they contain additional semantic information for determining the next state transition.

	1.3. TRAFFIC_LIGHT_COLOR
		Defines the state (color) of a single traffic light.

2. Implement the TrafficLight device
	This device consists of three internal DigitalOutput devices for each color (red, yellow, green).
	The class inherits from the abstract TOF_Automation.OutputDevice<3>, where <3> indicates the number of internal devices.
	Inheritance enforces the implementation of:
		- three abstract properties: ClassName, Size, and SubDevices;
		- one abstract method: OnUpdateOutputsFromState;
		- a custom method SetLight is implemented.

	2.1. ClassName
		A required property for framework operation that returns the name of the current class (functional block). It is used in exception handling.

	2.2. Size
		A required property used by the framework to manage dynamic memory.

	2.3. SubDevices
		Returns a reference to the array populated with actual internal devices (in this case, the digital outputs controlling the light indicators).

	2.4. OnUpdateOutputsFromState
		This method is intended to propagate internal virtual device states to physical terminals or other external objects.
		At the TrafficLight level, no direct action is performed.
		However, at the DigitalOutput level, actual assignments from internal state to terminal-bound variables occur—this logic is already implemented in the Devices.IO library.

	2.5. SetLight
		A helper method used to control the traffic light. Accepts a color (from the enum) and activates the corresponding internal output.

3. Implement the SignalControlledIntersectionAutomationUnit
	This automation unit encapsulates the logic for interacting with six devices:
		- one ON/OFF switch
		- one mode switch (standard vs. blinking yellow)
		- four traffic lights
	It inherits from TOF_AutomationEngine.AutomationUnit<6>, where <6> represents the number of devices.
	Required implementations:
		abstract properties: ClassName, Size, Devices, StartRequest
		abstract method: OnRun
		overriden property: StopRequest
		overriden methods: OnInitialize, OnStop (default implementations do nothing)

	3.1. ClassName – see 2.1

	3.2. Size – see 2.2

	3.3. Devices
		Returns a reference to the array of actual devices (two digital inputs and four traffic light devices).

	3.4. StartRequest
		A base property that signals the engine to enter operational mode. Returns the state of the ON/OFF switch.

	3.5. StopRequest
		A base property that signals the engine to enter stopped mode. Returns the negated state of the ON/OFF switch.

	3.6. OnRun
		Executed cyclically while the engine is in operational mode. Contains the main logic for controlling the traffic lights.

	3.7. OnInitialize
		Called during the initialization phase. Returns TRUE once initialization is complete.
		In this case, it sets timing values and completes in a single cycle (though in other cases, it may span multiple cycles).

	3.8. OnStop
		Called cyclically when the engine is in stopped mode. Ensures that all traffic lights are turned off.

4. Implement the SignalControlledIntersectionAutomationRunner
	This is the automation engine that manages one or more automation units.
	In this case, it manages a single unit (SignalControlledIntersectionAutomationUnit) and therefore inherits from TOF_AutomationEngine.AutomationRunner<1>.

	In addition to standard properties ClassName and Size (see 2.1 and 2.2), it implements:

	4.1. AutomationUnits
		Returns the array of automation modules managed by the engine. In this case, the array contains a single instance of SignalControlledIntersectionAutomationUnit.

	4.2. FB_Init
		A standard initialization method used to enable simulation mode, since this project is a demonstration and does not use physical terminals.

5. Integrate in MAIN Program
	In the MAIN program:
		- Instantiate SignalControlledIntersectionAutomationRunner
		- Call its Run() method

Summary
	That’s all that is required. As you can see, once you understand the framework's design principles, implementation becomes straightforward.
	The HMI/visualization layer is just an auxiliary component for testing and demonstration purposes.