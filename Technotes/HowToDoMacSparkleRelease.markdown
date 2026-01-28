# How To Do Mac Sparkle Release

NetNewsWire_mac_target_common.xcconfig
	update MARKETING_VERSION and CURRENT_PROJECT_VERSION

Run buildscripts/quiet_build_and_test.sh

Run app

ReleaseNotes-Mac.markdown
main branch
Write change notes in notes
Include branch and tag

Make sure there are no outstanding changes

Archive build
Developer ID distribution - notarize
Click Distribute App button
Wait while processing

Export
Smoke test

On main: update Technotes/Status.md
commit

git push

Tag the app:
git tag mac-6.1.5b4

Push:
git push origin mac-6.1.5b4

Find tag in GitHub - https://github.com/Ranchero-Software/NetNewsWire/tags
Turn into release — NetNewsWire 6.1.5b4 for Mac
Add change notes
Zip app - NetNewsWire6.1.5b4.zip
Upload binary to release
Publish release
Copy file to releases archive — /Volumes/KD/Archive/Releases/

Update Appcast on main branch
	Add changes
	Update title
	Update pubDate
	Update enclosure URL
	Update version
	Update file size - length

Run xmllint on appcast
xmllint --noout ~/Projects/nnw/main/Appcasts/netnewswire-beta.xml

Upload appcast
Commit and push git change

Test updating via appcast

Optionally:
Announce on Discourse
Announce on blog

If release build:
	Update netnewswire-release.xml
	Update download on netnewswire.com — via .htaccess redirect

