#!/bin/sh

for filename in ~/Library/Logs/DiagnosticReports/Slack*.crash; do
    cat $filename
done