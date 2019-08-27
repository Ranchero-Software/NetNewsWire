# ![Icon](Technotes/Images/icon.png) NetNewsWire

[![CircleCI](https://circleci.com/gh/brentsimmons/NetNewsWire.svg?style=svg)](https://circleci.com/gh/brentsimmons/NetNewsWire)
[![GitHub All Releases](https://img.shields.io/github/downloads/brentsimmons/netnewswire/total)](https://github.com/brentsimmons/NetNewsWire/releases)

It’s a free and open source feed reader for macOS.

It’s not in beta just yet. Getting close! While NetNewsWire 5.0 is feature-complete as of May 25, 2019, it has known bugs — and, surely, plenty of unknown bugs.

It supports [RSS](http://cyber.harvard.edu/rss/rss.html), [Atom](https://tools.ietf.org/html/rfc4287), [JSON Feed](https://jsonfeed.org/), and [RSS-in-JSON](https://github.com/scripting/Scripting-News/blob/master/rss-in-json/README.md) formats.

More info: [https://ranchero.com/netnewswire/](https://ranchero.com/netnewswire/)

Also see the [Technotes](Technotes/) and the [Roadmap](Technotes/Roadmap.md).

Note: NetNewsWire’s Help menu has a bunch of these links, so you don’t have to remember to come back to this page.

Here’s [How to Support NetNewsWire](Technotes/HowToSupportNetNewsWire.markdown). Spoiler: don’t send money. :)

#### Community

[Join the Slack group](https://join.slack.com/t/netnewswire/shared_invite/enQtNjM4MDA1MjQzMDkzLTNlNjBhOWVhYzdhYjA4ZWFhMzQ1MTUxYjU0NTE5ZGY0YzYwZWJhNjYwNTNmNTg2NjIwYWY4YzhlYzk5NmU3ZTc) to talk with other NetNewsWire users — and to help out, if you’d like to, by testing, coding, writing, providing feedback, or just helping us think things through. Everybody is welcome and encouraged to join.

Every community member is expected to abide by the code of conduct which is included in the [Contributing](CONTRIBUTING.md) page.

#### Pull Requests

See the [Contributing](CONTRIBUTING.md) page for our process. It’s pretty straightforward.

#### Building

```bash
git clone https://github.com/brentsimmons/NetNewsWire.git
cd NetNewsWire
git submodule update --init
```

You can locally override the Xcode settings for code signing
by creating a `DeveloperSettings.xcconfig` file locally at the appropriate path.
This allows for a pristine project with code signing set up with the appropriate
developer ID and certificates, and for dev to be able to have local settings
without needing to check in anything into source control.

As an example, make a directory SharedXcodeSettings next to where you have this repository.
An example of the structure is:

```
aDirectory/
  SharedXcodeSettings/
    DeveloperSettings.xcconfig
  NetNewsWire
    NewNewsSire.xcworkspace
```

Then create a plain text file in it: `SharedXcodeSettings/DeveloperSettings.xcconfig` and
give it the contents:

```
CODE_SIGN_IDENTITY = Mac Developer
DEVELOPMENT_TEAM = <Your Team ID>
CODE_SIGN_STYLE = Automatic
PROVISIONING_PROFILE_SPECIFIER =
```

Now you should be able to build without code signing errors and without modifying
the NetNewsWire Xcode project.

Example:

If your NetNewsWire Xcode project file is at:
`/Users/Shared/git/NetNewsWire/NetNewsWire.xcodeproj`

Create your `DeveloperSettings.xcconfig` file at
`/Users/Shared/git/SharedXcodeSettings/DeveloperSettings.xcconfig`
