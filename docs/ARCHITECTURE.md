# OverflowBar native engine

The menu bar contains two persistent native controls: `OverflowBarControlItem` and `OverflowBarHiddenSection`. Selected icons are arranged to the left of the divider. A 10,000-point native separator conceals that section; the arrow opens a captured, floating second row.

`NativeMenuBarEngine` is the serialized boundary for discovery, layout application, activation, cancellation and recovery. `MenuBarItemStore` presents state and owns preferences, not event posting. Source provenance and the exact Ice/Thaw pins are in [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).

## Identity

Persistent identities come from a resolved originating bundle and Accessibility identifier/name. Window IDs and PIDs are session handles. On macOS 26, Control Center owns the item windows: source attribution walks each application's `AXExtrasMenuBar`, prefers exact backing-window identity, and accepts only unique same-row geometric fallback. Ambiguous items stay visible and cannot be guessed click targets. On macOS 15, native window ownership also identifies the source.

## Helpers

Two embedded XPC services compile the shared worker implementation. `EngineWorker` performs bounded discovery/AX activation; `CaptureWorker` performs ScreenCaptureKit and private SkyLight capture. Both join the user's existing session. Separate connections prevent capture recycling from interrupting an in-flight move.

Every connection validates the current packaged peer's designated code-signing requirement before resume, including ad-hoc code hashes. There is no same-Team-ID requirement and no unauthenticated fallback. Requests time out after three seconds; capture interruption permits one reconnect/retry. Pixel dimensions, total payloads and requested status windows are bounded. Private capture attempts count toward recycling even when they fail.

## Layout and activation

A stable native snapshot precedes automatic layout. The two-section planner keeps the divider fixed and minimizes moves with upstream LCS logic. Moves share an absolute 15-second deadline, verify fresh endpoints and settled placement, and release taps/buttons/cursor state on every exit. Automatic repeats and failed batches are rationed by the upstream circuit breaker. Only verified placement is persisted; partial results remain partial.

Activation resolves the source again, uses native AX press for Electron when advertised, otherwise posts scoped native events. Offscreen targets temporarily move beside the arrow. A delivered event is not menu success: the response verifier observes a new owner interface or item size/disappearance. An uncertain menu stays accessible. Restoration uses original neighbor identities only after a positively observed close.

## Lifecycle

Desired hidden state and realized native visibility are separate. Quit shrinks the divider without erasing the preference. Manual app launch and Finder reopen display setup/overview; login startup stays in the background. The panel refreshes captured icons at at most two batches per second, only while visible. Permission denial is explicit. macOS 27+ fails open and does not run native management.

## Release acceptance

Builds and generic fallback icons cannot establish GUI reliability. The [validation checklist](NATIVE_VALIDATION.md) tracks actual native hiding, recognizable previews, intended menus, 100 cycles and a two-hour soak on macOS 15 and 26.4. The v1.5.0 release report records which physical checks were not run; they must not be treated as passed.
