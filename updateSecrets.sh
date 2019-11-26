#!/bin/bash

find . -name '*.gyb' |                                               \
  while read file; do                                              \
    echo "running ${file%.gyb}"; \
    gyb --line-directive '' -o "${file%.gyb}" "$file"; \
  done