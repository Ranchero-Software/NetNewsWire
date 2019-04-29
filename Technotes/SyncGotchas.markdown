# Possible Gotchas To Be Aware Of When Working on Syncing

## Accounts and the local account

NetNewsWire was written to support multiple accounts.

However, there may be places where the code assumes the local account, when really it needs to refer to a specific account. These references should be checked.

However however, there are times when assuming the local account is actually correct — such as when importing the default feeds on the first run.

## Feed ID vs. Feed URL

With the local account, a feed’s ID and its URL are the same thing.

With syncing systems, a feed’s ID will often be completely different from its URL. (It might be a UUID, it might be a hash of something, it might be a database row ID.)

There are times when the code should refer to the ID and times when it should refer to the URL. Did we get it wrong sometimes? Possibly. Hopefully not, but possibly.

Also: if the syncing system uses an integer for a feed’s ID, it should be converted to a string in NetNewsWire. This is what the database is expecting — because a string is the most flexible representation and can handle whatever the various systems use.

