#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

find "${PROJECT_ROOT}" -name '*.gyb' -print0 |
  while IFS= read -r -d '' file; do
    echo "Generating ${file%.gyb}"
    "${PROJECT_ROOT}/buildscripts/gyb" --line-directive '' -o "${file%.gyb}" "$file"
  done
