![TwinCAT Open Framework](Icons/Icon_128.png)

# TwinCAT.OpenFramework

**A structured application framework for TwinCAT (IEC 61131-3)**

TwinCAT.OpenFramework is a modular framework that introduces architecture, execution model, and reusable libraries for building scalable PLC applications.

It brings structured software engineering practices into the TwinCAT ecosystem.

More technical descrition you can find [here]

---

## 🚨 The Problem

As TwinCAT projects grow, they often become:

* Hard to maintain and extend
* Tightly coupled
* Filled with repetitive patterns
* Lacking clear architectural boundaries

Typical PLC code mixes:

* execution flow
* business logic
* error handling

This leads to:

* fragile systems
* slow development
* high cost of change

---

## 💡 The Solution

TwinCAT.OpenFramework provides a **unified platform** for PLC development, similar in spirit to modern software frameworks.

Instead of ad-hoc code, you get:

* A structured execution model
* A consistent programming model
* A reusable foundation library

---

## 🧱 Architecture

The framework is built around three main layers:

---

### 1. Execution Layer

Defines how your application runs.

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
* Full list you can find [here]

This layer reduces boilerplate and standardizes common operations.

---

## 🔥 What You Gain

* 📐 Clear and scalable architecture
* 🔁 Reusable components
* 🧠 Easier reasoning about program flow
* 📉 Less repetitive code
* ⚡ Faster development in medium and large projects

---

## 🚀 Example

```
__TRY
    controller.Execute();
__CATCH(errorCode)
    exception := TOF_Core.ExceptionManager.GetLastException(errorCode);
    TOF_Core.LogManager.TryLogException(exception);
__ENDTRY
```

---

## 📌 Use Cases

* Medium and large TwinCAT projects
* Complex automation systems
* Long-lifecycle industrial applications
* Teams that need maintainable code

---

## ⚠️ Trade-offs

* Requires learning new concepts
* Adds abstraction layer
* May be unnecessary for small/simple projects

---

## 🧭 Philosophy

TwinCAT.OpenFramework treats PLC development as **software engineering**, not just control scripting.

It encourages:

* separation of concerns
* structured execution
* reusable design

---

## 📚 Detailed concepts overview

* [Exception Handling](Concepts/Exceptions/ExceptionsConcept.md)
* [Automation Engine](Concepts/AutomationEngine/AutomationEngine.md)
* [Collections and Utilities](Concepts/Collections/CollectionsConcept.md)

---

## 🤝 Contributing

Contributions, ideas, and feedback are welcome.

---

## ⭐ Support

If this project is useful:

* Star the repository
* Share it
* Use it in your projects

---

## 📫 Contact

Open an issue or reach out via GitHub.
