# Adaptive ETA & Alarm System Overview

## Goals
Reliable wake/transfer alarms based on continuous ETA, distance, and stops progression with minimal false positives and timely user prompts (pre-boarding + transfers + destination), resilient to GPS variance and multi-modal journeys.

## Architecture Components
- **EtaEngine (`lib/services/eta/eta_engine.dart`)**: Raw ETA sampling, exponential smoothing, confidence (sample saturation), volatility (recent dispersion), rapid drop detection (raw ETA delta), metadata feeding adaptive scheduler.
- **Adaptive Scheduler**: Tiered intervals for time & distance (far→mid→near→close→veryClose→burst) modulated by: movement mode (walk / transit / drive), confidence (+interval), volatility (−interval), burst mode with hysteresis (rapid tightening when inside threshold).
- **Stops Mode Enhancements**:
  - Destination hysteresis: require 2 consecutive passes below remaining stops threshold before gating evaluation.
  - Pre-boarding alert: dynamic window = clamp(alarmValue * heuristicMetersPerStop, 400m, 1500m) (default heuristic 550m/stop).
  - Transfer early alert heuristic: single-stop window = clamp(heuristicMetersPerStop, 300m, 800m) independent of destination threshold to prevent very early spam while providing useful notice.
- **Gating & Stability**: Proximity dwell (time/distance/stops unified), consecutive passes, deduplication keys (pre-boarding, event alarms, destination), jitter resilience.

## Heuristic Rationale
Urban stop spacing distribution (literature + synthetic tests): ~400–600m dense metro, 600–1200m typical heavy rail; chosen midpoint 550m. Scaling destination pre-boarding by user stop preference (capped at 1500m) honors user desire for earlier wake without excessive anticipation. Transfers use a single-stop heuristic window to avoid compounding early alerts.

## Key Configurables
| Config | Purpose | Default |
|--------|---------|---------|
| `TrackingService.stopsHeuristicMetersPerStop` | Base meters per stop heuristic | 550.0 |
| `adaptiveRapidEtaChangeFrac` | Raw ETA rapid drop trigger | 0.20 |
| `adaptiveReentryHysteresis` | Burst exit multiplier | 1.10 |
| Hysteresis required passes (stops) | Destination stops stability | 2 |

## Tests Added / Updated
- `preboarding_alert_test.dart` – legacy behavior preserved via dynamic threshold (still satisfied).
- `preboarding_heuristic_scaling_test.dart` – scaling & cap logic + non-duplication.
- `metro_stops_prior_test.dart` – transfer + pre-boarding interplay (still green).
- `adaptive_journey_integration_test.dart` – multi-phase walk→drive→transit path to destination; validates end-to-end alarms.
- `stops_hysteresis_jitter_test.dart` – verifies two-pass stops hysteresis guards against single jitter.
- Existing invariants & distance/time gating tests remain passing.

## Remaining / Deferred Edge Cases
| Edge Case | Status | Notes |
|-----------|--------|-------|
| Tunnel / GPS blackout bridging | Deferred | Could retain last good speed & apply decay model; not yet implemented.
| Android Doze / background throttling | Deferred | Potential fallback with OS scheduled exact alarm; future work.
| Dynamic heuristic personalization | Deferred | Could collect anonymized average stop spacing per user region.
| Transfer chaining (multiple rapid transfers) | Partially Covered | Heuristic should still apply individually; no extra batching logic yet.
| Loss of movement mode accuracy | Mitigated | Activity scalar default safe (1.0) if classifier uncertain.

## UX Impact
- Earlier but not premature awareness (pre-boarding & transfer) reduces anxiety and missed stops.
- Reduced false alarms through hysteresis + dwell promotes user trust.
- Adaptive cadence lowers battery usage when far while ensuring dense updates near threshold or volatility spikes.

## Extension Ideas
1. Confidence-weighted ETA blending with historical segment averages.
2. Bayesian stop-spacing refinement from observed ride distances.
3. Automatic scaling of transfer heuristic if first transit leg indicates longer average spacing.
4. Offline fallback threshold tracking using step bounds only when GPS intermittent.

## Verification Snapshot
All new and existing targeted tests pass (see CI/test run). Heuristic introduced without breaking prior semantics; defaults safe for dense networks and configurable for future tuning.

---
Generated: (auto) Adaptive ETA & Alarm System Summary.
