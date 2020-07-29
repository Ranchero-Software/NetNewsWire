#!/bin/sh
set -v
set -e

# Unencrypt our provisioning profiles, certificates, and private key
# 
# Encrypt the profiles, certs, and key using the following example command where 
# "secret-key" is the key stored in the Github Secrets variable ENCRYPTION_SECRET
#
# openssl aes-256-cbc -k "secret-key" -in buildscripts/profile/NetNewsWire.provisionprofile -out buildscripts/profile/NetNewsWire.provisionprofile.enc -a
#
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in buildscripts/profile/NetNewsWire.provisionprofile.enc -d -a -out buildscripts/profile/NetNewsWire.provisionprofile
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in buildscripts/profile/NetNewsWireiOS.mobileprovision.enc -d -a -out buildscripts/profile/NetNewsWireiOS.mobileprovision
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in buildscripts/certs/mac-dist.cer.enc -d -a -out buildscripts/certs/mac-dist.cer
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in buildscripts/certs/ios-dist.cer.enc -d -a -out buildscripts/certs/ios-dist.cer
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in buildscripts/certs/mac-dist.p12.enc -d -a -out buildscripts/certs/mac-dist.p12

# Put the certificates and private key in the Keychain, set ACL permissions, and make default
security create-keychain -p github-actions github-build.keychain
security import buildscripts/certs/apple.cer -k ~/Library/Keychains/github-build.keychain -A
security import buildscripts/certs/mac-dist.cer -k ~/Library/Keychains/github-build.keychain -A
security import buildscripts/certs/ios-dist.cer -k ~/Library/Keychains/github-build.keychain -A
security import buildscripts/certs/mac-dist.p12 -k ~/Library/Keychains/github-build.keychain -P $KEY_SECRET -A
security set-key-partition-list -S apple-tool:,apple: -s -k github-actions github-build.keychain
security default-keychain -s github-build.keychain

# Copy the provisioning profile
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
cp buildscripts/profile/NetNewsWire.provisionprofile ~/Library/MobileDevice/Provisioning\ Profiles/
cp buildscripts/profile/NetNewsWireiOS.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/

# Delete the decrypted files
rm -f buildscripts/profile/NetNewsWire.provisionprofile
rm -f buildscripts/profile/NetNewsWireiOS.mobileprovision
rm -f buildscripts/certs/mac-dist.cer
rm -f buildscripts/certs/ios-dist.cer
rm -f buildscripts/certs/mac-dist.p12

# Do the build
xcodebuild -scheme $SCHEME build -destination "$DESTINATION" -showBuildTimingSummary -allowProvisioningUpdates

# Delete the keychain and the provisioning profile
security delete-keychain github-build.keychain
rm -f ~/Library/MobileDevice/Provisioning\ Profiles/NetNewsWire.provisionprofile
rm -f ~/Library/MobileDevice/Provisioning\ Profiles/NetNewsWireiOS.mobileprovision
