![TwinCAT Open Framework](Icons/Icon_128.png)

# TwinCAT.OpenFramework

**A structured application framework for TwinCAT 3.1 (Build 4026+, IEC 61131-3)** — an architectural foundation and extended standard library that brings modern software engineering practices to Beckhoff PLCs, providing deterministic machine modeling, workflow orchestration, dynamic/static collections, structured exceptions, and native PLC testing.

Licensed under the [MIT License](LICENSE.txt).

### Why use this framework?

1. **Organized Utility Classes:** Replaces scattered standard functions with logically grouped static methods (e.g., `TOF_Core.Strings` providing `.GetLength()`, `.Concat255()`, `.ConcatFit255()`, `.Append()`, `.ReplaceInSource()`, `.CreateSplitter()`, `.Join()`, `.TrimChars()`).
2. **Advanced Data Structures:** Provides both fixed-capacity static and heap-backed dynamic collections (`List`, `ByteList`, `Dictionary`, `UniqueDataSet`, `Queue`, `Stack`) with unified `GENERIC_VALUE` descriptors and ownership guards.
3. **Structured Exception Handling:** Adds detailed error messages, call-site info, timestamps, and modular logging on top of TwinCAT's `__TRY / __CATCH`. Use normal return values for expected cases (like a missing item or a `Try` method returning `FALSE`), and reserve exceptions for real errors. See [when to use exceptions](Concepts/Exceptions/ExceptionsConcept.md#when-to-use-exceptions).
4. **Unified Interfaces:** Provides standard interfaces and ready-to-use implementations for logging (`ILogger`), action permissions (`IActionPermissionPolicy`), events (`IEvent`), configuration serialization (`IConfigurationSerializable`), IO terminal process-image models (`TOF_IOModels`), and field devices (`TOF_Devices_IO`).
5. **Standardized Machine Modeling & Workflow Orchestration:** Offers a deterministic hierarchy (`AutomationRunner` → `AutomationController` → `CompositeAutomationComponent` → `LeafAutomationComponent`) for fixed machine hardware alongside a dynamic `Workflow` engine for external/JSON-configured recipes.
6. **Native PLC Testing:** Includes `TwinCAT.OpenFramework.Testing` with fluent typed assertions, cycle-bounded tests, and ADS/JUnit XML reporting.
7. **Full Technical Overview:** See [TECHNICAL_DESCRIPTION.md](TECHNICAL_DESCRIPTION.md).

---

## 🚨 The Problem

As TwinCAT projects grow, they often evolve into implicit state machines with scattered error handling. They become:

* Hard to maintain and extend
* Tightly coupled
* Filled with repetitive patterns
* Lacking clear architectural boundaries

Typical PLC code mixes execution flow, business logic, and error handling. This leads to:

* Fragile systems
* Slow development
* High cost of change and maintenance

---

## 💡 The Solution

TwinCAT.OpenFramework provides a **unified platform** for PLC development, similar in spirit to modern IT software frameworks.

Instead of ad-hoc code, you get:

* A structured execution model
* A consistent programming model
* A modular, reusable foundation library

---

## 🧱 Architecture

The framework is built around three main layers:

- Execution Layer → "runtime"
- Programming Model → "language extensions"
- Foundation Library → "standard library"

### 1. Execution Layer

Defines a predictable and explicit execution model, replacing ad-hoc control flow typical for PLC applications:

* `AutomationRunner` (top-level root scheduler and per-task runtime boundary)
* `AutomationController` / `CompositeAutomationComponent` / `LeafAutomationComponent`
* Cooperative `Task` / `TaskQueue` / `Timer` state machines
* `Workflow` orchestration engine for dynamic scenarios

This layer separates **how code runs** from **what it does**.

### 2. Programming Model

Defines how you write logic:

* Exception-like error handling (`__TRY / __CATCH`) with `TOF_Core.Exceptions`
* Saved error details (`ERROR` and `ERROR_MESSAGE`) that stay valid across PLC cycles even after the original exception is cleaned up
* Base abstractions (`Object`, `GENERIC_VALUE`, policies, events, permissions)

### 3. Foundation Library

Provides reusable low-level components:

* Collections (`List`, `ByteList`, `Dictionary`, `UniqueDataSet`, `Queue`, `Stack`) and `Comparison`
* String, wide-string, math, bit, and date/time utilities
* Task-local `LogManager`, `AdsLogger`, `EventLogger`, `SimpleTextFileLogger`, `QueuedLogger`
* Asynchronous `FileSystem`, `JSON` serialization, EtherCAT `IO.Models`, `Devices.IO`, and `Testing`
* Full list in [TECHNICAL_DESCRIPTION.md](TECHNICAL_DESCRIPTION.md)

---

## 🔥 What You Gain

* 📐 **Clear and scalable architecture**
* 🔁 **Reusable components** (write once, use across projects)
* 📉 **Lower maintenance costs** (less repetitive code, faster commissioning)
* 🤝 **Easier onboarding** (standardized OOP approaches help new developers join faster)
* ⚡ **Faster development** for medium and large projects

---

## 🚀 Example: Structured Error Handling

When using `AutomationRunner.Execute()`, the runner automatically updates system time, services the task's logger, checks for out-of-memory errors, and cleans up exceptions at the end of every cycle. For standalone code without `AutomationRunner`, wrap operations in `__TRY / __CATCH`:

```iecst
__TRY
    controller.Execute();
__CATCH(errorCode)
    exception := TOF_Core.ExceptionManager.GetLastException(
        exceptionCode := errorCode,
        catchPointNamespaceName := CurrentNamespace.Name, // constant with name of your project namespace
        catchPointPOUName := __POUNAME(),
        catchPointPosition := __POSITION()
    );
    TOF_Core.LogManager.TryLogException(
        exception := exception,
        severity := TOF_Core.ERROR_SEVERITY.ERROR
    );
__ENDTRY
```

See [Concepts/Exceptions/ExceptionsConcept.md](Concepts/Exceptions/ExceptionsConcept.md#5-example-without-automationrunner) for the required end-of-cycle cleanup steps (`RaiseIfAllocationFailed`, `ExceptionManager.Cleanup`, and `DynamicMemoryManager.CleanupMemory`).

---

## 📚 Documentation Map

### Architecture & Concepts
* [Technical Capabilities & Library Overview](TECHNICAL_DESCRIPTION.md)
* [Automation Architecture Concept](Concepts/AutomationEngine/AutomationEngine.md)
* [Exception Handling Concept](Concepts/Exceptions/ExceptionsConcept.md)
* [Collections Concept](Concepts/Collections/CollectionsConcept.md)
* [Generic Values (`GENERIC_VALUE`) Concept](Concepts/Generics/GenericsConcept.md)

### Guides & Examples
* [Signal-Controlled Intersection Demo](Guides/SignalControlledIntersectionDemo.md)
* [Building & Loading Dynamic Workflows](Guides/WorkflowConstruction.md)
* [IO Models: Mapping & Supported Process Images](Guides/IOModels.md)
* [FileSystem: Preparing for Online Change](Guides/FileSystemOnlineChange.md)
* [JSON & EventLogger: Task Ownership](Guides/JsonAndEventLoggerOwnership.md)
* [Testing Library Guide](Sources/TwinCAT.OpenFramework.Testing/README.md)
