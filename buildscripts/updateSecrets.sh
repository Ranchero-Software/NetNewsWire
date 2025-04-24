#!/bin/bash

find "${PROJECT_DIR}" -name '*.gyb' |
  while read file; do
    echo "Generating ${file%.gyb}";
    "${PROJECT_DIR}/buildscripts/gyb" --line-directive '' -o "${file%.gyb}" "$file";
  done