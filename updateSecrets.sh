#!/bin/bash

find . -name '*.gyb' |
  while read file; do
    echo "running ${file%.gyb}";
    ./Vendor/gyb --line-directive '' -o "${file%.gyb}" "$file";
  done