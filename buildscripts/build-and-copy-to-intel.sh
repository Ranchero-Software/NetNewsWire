#!/bin/bash
set -euo pipefail

# Builds a Developer ID–signed Release build and copies it to the Intel laptop.

SCRIPTS_DIRECTORY="$(dirname "$0")"

"$SCRIPTS_DIRECTORY/build-local-test-release-config.sh"
"$SCRIPTS_DIRECTORY/copy_to_intel.sh"
