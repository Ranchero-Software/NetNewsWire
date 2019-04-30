# Syncing Implementation Roadmap

Any parts of this that are non-shared code should be done on the Mac. We’ll get iOS caught-up after syncing on the Mac is finished.

Some of this could be wrong on some details. Some things might be unanticipated by this document. It’s a start, though.

Also of note: some of this is generic sync infrastructure. Since this is the first time, we’ve got to do all that.

## Make new local accounts via Preferences

Make it so you can add second local (aka “On My Mac”) account via Preferences > Accounts on the Mac.

You should be able to change the display name of the account, and deactivate and reactivate it.

You should be able to add feeds and folders to it, and drag-and-drop within the account should work.

(Drag-and-drop *between* accounts should not work at all. We’re going to deal with that after shipping 5.0. It’s complex.)

## Make new Feedbin account via Preferences

This will need credentials. It should have a button for testing the login, to be sure it works. Username will go in AccountSettings.plist. Password goes in the keychain.

The Feedbin account should appear in the sidebar, though empty.

## General API stuff

We need some general code.

* APICall and WebServiceProvider are already in RSWeb. They’re speculative and need filling out. Decisions previously made should be revised as needed.
* APIResult has not been started yet.

APICall should be modeled on Vesper’s VSAPICall, but more general:

https://github.com/brentsimmons/Vesper/blob/master/Vesper/Classes/VSAPICall.h

https://github.com/brentsimmons/Vesper/blob/master/Vesper/Classes/VSAPICall.m

APIResult should be modeled similarly on Vesper’s VSAPIResult:

https://github.com/brentsimmons/Vesper/blob/master/Vesper/Classes/VSAPIResult.h

https://github.com/brentsimmons/Vesper/blob/master/Vesper/Classes/VSAPIResult.m

## Feedbin API Caller

There is a start of this already — data structures for values returned by Feedbin. It’s in Account.framework.

Then we need FeedbinAPICaller, which should be modeleted on Vesper’s VSAPICaller:

https://github.com/brentsimmons/Vesper/blob/master/Vesper/Classes/VSAPICaller.h

https://github.com/brentsimmons/Vesper/blob/master/Vesper/Classes/VSAPICaller.m

The idea is that we call easy-to-use methods, which then each queue up a VSAPICall on an NSOperationQueue. Or maybe just add them directly to an NSURLSession? (Maybe we don’t need an operation queue.)

(Vesper had its own home-grown queue. Let’s not repeat that: no need, I think.)

FeedbinAPICaller should have its own NSURLSession. Each FeedbinAccountDelegate will own a FeedbinAPICaller.

## Immediate syncing: subscriptions changes

NetNewsWire should download the subscriptions list from Feedbin and store that data in the normal ways. Display it in the sidebar.

When deleting a feed, moving a feed — same with folders — the sync should happen right away.

In the event of an error (network error or any other error), the change should be undone and the user notified.

This even extends to drag-and-drop within the Feedbin account in the sidebar.

This will mean adding additional communication between sidebar and Account. A SidebarAccountDelegate protocol is probably a good idea. The FeedbinAccountDelegate could also be a SidebarAccountDelegate. (Same with the LocalAccountDelegate.)

## Adding feeds

Adding a feed should call Feedbin’s API — I think Feedbin has its own feed finder mechanism. If I’m right, then it should use that.

If I’m wrong, we should find the feed and then call Feedbin to add the feed using the URL we found.

The same is true of importing OPML: if Feedbin has an import-OPML endpoint, then we should call that.

Otherwise we have to parse the OPML, then add each feed/folder to Feedbin, then download the subscriptions list from Feedbin.

## Downloading articles

This should be done periodically, as per prefs on refresh interval.

As part of the periodic refresh, NetNewsWire should download the subscriptions list and catch up on any queued syncing not-yet-done.

## Queued syncing: article status

Changes to article status should be synced periodically quite often. We never want to drift far from the source of truth.

But we should support the possibility that a person is without internet and just wants to read. They can’t add feeds or change their subscriptions list, but they can read articles (which marks them as read) and do all other operations which affect article status.

Changes should be stored in a queue, and the queue should persist between runs. The queue should be in a SQLite database, and we should use FMDB and RSDatabase to manipulate the database.

This database queue should be stored alongside other data for the account (same folder).

I think the best way is to have two tables: readStatus and starredStatus.

Each table has two columns: feedbin article ID and a `state` Boolean.

Then, when updating Feedbin, grab what you need from the database and make the call. On success, delete those items from the database.

Some care must be taken here: while the call is in progress, the queue could be updated behind your back. So, when deleting, don’t just delete those article IDs — also be sure the `state` column matches.

## Progress indicator

The progress indicator when refreshing will need to take into some sync calls. During a sync/refresh it should count calls to Feedbin that have to do with syncing subscriptions and downloading articles. It should not count calls dealing with article status.

## AppleScript support

Anything having to do with subscriptions is going to be a bit weird, because it involves a round trip to Feedbin. Let’s figure this out after everything else is done.