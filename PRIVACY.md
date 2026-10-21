# Privacy

OverflowBar does not send icon captures, native menu information or layout selections to a server. Sparkle contacts the configured GitHub update feed to check signed updates.

Accessibility is used to attribute menu-bar controls and perform native arrangement/activation. Native mouse events and temporary pointer movement are permitted in v1.5. Operations are serialized, bounded and cleaned up on failure or cancellation.

Screen Recording is used for point-in-time captures of selected native status-item windows. Two authenticated local helper services isolate blocking discovery and capture. Captures remain in bounded memory; no screenshot history is recorded. The recyclable capture process confines the system private-capture leak.

Permission denial is visible in setup/overview. Unknown native controls are not guessed or clicked. Private macOS APIs are used for compatibility with offscreen menu-bar windows and are a release-validation risk.

Ad-hoc signing is retained. Updates can require macOS permission regranting. Only the installed build should be added to Privacy & Security; unrelated apps' grants remain untouched.
