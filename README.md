![TwinCAT Open Framework](Icons/Icon_128.png)

# TwinCAT.OpenFramework

**A structured application framework for TwinCAT (IEC 61131-3)** is an architectural template and extended standard library that brings modern software engineering practices to Beckhoff PLCs, providing a standardized way to model hardware machines and eliminating the chaos of scattered utility functions.

### Why use this framework?

1. **Organized Utility Classes:** Replaces scattered standard functions with logically grouped static methods (e.g., a `Strings` program providing `.GetLength()`, `.Concat()`, `.Replace()`, `.Split()`, `.Join()`).
2. **Advanced Data Structures:** Adds crucial missing functionality, such as powerful and easy-to-use dynamic collections.
3. **Exception Handling:** Establishes a robust mechanism for exception handling, error tracking, and system logging.
4. **Unified Interfaces:** Provides standard interfaces and ready-to-use implementations for common services, such as `ILogger`, IO terminal models, devices.
5. **Standardized Machine Modeling:** Offers a unified architectural approach to building a software model of your hardware. It standardizes system initialization, I/O interaction, error handling, and logging across your entire project.
6. **And many more** You can find technical description [here](TECHNICAL_DESCRIPTION.md)

---

## 🚨 The Problem

As TwinCAT projects grow, they often evolve into implicit state machines with scattered error handling. They become:

* Hard to maintain and extend
* Tightly coupled
* Filled with repetitive patterns
* Lacking clear architectural boundaries

Typical PLC code mixes execution flow, business logic, and error handling. This leads to:

* fragile systems
* slow development
* high cost of change and maintenance

---

## 💡 The Solution

TwinCAT.OpenFramework provides a **unified platform** for PLC development, similar in spirit to modern IT software frameworks.

Instead of ad-hoc code, you get:

* A structured execution model
* A consistent programming model
* A reusable foundation library

---
  
## 🧱 Architecture

The framework is built around three main layers:

- Execution Layer → "runtime"
- Programming Model → "language extensions"
- Foundation Library → "standard library"

---

### 1. Execution Layer

Defines a predictable and explicit execution model, replacing ad-hoc control flow typical for PLC applications.

Includes concepts like:

* AutomationRunner
* AutomationController
* Workflow / execution orchestration

This layer separates **how code runs** from **what it does**.

---

### 2. Programming Model

Defines how you write logic.

Includes:

* Exception-like error handling (`__TRY / __CATCH`)
* Result and error models
* Base abstractions and patterns

This layer makes code:

* more predictable
* easier to reason about
* less error-prone

---

### 3. Foundation Library

Provides reusable low-level components.

Includes:

* Collections
* String utilities
* Date & time helpers
* Base types and primitives
* Full list you can find [here](TECHNICAL_DESCRIPTION.md)

This layer reduces boilerplate and standardizes common operations.

---

## 🔥 What You Gain

* 📐 **Clear and scalable architecture**
* 🔁 **Reusable components** (write once, use across projects)
* 📉 **Lower maintenance costs** (less repetitive code, faster commissioning)
* 🤝 **Easier onboarding** (standardized OOP approaches help new developers join faster)
* ⚡ **Faster development** for medium and large projects

---

## 🚀 Example: Structured Error Handling

Instead of unexpected machine stops or untraceable bugs, the framework allows graceful error recovery and structured logging, directly reducing equipment downtime:

```iecst
__TRY
    controller.Execute();
__CATCH(errorCode)
    exception := TOF_Core.ExceptionManager.GetLastException(errorCode);
    TOF_Core.LogManager.TryLogException(exception);
__ENDTRY
