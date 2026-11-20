# Making OpenFramework easier to use for engineers and AI

- [ ] **Make `Core.Strings` reliable for UTF-8.** Preserve complete code points during truncation and trimming. Verify text at logging and serialization boundaries and fix confirmed encoding losses in the affected adapters.

- [ ] **Explain where to start in the README.** Give three examples. Use `Automation` for a permanent part of the machine, such as a traffic light. Show `Tasks` for an operation that takes several PLC cycles, such as reading a file. Show `Workflow` for a sequence of steps defined by a recipe. Link to the relevant code for each example.

- [ ] **Show how a command reaches an output.** At the start of the intersection guide, answer three questions. What calls `TrySetLight`? Where does the code check whether the color change is allowed? Where in the PLC cycle does the code write to the bound output variable? Give the file and method for each answer so readers can follow the code. [Intersection guide](Guides/SignalControlledIntersectionDemo.md)

- [ ] **Check that the caller can see why a command was refused.** In the intersection example, write a test where the permission check refuses a request to turn on the green light. Check that the caller receives `FALSE` and the reason, and that the outputs keep their previous values. This applies to refusal at the permission check. If a fault occurs during switching, some outputs may already have changed.

- [ ] **Give an AI assistant a small task using a clean copy of the public repository.** Ask it to add an indicator for flashing yellow mode to the intersection example and write a test for it. In TwinCAT, confirm that the project builds and that the test checks the output when entering and leaving the mode. If the assistant needs extra guidance, add it where the next engineer would look for it.
