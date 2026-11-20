# Collections Concept

## 1. General Description

Collections are abstract data types that allow you to store, organize, and manipulate a group of objects as a single entity.

## 2. Built-in Language Options

The StructuredText language provides two basic ways to work with collections:
1. Arrays  
2. Pointers  

Both approaches have significant limitations. The `TwinCAT_OpenFramework_Collections` module is designed to overcome these limitations and provide a safer and more convenient way to work with collections.

## 3. Limitations of Arrays and Pointers

1. Arrays have a fixed size and are not suitable when the amount of data is unknown in advance.  
2. Pointers allow working with both static and dynamic data, but type safety and memory management are entirely the developer’s responsibility.  
3. Pointer misuse can easily lead to controller crashes or system instability.  
4. Manual memory management often leads to memory leaks, which can eventually stop the controller.  
5. Implementing collection classes manually is complex and time-consuming.  
6. Arrays and pointers do not provide common insertion, equality-search or disposal policies.  

## 4. Standard Library Solutions

Some standard libraries provide basic collection-like structures, such as:
- `Tc2_Utilities.FB_MemRingBuffer`  
- `Tc2_Utilities.FB_HashTableCtrl`  

These building blocks expose their own storage and API contracts; callers must manage the required buffers and lifetimes.

## 5. What `TwinCAT_OpenFramework_Collections` Provides

The framework provides ByteList, List, Dictionary, UniqueDataSet, Queue and Stack.

All collections are universal and store values using the `GENERIC_VALUE` type (except ByteList). 

`GENERIC_VALUE` concept described [here.](../Generics/GenericsConcept.md)

## 6. Static and Dynamic Collections

Collections can be either static or dynamic:

- A collection is **static** if the `VAR_GENERIC CONSTANT` parameter is greater than zero.  
- A collection is **dynamic** if the `VAR_GENERIC CONSTANT` parameter is set to zero.  

The maximum number of elements a collection can hold is available via the `Capacity` property.  
The actual number of stored elements is available via the `Length` property.

- For static collections, `Capacity` is defined at declaration time.  
- For dynamic collections, `Capacity` grows as needed.  

## 7. Key Features

- Each element is stored as a `GENERIC_VALUE` (except `ByteList`).  
- A single collection can store values of different types.  
- Custom validation rules can be applied using `TOF_Core.IGenericValueValidator`.  
- Memory management can be delegated to the collection, allowing automatic cleanup when elements are removed.  
- All collections implement the `IEnumerable` interface, enabling iteration using a `WHILE` loop.  

## 8. Supported Collection Types

### 8.1. ByteList
A collection optimized for working with bytes.  
Supports: add (various), clear, replace (various), remove, search, get by index.

### 8.2. List
A collection of `GENERIC_VALUE`.  
Supports: add, clear, replace, insert, remove, search, get by index, sort.

### 8.3. Dictionary
A key-value collection where both key and value are `GENERIC_VALUE`.  
Keys are unique.  
Supports: assign, clear, remove, search by key, get value or index by key, get by index.

### 8.4. UniqueDataSet
A collection of unique `GENERIC_VALUE` items.  
Supports: assign, clear, remove, search, get by index.

### 8.5. Queue
A FIFO (first-in, first-out) collection of `GENERIC_VALUE`.  
Supports standard queue operations such as enqueue, peek, remove first and clear.

### 8.6. Stack
A LIFO (last-in, first-out) collection of `GENERIC_VALUE`.
Index zero and enumeration start at the top. Push adds a value; Peek borrows the top;
RemoveLast destroys the stored entry without transferring ownership to the caller.

## 9. Ownership and borrowed views

