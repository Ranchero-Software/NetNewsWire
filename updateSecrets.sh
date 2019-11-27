#!/bin/bash

if [ ! $(type -P "gyb") ]; then
  echo "gyb not installed. Install via: brew install nshipster/formulae/gyb"
  exit 1
fi

find . -name '*.gyb' |
  while read file; do
    echo "running ${file%.gyb}";
    gyb --line-directive '' -o "${file%.gyb}" "$file";
  done