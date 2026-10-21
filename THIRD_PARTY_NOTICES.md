# Native engine provenance

OverflowBar v1.5 is GPL-3.0. Earlier OverflowBar code retains the original MIT notice in [LICENSE-MIT-ORIGINAL](LICENSE-MIT-ORIGINAL). The combined application is distributed under [LICENSE](LICENSE).

Pinned sources:

- [Thaw 73d275284a34a95c02416086f891b4fb4179bbab](https://github.com/thaw-app/Thaw/tree/73d275284a34a95c02416086f891b4fb4179bbab), copyright © 2026 Toni Förster, GPLv3.
- [Ice d567f1ecac68936a090d6b47d6f0b882c489c6f4 / 0.11.12](https://github.com/jordanbaird/Ice/tree/d567f1ecac68936a090d6b47d6f0b882c489c6f4), copyright © 2023–2025 Jordan Baird, GPLv3.

| OverflowBar files | Upstream source | Local changes |
| --- | --- | --- |
| `OverflowBar/Engine/MoveCircuitBreaker.swift`, `OverflowBarTests/Upstream/MoveCircuitBreakerTests.swift` | Thaw `MenuBarItemManager/MoveCircuitBreaker.swift` and its tests | Logger and import names, Swift 5-compatible collection counting; policy thresholds preserved. |
| `OverflowBar/Engine/EngineMoveBudget.swift` | Thaw `MenuBarItemManager+MoveTransaction.swift`, `MoveTransactionBudget` | Extracted standalone budget, renamed errors, default sleeper for deterministic tests. |
| `OverflowBar/Engine/NativeLayoutPolicy.swift` | Thaw `LayoutSolver.swift`, longest-common-subsequence planner | Two sections only; divider fixed; no profile, always-hidden or macOS 27 behavior. |
| `EngineShared/ExtrasDiscovery.swift` | Thaw `SourcePIDCache.swift`, `AXHelpers.swift` | Native AX APIs instead of AXSwift; bounded per-call/batch IPC; exact window matching followed by unique same-row geometry; no guessed source or persisted window IDs. |
| `EngineShared/NativeWindowBridge.swift`, `EngineWorker/CaptureWorker.swift` | Ice/Thaw `Bridging`, `Shims`, `ScreenCapture`, capture worker | Dynamic private-symbol lookup, private status-window enumeration with published fallback, per-window crops, measured image scale, payload bounds and recycling of every attempted private capture. |
| `OverflowBar/Engine/NativeEventRelay.swift` | Ice `MenuBarItemManager.swift` event barrier/scromble; Thaw event continuation/mismatch filtering | Scoped taps and cleanup; two OS paths share the native transport; cancellation and exact-window validation; no standalone staging item; native click fields stay separate from move fields. |
| `OverflowBar/Engine/MenuBarEngine.swift` | Ice/Thaw move geometry, move transactions, click and temporary-show operations | Focused two-section adapter, fresh endpoint resolution, bounded retries, positive menu-close restoration, explicit unobserved result. |
| `OverflowBar/App/StatusBarController.swift` | Thaw `ControlItem.swift` materialization and host recovery | Bounded disposal/recreation of only OverflowBar’s controls; no system preference repair in application code. |
| `OverflowBar/Engine/NativeResponseVerifier.swift` and response tests | Thaw `ClickReactionVerifier.swift` and its tests | Small WindowServer snapshots; origin-only changes remain unobserved. |

The helper transport, signature validation, UI adapters, fixtures and remaining tests are OverflowBar implementation. No upstream branding, assets, profiles, appearance editor, triggers or macOS 27 management were imported. The shared transport is compatible with macOS 15; macOS 26 source attribution handles Control Center hosting.

Sparkle remains an independently licensed dependency; its framework notices are retained. No paid certificate or Team ID is required for the engine helpers.
