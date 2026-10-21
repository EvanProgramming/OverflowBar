#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Native input is allowed only inside the serialized engine, never in discovery/capture/UI.
MATCHES="$(rg -l 'CGEvent\(|CGWarpMouseCursorPosition|\.postToPid\(|\.post\(tap:' "$ROOT/OverflowBar" "$ROOT/EngineShared" "$ROOT/EngineWorker" --glob '*.swift' || true)"
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    case "$file" in
        "$ROOT/OverflowBar/Engine/MenuBarEngine.swift"|"$ROOT/OverflowBar/Engine/NativeEventRelay.swift") ;;
        *) echo "Native input escaped the serialized engine: $file" >&2; exit 1 ;;
    esac
done <<< "$MATCHES"
if rg -n 'CGWindowListCreateImageFromArray|staging.target|StagingTarget|setAXPosition' "$ROOT/OverflowBar" "$ROOT/EngineShared" "$ROOT/EngineWorker" --glob '*.swift'; then
    echo "Obsolete capture or staging-target implementation returned." >&2; exit 1
fi
