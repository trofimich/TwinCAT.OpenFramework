![TwinCAT Open Framework](Icons/Icon_128.png)

# TwinCAT.OpenFramework

**A structured application framework for TwinCAT (IEC 61131-3)**

TwinCAT.OpenFramework is a modular framework that introduces architecture, execution model, and reusable libraries for building scalable PLC applications.

It brings structured software engineering practices into the TwinCAT ecosystem.

More technical description you can find [here](TECHNICAL_DESCRIPTION.md)

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
