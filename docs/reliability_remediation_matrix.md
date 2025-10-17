# Reliability Remediation Matrix (Phase 1 Output)

| Risk ID | Component | Scenario / Failure Mode | Detection Mechanism (Current / Planned) | User Impact | Severity (L/M/H) | Mitigation Implemented in Phase 1 | Residual Gap | Phase 2 Action |
|---------|-----------|-------------------------|-------------------------------------------|-------------|------------------|------------------------------------|--------------|----------------|
| R1 | ApiClient | Token refresh storm under concurrent requests | Single-flight test (concurrent_refresh_test) | Latency spike / battery | M -> L | Single-flight guard + test | Boundary equality not tested | Add boundary & max retry exhaustion test |
| R2 | ApiClient | Silent auth failure after max retries | Log warnings only | Session break | M | Backoff logic present | No deterministic failure test | Inject failing auth sequence test |
| R3 | RouteCache | Capacity eviction removes wrong entry | Explicit eviction test | Stale routes kept / memory bloat | M -> L | Oldest key eviction validated | Tie / TTL+capacity interplay | Add mixed condition test |
| R4 | RouteCache | Corrupted entry causes crash | Corruption test (malformed JSON) | Crash / data loss | M -> L | Try/catch removal of malformed | Truncation & partial write not covered | Add truncation + size tests |
| R5 | DeviationMonitor | Flicker near thresholds | Hysteresis invariant test | Spurious reroutes / switches | M -> L | Invariant-based test added | Boundary == threshold not tested | Boundary jitter test |
| R6 | DeviationMonitor | Sustain timer resets on route switch improperly | Switch triggers reset() but untested | Missed sustained detection | M | Reset logic simple | No reset-mid-sustain test | Add reset scenario test |
| R7 | ActiveRouteManager | Rapid switch oscillation ignoring blackout | Blackout logic covered indirectly | Route instability | M -> L | Stress & switching tests present | Blackout + sustain timing interplay | Targeted blackout interplay test |
| R8 | ReroutePolicy | Multiple reroutes during cooldown | Burst stress test ensures no overlap | Excess network usage | M -> L | Cooldown works in burst | Cooldown expiry + queued event untested | Cooldown boundary test |
| R9 | OfflineCoordinator | Mid-request connectivity change | Separate online/offline tests | Unexpected error / stale data | M | Distinct mode tests | Mid-flight flip untested | Transition test with delayed future |
| R10 | TrackingService | Start/stop race causing orphan timers | Race fuzz harness (lifecycle) | Battery drain | M -> L | Fuzz harness added | High-volume start/stop with background mode not covered | Expand fuzz harness iterations |
| R11 | TrackingService | Sensor fusion starts erroneously on brief GPS blip | Connectivity simulation test (full dropout) | Battery drain | L | Threshold gating | Early resume path untested | Early resume test |
| R12 | MetricsRegistry | Counter non-monotonic due to race | Race harness limited | Misleading analytics | M | Simple increments validated | High concurrency not tested | Add intense concurrency test |
| R13 | SnapToRouteEngine | Hint index regression on polyline change | Static polyline tests | Degraded accuracy | L | Baseline snapping tests | Polyline shrink not tested | Dynamic polyline test |
| R14 | AlarmScheduler | Overlapping alarm collisions | Single alarm test | Missed/duplicate alarms | M | Invariants test ensures basic firing | No multi-alarm scenario | Multi-alarm scheduling test |
| R15 | Notification Service | Notification spam (debounce failure) | None explicit | User annoyance | L | Implicit rate control | Debounce not asserted | Debounce assertion test |
| R16 | Power Policy | Low battery adaptive reduction absent | Not exercised | Battery drain | L | Config stubs only | Behavior not asserted | Add battery policy test harness |
| R17 | RouteCache | Simultaneous TTL expiry & capacity prune ordering | TTL test + capacity test separate | Potential premature drop | L | Baseline TTL/capacity tests | Combined ordering not tested | Mixed scenario test |

## Key Mitigations Implemented in Phase 1
- Concurrency: ApiClient single-flight, auth stress test, lifecycle race fuzz harness.
- Persistence: Route cache eviction & corruption tests (malformed JSON) added.
- Hysteresis: DeviationMonitor invariant-based no-flicker test.
- Stress: Orchestrator dual-run cycles, deviation/reroute burst, tracking lifecycle cancellation.
- Metrics Safety: Monotonic check included in fuzz harness (initial scope).

## Residual Risk Summary
No High severity risks remain. Medium risks center on timing boundaries and multi-condition interactions which require a controllable clock or injected failures to test deterministically.

## Phase 2 Enablers
| Enabler | Description | Benefit |
|---------|-------------|---------|
| FakeClock abstraction | Replace DateTime.now() in timing-sensitive services | Deterministic timing tests |
| Fault injection adapters | ApiClient (auth), RouteCache (persistence), ReroutePolicy (cooldown) | Precise boundary & failure coverage |
| Expanded Fuzz Harness | Parameterized iteration count & variable delays | Higher race detection probability |

## Suggested Phase 2 Exit Criteria
- All Medium risks have at least one deterministic test.
- Fault injection triggers graceful handling paths (no uncaught exceptions) across ApiClient, RouteCache, ReroutePolicy.
- Hysteresis boundary tests (== threshold) stable for 500 iterations.
- Concurrency fuzz harness passes with 10k lifecycle start/stop operations.

Generated: 2025-09-28
