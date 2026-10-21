# OverflowBar v1.5.0 candidate — native engine replacement

This candidate replaces the manual-grouping backend with a focused Ice/Thaw engine port. It restores per-icon selection, native drag arrangement, correctly attributed source applications, genuine second-row previews and native-menu activation.

The app retains its bundle identity, status autosave names, ad-hoc signing, login preference and signed Sparkle updates. v1.5 adopts GPL-3.0 with upstream provenance. Manual launch reopens setup/overview, and quit reveals originals without clearing the desired hidden state.

Accessibility is required for automatic arrangement and activation. Screen Recording enables genuine previews. Native operations can move the pointer. Timeouts, cancellation, response verification and an automatic-move circuit breaker replace unbounded retries and the former staging target.

**Not released:** physical macOS 15/26.4 validation, real native-menu cycles, helper permission attribution and the two-hour soak must pass first. See [release gates](docs/NATIVE_VALIDATION.md). Generic placeholders and an expanded separator do not count as proof.
