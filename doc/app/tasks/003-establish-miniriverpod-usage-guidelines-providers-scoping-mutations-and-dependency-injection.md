# Establish miniriverpod usage guidelines (providers, mutations/concurrency, scoping) and dependency injection strategy without code generation.

**Parent Section:** 0. Planning & Architecture
**Task ID:** 003

## Goal
Document miniriverpod usage patterns without relying on code generation or `StateProvider`.

## Topics
- Provider categories (global app-level, feature-level, ephemeral UI) and lifecycle management with autoDispose defaults.
- Dependency injection using `Scope`/overrides for testing and environment switching.
- Handling asynchronous state with `AsyncProvider` (`AsyncValue`, `ref.emit` for streams) and custom state classes.
- Mutation patterns (`mutation`, `mutate`, `ref.invoke`) and concurrency options (`concurrent`, `queue`, `restart`, `dropLatest`).
- Error propagation, retry patterns, UI binding guidance, and avoiding circular dependencies or overusing global providers.
