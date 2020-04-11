# Retention Policy

This is a user interface issue, primarily — what articles should be displayed to the user?

This article answers that question, and it describes how the decisions are implemented.

And, at the end, there’s a special note about why we have limits at all.

## Web-Based Sync Systems

When used with Feedbin, Feedly, and other syncing systems, NetNewsWire should show the same unread articles that the user would see in the browser-based version. (The unread counts would necessarily be the same in NetNewsWire and on the web.)

It should also show the exact same starred items.

It does *not* have to show the exact same read items. Instead, it will show read items that arrived locally in the last 90 days.

### Database Queries

Most queries for articles should include this logic:

* If an article is userDeleted, don’t show it
* If an article is starred or unread, show it no matter what
* If an article is read, and status.dateArrived < 90 days ago, then show it

### Database Cleanup

Database cleanups to do at startup:

* Delete articles from feeds no-longer-subscribed-to, unless starred
* Delete read/not-starred articles where status.dateArrived > 90 days go (because these wouldn’t be shown in the UI)
* Delete statuses where status is read, not starred, and not userDeleted, and dateArrived > 180 days ago, and the associated article no longer exists in the articles table.

We keep statuses a bit longer than articles, in case an article comes back. But we don’t keep most statuses forever.

## Local and iCloud Accounts

NetNewsWire should show articles that are currently in the feed. When an article drops off the feed, it no longer displays in the UI.

The one exception is starred articles: as with sync systems, starred articles are kept forever.

### Database Queries

Most queries for articles should include this logic:

* If an article is userDeleted, don’t show it
* If an article is starred, show it no matter what

### Database Cleanup

Database cleanups to do while running:

* When processing a feed, delete articles that no longer appear in the feed — unless a feed comes back empty (with zero articles); do nothing in that case

Database cleanups to do at startup:

* Delete articles from feeds no-longer-subscribed-to, unless starred
* Delete statuses where not starred, not userDeleted, and dateArrived > 30 days ago, and the associated article no longer exists in the articles table.

We keep statuses a bit longer than articles, in case an article comes back. (An article could come back when, for example, a publisher reconfigures their feed so that it includes more items. This could bring back articles that had previously fallen off the feed.)

## Why Do We Have Limits At All?

Most people don’t want NetNewsWire to just keep holding on to everything forever, but a few people do.

And that’s understandable. It’s pretty cool to have a personal backup of your favorite parts of the web. It’s great for researchers, journalists, and bloggers.

But the more articles we keep, the larger the database gets. It’s already not unusual for a database to become 1GB in size — but we can’t let it grow to many times that, because it will:

* Make NetNewsWire unacceptably slow
* Take up an inordinate amount of disk space

So we need to have limits. The point of NetNewsWire is to keep up with what’s new: it’s *not* an archiving system. So we’ve defined “what’s new” expansively, but not so expansively that we don’t have a definition for “what’s old.”
