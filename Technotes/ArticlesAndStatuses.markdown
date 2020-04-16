# Why Articles and Statuses Are Separate Tables

An `Article` is an immutable struct; an `ArticleStatus` is a mutable object.

In the database (see ArticlesDatabase), they’re stored in two separate tables: `articles` and `statuses`.

The articles table contains the columns you’d expect: `articleID`, `title`, `contentHTML`, and so on.

The statuses table contains `articleID`, `read`, `starred`, and `dateArrived` columns.

This separation is deliberate. There are two main reasons: syncing, and strange behavior.

## Syncing

When syncing with another service, it’s entirely likely that the service will report article status information in calls that are separate from calls to retrieve articles.

Thus the app might learn about statuses for articles it hasn’t seen yet.

This way the app can store those statuses without having to have their corresponding articles. And then, when the app does download those articles, it has their statuses already in the database.

## Strange Behavior

The articles database periodically deletes old articles that have been read. (In theory. This code has still to be written at this date (28 April 2019).)

However, it retains old statuses for a considerably longer period of time.

The reason for this is the following strange behavior:

* An article with no pubDate appears in a feed.
* Many months pass, and the article is deleted from the database.
* That exact article re-appears in the feed.

With the article deleted — and since it has no pubDate — how can the app tell if this is a new or old article?

Here’s how: it still has the status, and the status includes a `dateArrived` property which is in the distant past — and so NetNewsWire knows that it’s not new but old.

Note that statuses do get deleted eventually, too (in theory) — but that’s after a much longer period of time.
