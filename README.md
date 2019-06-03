# NetNewsWire

It’s a free and open source feed reader for macOS.

It’s not in beta yet. Not even alpha! While NetNewsWire 5.0 is feature-complete as of May 25, 2019, it has known bugs — and, surely, plenty of unknown bugs.

It supports [RSS](http://cyber.harvard.edu/rss/rss.html), [Atom](https://tools.ietf.org/html/rfc4287), [JSON Feed](https://jsonfeed.org/), and [RSS-in-JSON](https://github.com/scripting/Scripting-News/blob/master/rss-in-json/README.md) formats.

More info: [https://ranchero.com/netnewswire/](https://ranchero.com/netnewswire/)

Also see the [Technotes](Technotes/) and the [Roadmap](Technotes/Roadmap.md).

Note: NetNewsWire’s Help menu has a bunch of these links, so you don’t have to remember to come back to this page.

#### Community

[Join the Slack group](https://join.slack.com/t/netnewswire/shared_invite/enQtNjM4MDA1MjQzMDkzLTNlNjBhOWVhYzdhYjA4ZWFhMzQ1MTUxYjU0NTE5ZGY0YzYwZWJhNjYwNTNmNTg2NjIwYWY4YzhlYzk5NmU3ZTc) to talk with other NetNewsWire users — and to help out, if you’d like to, by testing, coding, writing, providing feedback, or just helping us think things through. Everybody is welcome and encouraged to join.

#### On accepting pull requests

It’s pretty early still, and we have strong opinions about how we want to do things, so we’re not seeking help just yet.

That said, we will seriously consider any pull requests we do get. Just note that we may not accept them, or we may accept them and do a bunch of revision.

It’s probably a good idea to let us know first what you’d like to do. The best place for that is definitely the [Slack group](https://join.slack.com/t/netnewswire/shared_invite/enQtNjM4MDA1MjQzMDkzLTNlNjBhOWVhYzdhYjA4ZWFhMzQ1MTUxYjU0NTE5ZGY0YzYwZWJhNjYwNTNmNTg2NjIwYWY4YzhlYzk5NmU3ZTc).

We do plan to add more and more contributors over time. Totally. But we’re taking it slow as we learn how to manage an open source project.

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

As an example, make a `../../SharedXcodeSettings/DeveloperSettings.xcconfig` file and
give it the contents

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
