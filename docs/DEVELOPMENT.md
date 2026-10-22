# Development

## Requirements

- macOS 15 or later
- Xcode 26; CI verifies the Xcode 26 toolchain
- The OverflowBar Xcode project and its resolved Swift packages

The current macOS 26.4 host passed an XCTest suite and native-fixture checks recorded in the [v1.5 release report](RELEASE_CHECKS_V1.5.md). Physical macOS 15 and Intel machines were not available for that release audit. A successful build is not evidence of native menu-bar behavior.

## Open or build

Open OverflowBar.xcodeproj in Xcode and select the shared OverflowBar scheme.

To build from the command line:

    xcodebuild -project OverflowBar.xcodeproj -scheme OverflowBar -configuration Debug -destination 'generic/platform=macOS' CODE_SIGN_IDENTITY="-" build

To run the test suite on macOS:

    xcodebuild -project OverflowBar.xcodeproj -scheme OverflowBar -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" test

CI runs the equivalent Debug build, XCTest suite, and universal Release build in [build.yml](../.github/workflows/build.yml). A live Accessibility-dependent test may be skipped when its permission is unavailable.

## Project map

- OverflowBar/ contains the SwiftUI app, onboarding, settings, panel, native engine, and services.
- EngineShared/ contains native identity, window, discovery, and peer-signing logic shared with helper processes.
- EngineWorker/ performs bounded discovery and native activation.
- Capture-worker sources are in EngineWorker/CaptureWorker.swift; the helper is embedded as a separate authenticated service.
- OverflowBarTests/ contains policy, capture, activation, onboarding, migration, and worker integration tests.
- NativeFixtures/ contains the app used to exercise native menu, popover, toggle, and disappearing-item behavior.
- [Architecture](ARCHITECTURE.md) describes the runtime boundaries.

## Native testing

Preserve bounded operations, cancellation, and cleanup when changing event delivery. Native operations can briefly move and restore the pointer. Test cancellation and recovery; a unit test or generic icon cannot establish physical menu-bar behavior.

Read the [native validation checklist](NATIVE_VALIDATION.md) before changing capture, discovery, placement, or activation. Permission-dependent tests require the installed test host to be granted Accessibility. Request Screen Recording only when exercising capture. Do not edit protected Control Center preferences or ask contributors to disclose menu-bar screenshots without checking for private content.

## Signing and release scope

Local Debug builds use ad-hoc signing and need no paid Developer ID certificate. Never describe community builds as notarized. Release signing, signed update generation, and publication are documented in [Releasing](RELEASING.md).

## Related guides

[Contributing](../CONTRIBUTING.md) · [Architecture](ARCHITECTURE.md) · [Native validation](NATIVE_VALIDATION.md) · [Permissions](PERMISSIONS.md) · [Releasing](RELEASING.md)
