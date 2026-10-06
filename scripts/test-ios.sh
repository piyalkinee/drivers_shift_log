#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if curl --silent --fail --max-time 2 http://127.0.0.1:18080/health >/dev/null; then
    echo 'Port 18080 is already serving an API; stop it before running isolated UI tests.' >&2
    exit 1
fi
fixture_dir=$(mktemp -d)
server_pid=''
cleanup() {
    if [ -n "$server_pid" ]; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi
    rm -rf "$fixture_dir"
}
trap cleanup EXIT
(cd backend && go build -o "$fixture_dir/server" ./cmd/server)
ADDR=127.0.0.1:18080 DATA_FILE="$fixture_dir/trips.json" "$fixture_dir/server" >"$fixture_dir/server.log" 2>&1 &
server_pid=$!
for attempt in {1..30}; do
    kill -0 "$server_pid" 2>/dev/null || { cat "$fixture_dir/server.log"; exit 1; }
    if curl --silent --fail --max-time 2 http://127.0.0.1:18080/health >/dev/null; then break; fi
    sleep 0.2
done
curl --silent --fail --max-time 2 http://127.0.0.1:18080/health >/dev/null
if [ -z "${IOS_DESTINATION:-}" ]; then
    simulator_id=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(v["udid"] for k,vs in d["devices"].items() if "iOS" in k for v in vs if "iPhone" in v["name"]))')
    IOS_DESTINATION="platform=iOS Simulator,id=$simulator_id"
fi
mkdir -p build/TestResults
result_path="build/TestResults/$(date +%Y%m%d-%H%M%S)-$$.xcresult"
xcodebuild -project ios/ShiftLog.xcodeproj -scheme ShiftLog \
    -destination "$IOS_DESTINATION" -parallel-testing-enabled NO \
    -derivedDataPath build -resultBundlePath "$result_path" \
    CODE_SIGNING_ALLOWED=NO test
