#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

swift test
swift build --product ClipCanvas
swift build --product clipcanvas-mcp
