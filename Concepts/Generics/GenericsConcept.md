# `GENERIC_VALUE` Concept (`TOF_Core`)

## 1. General Description

`GENERIC_VALUE` is a function block data descriptor (not extending `Object`) that pairs a memory `Address` and byte `Size` with a normalized `TypeClass : GENERIC_TYPE_CLASS`, an `IsMemoryOwner : BOOL` flag, and `IsNull`.

It improves upon raw `__SYSTEM.AnyType` by:
1. Eliminating duplicate type classes (for example, collapsing bit-width aliases into explicit categories such as `GENERIC_TYPE_CLASS.UINT_16`).
2. Covering 25 well-defined categories in `GENERIC_TYPE_CLASS` (`UNSPECIFIED`, `BOOLEAN`, signed/unsigned 8/16/32/64-bit integers, `REAL_32`, `REAL_64`, `STRING_ASCII`, `STRING_UTF16`, 32/64-bit `TIME`/`DATE`/`DATE_AND_TIME`/`TIME_OF_DAY`, `POINTER_TO`, `USER_DEFINED`, `OBJECT`).
3. Preserving memory ownership rules (`IsMemoryOwner`) for dynamic values and collections.

---

## 2. Operations, Comparison & Ownership Notes

1. **Descriptor vs. Payload**: Copying a `GENERIC_VALUE` by value copies its metadata fields (`Address`, `Size`, `TypeClass`, `IsMemoryOwner`), not the underlying payload. Keep external borrowed storage alive and stable while used.
2. **Typed Access (`As*`)**: Provides `AsBool`, `AsSInt`/`AsInt`/`AsDInt`/`AsLInt`, `AsUSInt`/`AsUInt`/`AsUDInt`/`AsULInt`, `AsByte`/`AsWord`/`AsDWord`/`AsLWord`, `AsReal`/`AsLReal`, `AsString255`/`AsStringReference`, `AsWString255`/`AsWStringReference`, `AsTime`/`AsLTime`/`AsDate`/`AsLDate`/`AsDateAndTime`/`AsLDateAndTime`/`AsTimeOfDay`/`AsLTimeOfDay`, `AsObject`, `AsIObject`, and `AsAnyType`. Integer narrowing checks actual range unless `allowTypeCastWithDataLoss := TRUE` is specified.
3. **Value Semantics (`Equals`, `GetHashCode`, `CompareTo`)**:
   * `Equals` and `GetHashCode` accept an optional borrowed `IEqualityComparer`, preserve type categories, normalize floating-point `NaN` and signed zero, and delegate non-empty `OBJECT` values to `IObject.Equals` / `GetHashCode`.
   * `CompareTo` places all `NaN` values first (equal to each other), compares mixed integer/floating-point numbers exactly without lossy float rounding, compares full strings beyond 255 characters, and delegates `OBJECT` comparisons to `IComparable`.
   * `IsConvertibleTo` checks static `TypeClass` pair support without reading payload range or lifetime.
4. **Copying, Mutation & Cleanup**:
   * `CopyTo` / `TryCopyTo` copies the payload to another descriptor; `ChangeValueByAny*` / `TryChangeValueByAny*` updates stored values.
   * `Reset` resets metadata fields to defaults without freeing memory.
   * `Release` frees owned dynamically allocated memory when `IsMemoryOwner` is `TRUE` (calling `FB_exit` via `Object` when appropriate) and then calls `Reset`.
5. **Errors & Running Out of Memory**:
   * Regular methods (without `Try`) may throw exceptions such as `GenericConversionNotSupportedException` or `ArgumentOutOfRangeException`. Wrap them in `__TRY -> __CATCH` if you want to handle those errors.
   * `Try*` methods never throw — they catch errors and return `FALSE`. If dynamic memory runs out, they respect the global out-of-memory flag (`DynamicMemoryManager.HasAllocationFailed`) without clearing it and still return `FALSE` (the end-of-cycle `RaiseIfAllocationFailed()` check stops the task safely).

---

## 3. `GenericValueFactory`

`GenericValueFactory` is a static `PROGRAM` for constructing `GENERIC_VALUE` descriptors according to `GENERIC_MEMORY_MANAGEMENT_BEHAVIOR` (borrow, clone, or adopt):

1. **`FromXxxValue` methods**: Clone the original value onto managed storage and return a descriptor with `IsMemoryOwner := TRUE`. Cloning `OBJECT` values requires `ICloneable`; other types are copied as bytes. (Auto-disposed exception objects are unsupported in user-managed collections.)
2. **`FromXxxReference` methods**: Store a borrowed reference (`Address`) to caller storage with `IsMemoryOwner := FALSE`.
3. **`FromAny` and `FromAnyType`**: Build a `GENERIC_VALUE` from `ANY` or `__SYSTEM.AnyType` and a chosen `GENERIC_MEMORY_MANAGEMENT_BEHAVIOR`. `TYPE_ENUM` and `TYPE_SUBRANGE` map to unsigned integers of matching byte width.
4. **`FromParts`**: Explicitly constructs a `GENERIC_VALUE` from `TypeClass`, `Address`, `Size`, and `memoryManagementBehavior`.

---

## 4. Usage

Designed for generic containers (`TwinCAT.OpenFramework.Collections`), value comparers (`TwinCAT.OpenFramework.Comparison`), and dynamic variable/condition scopes (`TwinCAT.OpenFramework.Workflow`).
