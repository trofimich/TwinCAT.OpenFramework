![TwinCAT OpenFramework](Icons/Icon_128.png)

# TwinCAT.OpenFramework

TwinCAT.OpenFramework is a set of Structured Text libraries for Beckhoff PLCs running TwinCAT 3.1 Build 4026.
You can use them to organize machine logic, run work across PLC cycles, handle errors, and test code on the PLC.
The libraries also cover everyday tasks such as building strings, storing lists of values, and reading files.

## Getting started

- **Find an API for your task.** Start with [Choosing APIs](Guides/ChoosingAPIs.md).
  For example, the guide shows how to build a diagnostic message, scale an analog input, or run two tasks in order.
  Each entry explains when to use the API and links to its declaration or an example.
  Use the guide from the same tag or commit as your libraries.
- **Try a first example.** Open the [TwinCAT solution](Sources/TwinCAT.OpenFramework.sln) and find the HowTo project.
  Its first example tests that adding 2 and 3 gives 5. Follow the [HowTo instructions](Sources/TwinCAT.OpenFramework.HowTo/README.md)
  to see the result in Watch or choose another example.
- **Explore a complete machine example.** The [traffic light demo](Guides/SignalControlledIntersectionDemo.md)
  shows how a controller and its components work together.

## Guides by topic

| I want to... | Read |
| --- | --- |
| Organize a machine into components that run each PLC cycle | [Automation architecture](Concepts/AutomationEngine/AutomationEngine.md) |
| Build a recipe from steps, conditions, and loops | [Workflow construction](Guides/WorkflowConstruction.md) |
| Handle an exception and keep its details for later | [Exception handling](Concepts/Exceptions/ExceptionsConcept.md) |
| Handle exceptions in a PLC task without `AutomationRunner` | [Complete example with end-of-cycle cleanup](Concepts/Exceptions/ExceptionsConcept.md#5-example-without-automationrunner) |
| Choose a collection and understand how it stores values | [Collections](Concepts/Collections/CollectionsConcept.md) and [generic values](Concepts/Generics/GenericsConcept.md) |
| Map EtherCAT terminal data to PLC variables | [I/O models and supported layouts](Guides/IOModels.md) |
| Prepare file operations for an online change | [File system guide](Guides/FileSystemOnlineChange.md) |
| Use JSON and EventLogger objects in PLC tasks | [Task ownership guide](Guides/JsonAndEventLoggerOwnership.md) |
| Write a PLC test and report its result as JUnit XML | [Testing library guide](Sources/TwinCAT.OpenFramework.Testing/README.md) |

For a list of libraries and their features, see the [technical overview](TECHNICAL_DESCRIPTION.md).

## Using a coding agent in your own project

Copy the instructions below into `AGENTS.md` at the root of your application repository, or into the project
instructions file your agent reads. Replace `<revision>` with the framework tag or commit that matches your libraries.
For offline use, link to the guide in a local copy the agent can read. Update the link when you upgrade.

```markdown
Use ordinary Structured Text for assignments, arithmetic, branches, and loops.
For application tasks, consult the [OpenFramework API selection guide](https://github.com/trofimich/TwinCAT.OpenFramework/blob/<revision>/Guides/ChoosingAPIs.md).
First check the OpenFramework libraries this PLC project already references. If their APIs do not fit the task,
check the standard TwinCAT and Beckhoff libraries before writing your own reusable code.
Treat adding a library as a separate decision.
```

Licensed under the [MIT License](LICENSE.txt).
