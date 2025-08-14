# How To Do App Store Release

Write release notes in ReleaseNotes-iOS.markdown on main
Commit release notes

Tag the app if needed:

	git tag iOS-6.1.9
	git push origin iOS-6.1.9

Click + near iOS App
Type in new version name
Scroll way down to Build section and choose the build (latest TestFlight build, presumably)
Fill in What’s New text
Click Save at top of screen
Click Add for Review next to Save

On next screen, click Submit to App Review

Make new release from tag

https://github.com/Ranchero-Software/NetNewsWire/tags

Example title:
NetNewsWire 6.1.6 (6140) for iOS - AppStore

Announce on Slack
Announce on NetNewsWire blog
Optionally announce on inessential
