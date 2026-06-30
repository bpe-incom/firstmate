# .NET / F# conventions

- Do NOT add XML doc comments (`/// <summary>` ...) to functions, types, members, or modules. This holds even for public API unless the captain explicitly asks.
- Prefer F# idioms: pipelines (`|>`), expression-bodied members, immutable bindings, exhaustive pattern matches over conditionals.
- Keep modules small and composable; avoid premature abstraction.
- (Replace this file with the captain's actual house style — it is only a starting point.)
