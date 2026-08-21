# Agent Guidelines for Dashboard Project

This project adheres to the official **Flutter AI Developer Experience** standards.

## Working with this Codebase
1. **Spec First**: Before implementing features, consult or document requirements under `plans/`.
2. **Quality Gate**: Always execute `dart analyze` and `flutter test` after writing code.
3. **Layer Isolation**:
   - `lib/core/`: Shared theme, constants, network client, and encryption utilities.
   - `lib/<feature>/presentation/`: Stateless and Stateful widgets only.
   - `lib/<feature>/models/`: Structured data models with serializations.
   - `lib/<feature>/services/`: Async business and API service layers.
