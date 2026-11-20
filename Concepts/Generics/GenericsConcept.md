# `GENERIC_VALUE` Concept (`TOF_Core`)

## 1. General Description

`GENERIC_VALUE` is a small wrapper (a data function block, not extending `Object`) that points to any PLC value and tracks four things: its memory `Address`, byte `Size`, clean type category (`TypeClass : GENERIC_TYPE_CLASS`), and whether this wrapper owns and must free that memory (`IsMemoryOwner : BOOL`), plus `IsNull`.

It improves on TwinCAT's built-in `__SYSTEM.AnyType` by:
1. Combining duplicate type names into clean categories (for example, `UINT_16` instead of overlapping aliases).
2. Covering 25 well-defined categories in `GENERIC_TYPE_CLASS` (`UNSPECIFIED`, `BOOLEAN`, signed/unsigned 8/16/32/64-bit integers, `REAL_32`, `REAL_64`, `STRING_8`, `STRING_16`, 32/64-bit `TIME`/`DATE`/`DATE_AND_TIME`/`TIME_OF_DAY`, `POINTER_TO`, `USER_DEFINED`, `OBJECT`).
3. Tracking memory ownership (`IsMemoryOwner`) so collections and variables know when to free memory automatically.

`STRING_8` represents IEC `STRING` with 8-bit code units. `STRING_16` represents IEC `WSTRING` with 16-bit code units.
These tags describe the storage representation. Text conversions use the encoding documented by the corresponding operation.

---

## 2. Operations, Comparison & Ownership Notes

1. **Wrapper vs. Stored Data**: Assigning one `GENERIC_VALUE` to another copies only the wrapper fields (`Address`, `Size`, `TypeClass`, `IsMemoryOwner`) — **not** the actual data in memory. If the wrapper points to one of your variables (`IsMemoryOwner = FALSE`), keep that variable alive while the wrapper is used.
2. **Reading Typed Values (`As*`)**: Provides `AsBool`, `AsSInt`/`AsInt`/`AsDInt`/`AsLInt`, `AsUSInt`/`AsUInt`/`AsUDInt`/`AsULInt`, `AsByte`/`AsWord`/`AsDWord`/`AsLWord`, `AsReal`/`AsLReal`, `AsString255`/`AsStringReference`, `AsWString255`/`AsWStringReference`, `AsTime`/`AsLTime`/`AsDate`/`AsLDate`/`AsDateAndTime`/`AsLDateAndTime`/`AsTimeOfDay`/`AsLTimeOfDay`, `AsObject`, `AsIObject`, and `AsAnyType`. Converting a number to a smaller integer type checks that the number fits without losing data unless you pass `allowTypeCastWithDataLoss := TRUE`.
3. **Comparing & Hashing Values (`Equals`, `GetHashCode`, `CompareTo`)**:
   * `Equals` and `GetHashCode` take an optional custom `IEqualityComparer`, respect the type category, treat floating-point `NaN` ("not a number") and `+0.0`/`-0.0` consistently, and ask `OBJECT` values to compare themselves via `IObject.Equals` / `GetHashCode`.
   * `CompareTo` sorts all `NaN` values first (equal to each other), compares integer and floating-point numbers accurately without rounding errors, compares full strings even beyond 255 characters, and uses `IComparable` for `OBJECT` values.
   * `IsConvertibleTo` checks whether two `TypeClass` categories can convert at all, without looking at the actual value or memory.
4. **Copying, Updating & Freeing Memory**:
   * `CopyTo` / `TryCopyTo` copies the underlying value into another `GENERIC_VALUE`; `ChangeValueByAny*` / `TryChangeValueByAny*` overwrites the stored value.
   * `Reset` clears the wrapper fields back to defaults **without** freeing any memory.
   * `Release` frees owned dynamic memory when `IsMemoryOwner` is `TRUE` (calling `FB_exit` on `Object` instances when needed) and then calls `Reset`.
5. **Errors & Running Out of Memory**:
   * Regular methods (without `Try`) may throw exceptions such as `GenericConversionNotSupportedException` or `ArgumentOutOfRangeException`. Wrap them in `__TRY -> __CATCH` if you want to handle those errors.
   * `Try*` methods never throw — they catch errors and return `FALSE`. If dynamic memory runs out, they respect the global out-of-memory flag (`DynamicMemoryManager.HasAllocationFailed`) without clearing it and still return `FALSE` (the end-of-cycle `RaiseIfAllocationFailed()` check stops the task safely).

---

## 3. `GenericValueFactory`

`GenericValueFactory` is a helper `PROGRAM` for creating `GENERIC_VALUE` wrappers with a chosen `GENERIC_MEMORY_MANAGEMENT_BEHAVIOR` (point to your variable, copy into new dynamic memory, or take ownership of existing memory):

1. **`FromXxxValue` methods**: Copy your value into new managed dynamic memory and return a wrapper with `IsMemoryOwner := TRUE`. To copy an `OBJECT`, it must implement `ICloneable`; plain data is copied byte-by-byte. (Do not store temporary `Exception` objects in user-managed collections.)
2. **`FromXxxReference` methods**: Create a wrapper pointing directly to your variable (`Address`) with `IsMemoryOwner := FALSE` — you still own that variable and must keep it alive.
3. **`FromAny` and `FromAnyType`**: Create a `GENERIC_VALUE` from `ANY` or `__SYSTEM.AnyType` with the chosen `GENERIC_MEMORY_MANAGEMENT_BEHAVIOR`. `ENUM` and `SUBRANGE` types are handled as unsigned integers of the same byte size.
4. **`FromParts`**: Builds a `GENERIC_VALUE` directly from `TypeClass`, `Address`, `Size`, and `memoryManagementBehavior`.

---

## 4. Usage

Designed for generic containers (`TwinCAT.OpenFramework.Collections`), value comparers (`TwinCAT.OpenFramework.Comparison`), and dynamic variable/condition scopes (`TwinCAT.OpenFramework.Workflow`).
