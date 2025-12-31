# NetNewsWire Privacy Policy

This policy describes the information Brent Simmons may receive from NetNewsWire users and how that information is handled.

There are two things we do:

* We gather crash logs from NetNewsWire users who opt in.
* We log traffic to our website, which we view in aggregate.

In other words, we don’t want any private information. We really, really don’t — it’s of zero use to us and it would be a burden to have to store it securely.

But we do want to do two things: 1) identify and fix crashing bugs, and 2) find out how many people are visiting our website and see which pages are more or less popular.

Details on these, and other privacy topics, are below.

## Crash Logs

If you opt in to sending crash logs, we will have a copy of your crash logs.

* If you’re using an App Store version of the app, and you opt in with Apple, then Apple has a copy and we have a copy.
* If you’re using a Mac version downloaded directly from us, and you opt in, then it’s just us.

When NetNewsWire for Mac sends a crash log directly to us, it sends only the text of the crash log. No additional information, such as email address, is sent (though our website logging system — see below — will record some information, including time and IP address).

Crash logs are stored privately and are kept confidential.

However, we may make all or significant parts of a crash log available publicly when there‘s no personal identification in that part of the crash log.

We might make all of a crash log available (again, if there’s no personal identification), or just part — something like this:

	Thread 0 Crashed:: Dispatch queue: com.apple.main-thread
	0   libsystem_secinit.dylib       	0x00007fff6c06689f _libsecinit_setup_secinitd_client + 1393
	1   libsystem_secinit.dylib       	0x00007fff6c0662cd _libsecinit_initialize_once + 13
	2   libdispatch.dylib             	0x00007fff6be17dcf _dispatch_client_callout + 8
	3   libdispatch.dylib             	0x00007fff6be19515 _dispatch_once_callout + 20
	4   libsystem_secinit.dylib       	0x00007fff6c0662be _libsecinit_initializer + 79
	5   libSystem.B.dylib             	0x00007fff692639d4 libSystem_initializer + 136

This is entirely for the purpose of fixing crashing bugs.

## Website Logging

Visits to our website — including downloads of the app and of our RSS feeds (including the app-update feed) — are logged via a standard logging mechanism, and this includes IP addresses.

Our website logs are confidential and stored privately.

We look at the logs in aggregate — for instance, to find how many times NetNewsWire was downloaded on a given day.

## Other topics

### No Cookies, JavaScript, Trackers, Ads

Neither netnewswire.com nor inessential.com (Brent’s blog) use any cookies, JavaScript, or trackers, and they do not display any ads.

### Related sites

The [NetNewsWire GitHub repository](https://github.com/Ranchero-Software/NetNewsWire) does use cookies and JavaScript, because that’s how GitHub works. The repository, including the issue tracker and anything you post there, is public. See [GitHub’s privacy policy](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement) for more information.

The [NetNewsWire Discourse forum](https://discourse.netnewswire.com/) also uses cookies and JavaScript, because that’s how Discourse works. The group is public: anyone may join. (TODO: create a privacy policy for the Discourse forum. Short version: it’s membership-based, which means you have to create an account, and it collects information that it needs for functionality. It’s hosted by us, which means nobody else has access to that data. And we don’t use it for anything else and never would.)

Posting to the GitHub repository and joining the Discourse forum are optional, opt-in activities.

### Content in NetNewsWire

NetNewsWire displays HTML that comes from feeds from other sites. Some of these sites may do some kind of analytics so that, for instance, they can count how many times a given article in an RSS feed has been read. Refer to the privacy policies of the individual sites for more information.

## Questions or comments

If you have questions or comments about this privacy policy, please contact Brent Simmons on the [Slack group](https://netnewswire.com/slack) or on [Mastodon](https://indieweb.social/@brentsimmons).

This [policy](https://github.com/brentsimmons/NetNewsWire/blob/master/Technotes/privacypolicy.markdown) is stored in the NetNewsWire GitHub repository, where you can track any changes we might make.
