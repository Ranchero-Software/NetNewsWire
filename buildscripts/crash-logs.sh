#!/bin/sh

for filename in ~/Library/Logs/DiagnosticReports/NetNewsWire*.crash; do
    cat $filename
done