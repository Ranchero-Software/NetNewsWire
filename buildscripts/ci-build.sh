#!/bin/sh
set -v
set -e

openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in buildscripts/certs/dev.cer.enc -d -a -out buildscripts/certs/dev.cer
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in buildscripts/certs/dev.p12.enc -d -a -out buildscripts/certs/dev.p12

security create-keychain -p github-actions github-build.keychain
security import buildscripts/certs/apple.cer -k ~/Library/Keychains/github-build.keychain -A
security import buildscripts/certs/dev.cer -k ~/Library/Keychains/github-build.keychain -A
security import buildscripts/certs/dev.p12 -k ~/Library/Keychains/github-build.keychain -P $KEY_SECRET -A
security set-key-partition-list -S apple-tool:,apple: -s -k github-actions github-build.keychain
security default-keychain -s github-build.keychain

rm -f ./buildscripts/certs/dev.cer
rm -f ./buildscripts/certs/dev.p12

xcodebuild -scheme 'NetNewsWire' -configuration Debug -allowProvisioningUpdates -showBuildTimingSummary

security delete-keychain github-build.keychain