# Define MVVM + miniriverpod architecture conventions (view/widget, view-model, repository layers) and directory structure.

**Parent Section:** 0. Planning & Architecture
**Task ID:** 002

## Goal
Establish MVVM + miniriverpod architecture conventions and directory layout.

## Decisions
- Folder structure (`lib/modules/<feature>/{view,view_model,repository}`, shared layers, test directories).
- Provider base classes (`Provider`, `AsyncProvider`, provider families via `args`/subclass) and naming conventions using miniriverpod.
- Error/loading state modeling (sealed classes or custom state classes) and how view models expose state.
- Mutation patterns (`mutation`, `mutate`, `ref.invoke`) and concurrency policy defaults for view models.
- Repository interfaces vs service clients and how to mock them with `Scope` overrides.

## Deliverables
- Architecture guideline in `doc/app/architecture.md` with diagrams.
- Sample feature scaffold demonstrating conventions.
- Code review checklist enforcing architecture rules.
