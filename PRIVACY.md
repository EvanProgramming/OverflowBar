# Privacy

OverflowBar processes menu-bar layout and item captures locally. It does not send screen captures, menu contents, or layout selections to a server.

## Permissions and local processing

Accessibility identifies menu-bar controls and supports arrangement and activation. Native menu-bar operations can post mouse events and temporarily move and restore the pointer. Operations are bounded, cancellable, and cleaned up after failure.

Screen & System Audio Recording enables point-in-time captures of selected status-item windows. Captures stay in bounded memory, are not uploaded, and are not kept as screenshot history. The recyclable capture helper contains the system's private-capture leak.

Permission denial is shown in setup and settings. Unknown controls are not guessed or clicked. The app uses private macOS APIs to support off-screen menu-bar windows; operating-system changes can affect compatibility.

## Network access

Sparkle contacts the configured GitHub release feed to check for signed updates. The updater asks before installing. OverflowBar does not send captures or item choices with these checks.

## Signing and permission changes

Community builds are ad-hoc signed. Replacing a local build can require permission reauthorization. Remove only OverflowBar's stale permission entry; leave other applications' grants unchanged.

See [Permissions](docs/PERMISSIONS.md) for purpose, denial, and recovery details.

## Related guides

[Permissions](docs/PERMISSIONS.md) · [Installation](docs/INSTALLATION.md) · [Troubleshooting](docs/TROUBLESHOOTING.md)
