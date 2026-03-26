# `GENERIC_VALUE` Concept

## 1. General Description

Using `GENERIC_VALUE`, you can store data of any type along with additional metadata, such as the type class and memory management rules.

It is similar to `__SYSTEM.AnyType`, but addresses its shortcomings:
1) Eliminates duplication of type classes: for example, `__SYSTEM.TYPE_CLASS.TYPE_WORD` is the same as `__SYSTEM.TYPE_CLASS.TYPE_UINT`;
2) Provides clearer naming: instead of `__SYSTEM.TYPE_CLASS.TYPE_UINT`, you get `GENERIC_TYPE_CLASS.UINT_16`;
3) Adds additional, highly useful type classes: for example, `GENERIC_TYPE_CLASS.OBJECT`;
4) Preserves memory management rules for the stored value.

## 2. Important Notes

1. This is a class, not a structure: a class consumes more memory, but provides capabilities that a structure cannot offer.

2. Contains multiple methods to retrieve the value in a typed form. Example: `AsInt`, `AsBool`, `AsObject`.

3. Typed access methods attempt type conversion when possible. For example, if you store a value of type `INT`, the `AsDint` method will return the original value cast to `DINT`.

4. Provides the `AsAnyType` method, which converts `GENERIC_VALUE` to the standard `__SYSTEM.AnyType`.

5. Provides the `CopyTo` method, which allows copying the value to another memory location.

6. Provides the `Reset` method, which resets metadata to default values. No operations are performed on the memory allocated for the data.

7. Provides the `Release` method, which frees dynamically allocated memory according to the memory management rules and then calls `Reset`.

8. Provides a set of methods for changing the value: `ChangeValueByAny`, `ChangeValueByAnyType`, `TryChangeValueByAny`, `TryChangeValueByAnyType`.

9. Use the static class `GenericValueFactory` to create an instance of `GENERIC_VALUE`.

10. Methods whose names do not start with `Try` may throw exceptions, so they should be called within `__TRY -> __CATCH`.

11. Methods whose names start with `Try` never throw exceptions.

## 3. `GenericValueFactory`

1. This is a static class (program) intended for creating `GENERIC_VALUE` instances from values of specific types.

2. `FromXxxValue` methods always clone the original value and make `GENERIC_VALUE` responsible for freeing the memory.

3. `FromXxxReference` methods always store a reference (address) to the original value and do not make `GENERIC_VALUE` responsible for memory deallocation.

4. `FromAny` and `FromAnyType` methods create `GENERIC_VALUE` from `ANY` and `__SYSTEM.AnyType`.

5. The `FromParts` method allows you to manually construct any `GENERIC_VALUE`.

## 4. Usage

Designed for use in classes that operate on multiple data types. A typical example of such classes is collections.
