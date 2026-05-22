#!/bin/bash
#
# fail_on_warnings.sh — fail the build if any first-party warning lines
# appear in the captured xcodebuild log. SPM checkout paths are excluded
# so warnings inside external dependencies don't fail CI.
#
# Usage: fail_on_warnings.sh <path-to-build-log>

set -euo pipefail

log_file="${1:-}"
if [[ -z "$log_file" || ! -f "$log_file" ]]; then
	echo "fail_on_warnings.sh: build log not found: $log_file" >&2
	exit 2
fi

# Match clang/swift compiler warning format: path:line:col: warning: ...
# Exclude SPM package checkouts and DerivedData paths.
warnings=$(grep -E "^[^[:space:]].*:[0-9]+:[0-9]+: warning:" "$log_file" \
	| grep -v "SourcePackages/checkouts" \
	| grep -v "/DerivedData/" \
	| sort -u || true)

if [[ -n "$warnings" ]]; then
	echo ""
	echo "::error::Build produced first-party warnings — failing CI."
	echo ""
	echo "$warnings" | while IFS= read -r line; do
		echo "::warning::$line"
	done
	exit 1
fi

echo "No first-party warnings detected."