* **Copying (`Copy`):** Creates independent copies of stored elements. To copy an `OBJECT`, it must implement `ICloneable`. Ordinary structures are copied byte-by-byte, so pointer or interface fields inside them are not cloned deeply.
* **Transferring ownership on insert:** Passing an owning `GENERIC_VALUE` (`IsMemoryOwner = TRUE`) to a generic insertion method transfers memory ownership to the collection when insertion succeeds. Call `Reset()` on your local descriptor afterward so you do not release it a second time. If insertion fails before adding the item, you remain responsible for releasing it.
* **Reading (`Get`, `Peek`, `FindSingle`, `TryGet`, `Current`):** These return borrowed views — the collection still owns the stored element. Even if the returned descriptor has `IsMemoryOwner = TRUE`, do **not** call `Release()` on it. Keep the collection (and any borrowed caller variables stored in it) alive while using a borrowed view, because changing the collection can invalidate it.
* **No accidental copying (`no_assign`):** All six collection function blocks block direct variable-to-variable assignment (`colA := colB`), because a bitwise copy would duplicate internal memory pointers without cloning the elements. Assigning to an interface variable still points to the same collection instance.
* **`Dictionary` & `UniqueDataSet` keys:** `Dictionary` keeps the existing equal key and replaces its value; `UniqueDataSet` replaces the matching item. Neither guarantees sorted order. Do not modify key/element fields that affect equality or hash codes while the item is stored — remove it first, update it, and add it back. Custom comparers are borrowed for the collection's lifetime and must return matching hash codes for equal items.
* **Lookup queries:** In `Dictionary` and `UniqueDataSet`, lookup arguments are borrowed by default and never freed. In `List`, `Queue`, and `Stack`, `ContainsGeneric` frees an owning query descriptor (`IsMemoryOwner = TRUE`) by default — pass the release flag as `FALSE` if you want to keep owning it. Never pass an owning query descriptor that points to memory still used by the collection, and note that releasing inside the call does not reset other local aliases.

## 10. Sorting

List.Sort uses `GENERIC_VALUE.CompareTo` when the comparer is omitted or zero. This default
supports the Core natural order for compatible numeric, text, temporal and OBJECT values.
Mixed numeric widths and STRING/WSTRING pairs do not require choosing a typed comparer.
OBJECT values require `IComparable`; unsupported pairs raise `GenericConversionNotSupportedException`.
An explicitly supplied comparer takes precedence and defines its own supported representations.

Empty and singleton lists return without comparing. Comparison failure can leave the order
partially changed, while preserving every descriptor and its ownership. A default comparer
is not inferred from the first entry's type.

## 11. Enumeration and failures

* **Enumerators (`CreateEnumerator`):** Creates a standalone cursor owned by the caller. Release it explicitly with `TOF_Core.Memory.TryReleaseDynamicObject` after converting its interface to `IObject`. Keep the collection alive and do not modify it while iterating. `Current` is empty before the first successful `MoveNext`, after `Reset`, and after reaching the end (subsequent `MoveNext` calls return `FALSE` until `Reset`). If an enumerator was created without a source, `FB_init` succeeds without throwing, and calling `MoveNext` or reading `Current` throws `DataMemberNotSpecifiedException`.
* **One task per collection:** Each collection instance must be used by only one PLC task, with no built-in thread locks. Do not modify a collection from inside a user callback while an operation on that collection is running, unless that behavior is explicitly documented as supported.
* **`Try` methods and running out of memory:** `Try` methods catch errors and return `FALSE`. If dynamic memory runs out (`__NEW` fails), `DynamicMemoryManager` sets a global out-of-memory flag; `Try` methods keep that flag set and return `FALSE`. Each PLC task must call `TOF_Core.DynamicMemoryManager.RaiseIfAllocationFailed()` at the end of every cycle outside normal recovery blocks so the program stops safely instead of running on in a broken state (`AutomationRunner` already does this automatically).
* **Static vs. dynamic memory & online change:** Static capacity (`N > 0`) avoids heap allocations when adding items, though `Copy`, `CreateEnumerator`, and exception messages can still allocate memory; dynamic growth fails with an out-of-memory error if memory runs out. `FB_init` never throws or runs validators or comparers. If live `Dictionary` or `UniqueDataSet` instances survive an online change where variable addresses relocate, rebuild hash indices that depend on object addresses.

## 12. Usage

![Dynamic list usage](DynamicListUsage.png)

## 13. Tests

Unit and contract tests for collections live in
`Sources/TwinCAT.OpenFramework.Tests/Tests/Collections/` (including
`Contract/CollectionsContractTest`), covering ownership rules, callback failures,
hash collisions, dynamic growth, and independent enumerators.
