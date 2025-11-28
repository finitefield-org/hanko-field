# Linting, formatting, CI, and coverage

## Commands (local and CI)
- Format: `flutter format lib test`
- Static analysis: `flutter analyze`
- Tests with coverage: `flutter test --coverage --reporter compact`
- Coverage threshold: fail CI if line coverage < 80% (filter generated files).

## Analyzer configuration
- Uses `app/analysis_options.yaml` with:
  - strict inference/raw types
  - package imports enforced
  - const/final preference, ordering, unawaited futures
  - public member docs required for shared APIs
- Avoid `// ignore_for_file` except in generated bindings.

## CI pipeline outline
- Steps:
  1) `flutter pub get`
  2) `flutter format --set-exit-if-changed lib test`
  3) `flutter analyze`
  4) `flutter test --coverage`
  5) (optional) coverage gate: parse `coverage/lcov.info` and ensure ≥80% line coverage
- Cache `.pub-cache` and build artifacts between runs when possible.
- For flavors, tests/analyze run once (flavor-agnostic). Flavor builds handled in release jobs.

## Notes
- Document new public APIs to satisfy `public_member_api_docs`.
- Prefer fixing lints over suppressing; if suppressing, add a comment explaining why.
- Keep generated files out of coverage by adding them to `lcov` exclusions in CI script if needed.*** End Patch
