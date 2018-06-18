# Database Cleanup

Old articles and statuses are removed after a certain period of time.

(This applies to the OnMyMac account only. Other syncing systems have their own rules, and the app should follow them.)

We do this so that the database doesn’t just grow forever. Because the bigger it gets, the slower it gets.

The cleanup process is run at app launch, before other reads and writes. It should be fast enough that it goes unnoticed by the user.

Articles are deleted first, then statuses.

## Articles

All articles whose feed is no longer in the subscriptions list are deleted.

A cut-off date of 4 * 31 days ago is calculated.

For the remaining articles, we go feed-by-feed.

If a feed has 20 or fewer articles, it’s left alone.

For each article (oldest first) delete until:
  The feed’s count of articles is down to 20,
  or the article is newer than the cut-off date.

The reason we preserve some articles that would otherwise be deleted: you want to be able to select a feed that hasn’t been updated in a year (or whatever long period of time) and still articles from that feed.

## Statuses

Statuses older than five months (see statuses.dateArrived) with no matching articleID in articles are deleted.

