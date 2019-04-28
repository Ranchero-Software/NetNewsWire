# Accounts

NetNewsWire supports multiple accounts. See the Account framework for the implementation.

The local account — aka “On My Mac” or “On My iPhone” — reads feeds directly and has no syncing. Other accounts connect to a syncing service, such as Feedbin, Feedly, and so on.

There is always a default local account. It may be empty — no feeds or folders — but it still exists.

People can create multiple accounts of any type. More than one local account is permitted. More than one Feedbin account is permitted (provided the actual Feedbin account is different for each one). Etc.

The data for a given account is part of the account. Refreshing and syncing is the responsibility of each account.

## Where people manage accounts

Accounts are created and managed in Preferences > Accounts on the Mac and in a corresponding place in the iOS version.

The user interface, especially on the Mac, is much like the UI in Mail for account management.

## The Account class

Each account is an instance of the Account class. The Account class may not be subclassed — instead, there’s an AccountDelegate protocol to implement for custom behavior. (See LocalAccountDelegate for an example.)

It’s likely that the AccountDelegate may need to be extended to support the various syncing systems.

## Where data is stored

Except for app-level prefs and temporary caches, all NetNewsWire data is stored in `~/Library/Application Support/NetNewsWire/Accounts/`. (On the Mac, and in a similar location on iOS.)

The default local account has an OnMyMac folder. All other accounts should use a UUID as their identifier, and the folder name should use that UUID. (Not pretty, but it works.)

Inside each account folder should be four things:

1. AccountSettings.plist — stores settings the account needs. This includes the UUID of the account and the person’s username. (The default local account doesn’t yet do this, at this writing (29 April 2019), but it should.)
2. DB.sqlite3 — stores article data and article statuses.
3. FeedMetadata.plist — stores feed attributes that don’t belong in a traditional OPML file.
4. Subscriptions.opml — a traditional OPML file listing the accounts feeds and folders.

A syncing account will almost certainly need to store more things. It’s up the individual account what those should be, though it would be good to have conventions and even shared code between the various syncing systems. One thing that will surely be needed: a database-backed queue for article status changes. (More on that in another technote).

In addition, FeedMetadata.plist isn’t limited to what’s in there now: adding more feed metadata is encouraged (as long as it’s not large) to support syncing. (See the FeedMetadata class.)

Same with AccountSettings.plist — it should be extended to hold whatever is needed for syncing (as long as it’s small data).

## ArticlesDatabase

Each account has their own ArticlesDatabase, which is what manages DB.sqlite3.

There will certainly have to be modifications to support syncing systems, but hopefully those will be small. The goal is to avoid creating multiple database implementations *and* avoid making ArticlesDatabase overly-complex.

It’s possible we may have to create a delegate for it, to handle specific behavior, but we hope not.

## Secure info

While a person’s username will be stored in AccountSettings.plist, a person’s password, and any other information that needs security, should be stored in the Keychain as a NetNewsWire-specific item.

## Account loading at startup

The AccountManager class loads the accounts at startup by looping through the folder in Accounts/ and creating an Account for each one. There is no separate list of accounts.

## Account deletion

When a user deletes an account, a serious confirmation must be displayed, because account deletion deletes the data on disk for that account.

Accounts may be made inactive, instead. The data remains, but AccountSettings.plist will note that the account is inactive, and it will be treated as if it were gone, but the data will remain on disk and the account will still be displayed in the accounts management UI.