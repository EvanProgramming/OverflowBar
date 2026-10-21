# Native-engine release gates

## Automated checks

Run macOS XCTest, Debug and universal Release builds, `scripts/check-native-engine.sh`, documentation checks and nested signature/package verification. Build the universal fixture with `bash scripts/build-native-fixture.sh`. The fixture has a native menu, custom popover, toggle, disappearing target and `--unresponsive` mode. Its real native actions increment `/private/tmp/overflowbar-native-fixture-state.json`.

Helper tests must demonstrate authenticated ad-hoc discovery, rejection of mismatched code, nonempty live native-window enumeration, separate capture service embedding and exactly-once completion. Policy tests cover ambiguous/cross-row matches, layout minimization, shared deadlines, payload/scale validation, migration and native-response observation. Imported circuit-breaker tests preserve upstream thresholds.

## Physical GUI matrix — required on macOS 15 and 26.4

- Select actual native fixture and third-party icons; confirm originals disappear while protected system controls remain visible.
- Open the second row. Compare recognizable captured previews against the originals, not app-icon fallbacks or generic grids.
- Activate the native menu, popover, toggle, disappearing item and a real Electron tray item. Confirm the intended owner responds and no unrelated menu opens.
- Close native menus and confirm original order is restored. Uncertain states must remain accessible with an explanation.
- Exercise denied/regranted permissions, helper interruption/recycling, upgrade, relaunch, Safe Reset and quit.
- Exercise sleep/wake, new app launches, mixed-scale and negative/overlapping displays, notches, Spaces, fullscreen and menu-bar auto-hide.
- Require 100 complete panel/activation cycles, then a two-hour soak. Record real fixture action counters and resource samples. No hangs, stuck mouse state, growing caches or repeated repair loop are acceptable.

## Current evidence

The local host is macOS 26.4. Authenticated worker and policy XCTest checks are recorded in the implementation ledger. Real capture/activation requires explicit permission grants to the installed candidate. macOS 15 physical GUI coverage and the complete cycle/soak matrix remain release blockers until recorded; no claim of stable native behavior may replace them.

No v1.5.0 release, tag or published cask update should occur before these gates pass.
