# How To Do iOS TestFlight Release

Be sure to have updated code and be *on correct branch*

## Edit Build Version

NetNewsWire_ios_target_common.xcconfig

Possibly bump MARKETING_VERSION
Increment CURRENT_PROJECT_VERSION by 1 (usually)

Commit change.

## Test

Run buildscripts/quiet_build_and_test.sh to be sure all platforms build and tests pass.

Build and run app on device

Smoke test
If it fails, bail.
Check in and push changes.

## Create Release Notes

On main:

ReleaseNotes-iOS.markdown

Go to milestone and find closed bugs since last release notes
Add to iOS Release Notes note

Write release notes

Commit change.

## Archive and Upload

Archive
Distribute to TestFlight

## Status

Update NetNewsWire Status doc in Technotes
Commit

## Tag

On branch (or on main, if working on main):

Use SemVer with tags
Tag the app: git tag iOS-6.1.5-6124
Push: git push origin iOS-6.1.5-6124

## Release the app

In AppStoreConnect add groups and release the app
Paste in the release notes
Announce in Discourse
Optionally blog about it

## GitHub release

Make new release from tag

https://github.com/Ranchero-Software/NetNewsWire/tags

Example title:
NetNewsWire 6.1.6 (6140) for iOS - TestFlight

## Notes

Public TestFlight link:
https://testflight.apple.com/join/wpedPMRR

Update Technotes/Status.md
