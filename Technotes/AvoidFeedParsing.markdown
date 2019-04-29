# How NetNewsWire Avoids Parsing Feeds

NetNewsWire’s code for reading feeds directly — not via a syncing system like Feedbin or Feedly) — does its best to avoid parsing feeds.

Here’s the thing: parsing a feed means not just parsing the feed, it also means comparing the parsed version to what’s in the database. This is all *work*, and part of performing well is to avoid work.

Here’s what it does:

## Conditional GET

I can’t stress this strongly enough. When downloading a feed, NetNewsWire sends the appropriate headers to give the server a chance to respond with 304 Not Modified.

It’s quite simple — read The Fishbowl’s [HTTP Conditional Get for RSS Hackers](https://fishbowl.pastiche.org/2002/10/21/http_conditional_get_for_rss_hackers) (from way back in 2002!) for how this works.

This is such a great thing! It means less bandwidth uses, less energy consumed, etc.

Unfortunately, not every server implements the server side of Conditional GET. (Boo.) So we have a second method of avoiding work.

## Feed Content Hashing

When NetNewsWire parses a feed, it creates a hash — MD5 is fine for this sort of thing — of the content of the feed.

It stores that hash along with other feed metadata.

The next time it downloads the feed, it generates a hash of the just-downloaded copy. If the new hash matches the old hash, then the feed hasn’t changed, and we skip parsing it. Yay!

## Additional Fallbacks

NetNewsWire also looks at the content of the feed. If it’s definitely an image and not an RSS feed, for instance, it doesn’t attempt to parse it.

Yes, this kind of thing happens in the real world: I’ve seen it. (Once I even saw a feed URL return a movie file.)

We could do more here, but it’s not often an issue, so it’s not a high priority. Just a good-to-have.

## Thing It Never Does

Feeds sometimes contain dates for modification times. NetNewsWire doesn’t trust these at all. In-feed dates are *never* used for making any decisions about parsing or not.

When an article has a modification date, that date is stored in the database. But it’s there only in case it should be shown to the user. (Sometimes articles in a feed have a modification date but not a publication date — why oh why? — and in that case we display the modification date.)
