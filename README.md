# ![Icon](Technotes/Images/icon.png) NetNewsWire

[![CI](https://github.com/Ranchero-Software/NetNewsWire/workflows/CI/badge.svg?branch=main)](https://github.com/Ranchero-Software/NetNewsWire/actions?query=workflow%3ACI+branch%3Amain)

It’s a free and open source feed reader for macOS and iOS.

It supports [RSS](http://cyber.harvard.edu/rss/rss.html), [Atom](https://tools.ietf.org/html/rfc4287), [JSON Feed](https://jsonfeed.org/), and [RSS-in-JSON](https://github.com/scripting/Scripting-News/blob/master/rss-in-json/README.md) formats.

More info: [https://ranchero.com/netnewswire/](https://ranchero.com/netnewswire/)

Also see the [Technotes](Technotes/) and the [Roadmap](Technotes/Roadmap.md).

Note: NetNewsWire’s Help menu has a bunch of these links, so you don’t have to remember to come back to this page.

Here’s [How to Support NetNewsWire](Technotes/HowToSupportNetNewsWire.markdown). Spoiler: don’t send money. :)

#### Community

[Join the Slack group](https://ranchero.com/netnewswire/slack) to talk with other NetNewsWire users — and to help out, if you’d like to, by testing, coding, writing, providing feedback, or just helping us think things through. Everybody is welcome and encouraged to join.

Every community member is expected to abide by the code of conduct which is included in the [Contributing](CONTRIBUTING.md) page.

#### Pull Requests

See the [Contributing](CONTRIBUTING.md) page for our process. It’s pretty straightforward.

#### Building

You can build and test NetNewsWire without a paid developer account.

```bash
git clone https://github.com/Ranchero-Software/NetNewsWire.git
cd NetNewsWire
git submodule update --init --recursive
```

You can locally override the Xcode settings for code signing
by creating a `DeveloperSettings.xcconfig` file locally at the appropriate path.
This allows for a pristine project with code signing set up with the appropriate
developer ID and certificates, and for dev to be able to have local settings
without needing to check in anything into source control.

Make a directory SharedXcodeSettings next to where you have this repository.

The directory structure is:

```
aDirectory/
  SharedXcodeSettings/
    DeveloperSettings.xcconfig
  NetNewsWire
    NetNewsWire.xcworkspace
```
Example:

If your NetNewsWire Xcode project file is at:
`/Users/Shared/git/NetNewsWire/NetNewsWire.xcodeproj`

Create your `DeveloperSettings.xcconfig` file at
`/Users/Shared/git/SharedXcodeSettings/DeveloperSettings.xcconfig`

Then create a plain text file in it: `SharedXcodeSettings/DeveloperSettings.xcconfig` and
give it the contents:

```
CODE_SIGN_IDENTITY = Mac Developer
DEVELOPMENT_TEAM = <Your Team ID>
CODE_SIGN_STYLE = Automatic
ORGANIZATION_IDENTIFIER = <Your Domain Name Reversed>
DEVELOPER_ENTITLEMENTS = -dev
PROVISIONING_PROFILE_SPECIFIER =
```

Set `DEVELOPMENT_TEAM` to your Apple supplied development team.  You can use Keychain
Access to [find your development team ID](/Technotes/FindingYourDevelopmentTeamID.md).
Set `ORGANIZATION_IDENTIFIER` to a reversed domain name that you control or have made up.
Note that `PROVISIONING_PROFILE_SPECIFIER` should not have a value associated with it.

You can now open the `NetNewsWire.xccodeproj` in Xcode.

Now you should be able to build without code signing errors and without modifying
the NetNewsWire Xcode project.  This is a special build of NetNewsWire with some
functionality disabled.  This is because we have API keys that can't be stored in the
repository or shared between developers.  Certain account types, like Feedly, aren't
enabled and the Reader View isn't enabled because of this.

If you have any problems, we will help you out in Slack (see above).
