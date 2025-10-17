# Phase 0 Baseline Coverage & Metrics (2025-09-27)

## Test Suite Summary
- Total tests passing: 112
- Skipped: 1 (tag-driven)
- Result: All tests passed (post instrumentation & parity canary addition)
- Command: `flutter test --coverage --disable-dds`
- Duration: ~2h23m wall clock (on Windows environment with verbose debug output)

## Coverage Overview
| Metric | Value |
|--------|-------|
| Lines Covered | 1502 |
| Lines Found | 2151 |
| Line Coverage % | 69.83% |

Raw source: `coverage/lcov.info` (generated 2025-09-27).  
Computation: Count of DA: lines with hit>0 divided by total DA lines.

### Notes
- This is a baseline pre-Phase1 (Reliability & Concurrency Hardening) refactor.
- Instrumentation added in Phase 0 does not yet include export tests; metrics remain in-memory only.
- Future increases expected once additional orchestrator pathways and error branches are test-covered.

## Newly Introduced Metrics (Phase 0)
Counters:
- `alarm.event` – Event alarms emitted (per index)
- `alarm.triggered` – Total alarms (all types) fired via orchestrator `_fire()` path
- `alarm.legacy.triggered` – Legacy destination alarm fires (monolith path)
- `location.updates` – Location stream updates processed

Durations (aggregated total nanoseconds + count):
- `orchestrator.update` – Per update() evaluation cycle
- `alarm.legacy.check` – Legacy `_checkAndTriggerAlarm()` evaluation duration
- `location.pipeline` – Time from receipt of a location update through processing pipeline

### Metric Interpretation Guidance
- Compare `alarm.triggered` vs `alarm.legacy.triggered` during dual-run windows to confirm no double-firing.
- Track ratio of `location.pipeline` cumulative time / wall-clock to watch for processing drift as complexity grows.
- `orchestrator.update` p95 (future enhancement) should remain comfortably below location update cadence budget.

## Parity Sentinel
File: `test/parity_canary_test.dart`  
Ensures existence of: distance, time, and stops parity test suites. Fails fast if any renamed/removed.

## Acceptance Criteria (Phase 0) Verification
- [x] Metrics scaffolding present (`lib/services/metrics/metrics.dart`)
- [x] Instrumentation: orchestrator, legacy alarm, location pipeline
- [x] Parity canary test added & passing
- [x] Full suite green after changes
- [x] Coverage baseline captured & documented

## Risks & Follow-Up
- Coverage (<70%) leaves room to mask regressions in edge-case branches (notably persistence & concurrency).
- Add focused tests around: alarm dwell gating edge transitions, reroute hysteresis timing, failure paths of OfflineCoordinator.
- Plan Phase 1 to introduce metrics snapshot export hook for automated periodic diffing.

---
Baseline locked. Changes in subsequent phases should reference this document when asserting "no regression" in coverage or alarm parity.
