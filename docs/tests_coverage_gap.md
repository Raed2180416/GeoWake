# Test Coverage Gap Catalog (Phase 1 Closure)

This document enumerates notable untested or lightly-tested branches / scenarios after Phase 1 reliability hardening. It provides rationale, risk evaluation, and suggested Phase 2 follow‑ups.

| Area | Gap / Untested Branch | Current Mitigation | Risk (L/M/H) | Phase 2 Action |
|------|-----------------------|--------------------|--------------|----------------|
| ApiClient | Max retry exhaustion path with exponential backoff near network flapping; jitter interactions | Single-flight protects token storms; network layer generally stable in tests | M | Add deterministic fake clock & injected failure sequence test validating final error & backoff schedule |
| ApiClient | Early refresh race exactly at boundary (expiresAt - earlyWindow == now) | Concurrency test covers coalescing but not boundary equality | L | Add boundary test forcing clock to equality to confirm single refresh |
| ApiClient | Token corruption (parsing invalid JSON / secure store corruption) | Not simulated; unlikely in pure memory mode | L | Inject malformed persisted token and assert re-auth path triggers |
| RouteCache | Disk write failure / Hive box IO exception during eviction scan | Not simulated (would require mocking Hive backend) | M | Abstract persistence layer & inject faulting adapter for test |
| RouteCache | Simultaneous logical eviction (TTL + capacity) choosing different victims | Capacity test covers oldest selection but not tie with TTL expiry | L | Craft scenario with two stale + one fresh over capacity verifying deterministic victim ordering |
| RouteCache | Large object (> threshold) partial write / truncation; corruption test only covers bad JSON field | Only simple malformed entry removal tested | M | Add size-based corruption simulation (truncate JSON) |
| DeviationMonitor | Extremely rapid oscillation at exactly low/high boundary (== not just > or <) | Current test avoids equality; logic uses strict > and < | L | Add boundary jitter sequence verifying no bounce when == thresholds |
| DeviationMonitor | Reset() mid-sustain then continued deviation | Not covered; tracking service uses reset on route switch | M | Add test: enter deviation, near sustain threshold, call reset, ensure new timing window starts |
| ActiveRouteManager | Blackout window + sustain interplay on immediate re-deviation into previous route | Indirectly covered in switch tests but not targeted | M | Targeted test validating no premature second switch within blackout |
| ReroutePolicy | Cooldown expiration with overlapping sustained deviation events queueing | Only stress burst ensures no duplicates, not queued-after-cooldown scenario | M | Simulate sustained deviation near cooldown expiry and validate single reroute issuance |
| OfflineCoordinator | Transition mid-flight from offline->online while request pending | Online/offline branches separate tests; no runtime transition test | M | Add test with mocked network future delaying, then flip offline flag |
| TrackingService | Background mode re-entry after stopTracking() while timers still pending | Lifecycle cancellation test ensures counters stop, not restart sequence | L | Add test: start->stop->start quickly; assert state resets and no residual metrics increment from stale timers |
| TrackingService | Sensor fusion fallback abort path on early GPS resume (< dropout threshold) | Connectivity test sim covers full dropout, not early resume | L | Add test with resume before threshold to ensure fusion not started |
| SnapToRouteEngine | Hint index regression when route shrinks (removed tail) | Current tests assume static polyline | L | Add dynamic polyline change test ensuring hintIndex clamps |
| Snap Flags | Backtrack + regression simultaneous trigger priority ordering | Only shows absence in normal forward motion | L | Craft path that first triggers regression then backtrack and assert ordering/flag resolution |
| MetricsRegistry | Concurrent increments from multiple async sources (isolate or microtask flood) | Race fuzz harness minimal injection | M | Add stress test pumping 1000 increments; assert monotonic and final count |
| AlarmScheduler | Overlapping alarm schedule collisions (two routes same destination & time) | Integration test triggers one alarm | M | Add dual alarm schedule test verifying distinct IDs and no overwrite |
| Notification Service | Rapid update suppression (debounce) logic if present (not fully inspected) | Not directly asserted | L | Add test ensuring excessive updates inside debounce window collapse |
| Power/Policy | Low battery mode altering tracking frequency | Not simulated | L | Battery policy stub test adjusting config |

## Summary Stats
- Gaps enumerated: 17
- Risk profile: High=0, Medium=7, Low=10
- No High risks remain after Phase 1.

## Prioritization Rationale
Medium risks are those with potential to cause silent failure (missed reroute, cache eviction inefficiency, incorrect metric growth) or user experience degradation. Low risks either have natural guard rails (single-flight, strict inequality) or low probability (disk truncation without crash).

## Phase 2 Recommended Ordering
1. ReroutePolicy cooldown overlap
2. RouteCache IO & corruption variants
3. DeviationMonitor reset mid-sustain
4. MetricsRegistry concurrent increments stress
5. ApiClient boundary & retry exhaustion
6. OfflineCoordinator mid-flight transition
7. ActiveRouteManager blackout interplay
8. Remaining low-risk fine-grained boundary cases

## Instrumentation Enhancements Suggested
- Inject FakeClock across services for deterministic timing tests.
- Add pluggable persistence adapter for RouteCache (in-memory + faulting mock).
- Central TestHarness exposing counters for token refresh attempts & reroute dispatch counts.

## Exit Criteria for Phase 2 (Proposed)
- All Medium risks have at least one dedicated deterministic test.
- Retry, cooldown, sustain, and blackout window timing paths validated with FakeClock.
- Cache corruption tests cover: malformed JSON, truncated JSON, size overflow.
- Metrics stress tests achieve 100% branch coverage for registry increment logic.

---
Generated: 2025-09-28
