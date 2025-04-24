# Accounts

NetNewsWire supports multiple accounts. See the Account framework for the implementation.

The local account — aka “On My Mac” or “On My iPhone” — reads feeds directly and has no syncing. Other accounts connect to a syncing service, such as Feedbin, Feedly, and so on. The iCloud account reads feeds directly (like the local account) and syncs via iCloud.

There is always a default local account. It may be empty — no feeds or folders — but it still exists.

People can create multiple accounts of any type (except for iCloud). More than one local account is permitted. More than one Feedbin account is permitted (provided the actual Feedbin account is different for each one). Etc.

The data for a given account is part of the account. Refreshing and syncing is the responsibility of each account.

## Where people manage accounts

Accounts are created and managed in Settings > Accounts on the Mac and in a corresponding place in the iOS version.

The user interface, especially on the Mac, is much like the UI in Mail for account management.

## The Account class

Each account is an instance of the Account class. The Account class may not be subclassed — instead, there’s an AccountDelegate protocol to implement for custom behavior. (See LocalAccountDelegate for an example.)

## Where data is stored

Except for app-level prefs and temporary caches, all NetNewsWire data is stored in `~/Library/Containers/com.ranchero.NetNewsWire-Evergreen/Data/Library/Application Support/NetNewsWire/Accounts`. (On the Mac, and in a similar location on iOS.) (The absurdly long path is due to sandboxing.)

The default local account has an OnMyMac folder. All other accounts use a UUID as their identifier, and the folder name uses that UUID. (Not pretty, but it works.)

Inside each account folder are these four things (at a minimum):

1. Settings.plist — stores settings the account needs
2. DB.sqlite3 — stores article data and article statuses
3. FeedMetadata.plist — stores feed attributes that don’t belong in a traditional OPML file
4. Subscriptions.opml — a traditional OPML file listing the accounts feeds and folders

A syncing account will usually also include a Sync.sqlite3 file which contains sync info.

## ArticlesDatabase

Each account has their own ArticlesDatabase instance, which manages DB.sqlite3.

## Secure info

While a person’s username may be stored in AccountSettings.plist, a person’s password, and any other information that needs security, is stored in the Keychain as a NetNewsWire-specific item.

## Account loading at startup

The AccountManager class loads the accounts at startup by looping through the folder in Accounts/ and creating an Account for each one. There is no separate list of accounts.

## Account deletion

When a user deletes an account, a serious confirmation is displayed, because account deletion deletes the data on disk for that account.

Accounts may be made inactive, instead. The data remains, but AccountSettings.plist will note that the account is inactive, and it will be treated as if it were gone, but the data will remain on disk and the account will still be displayed in the accounts management UI.
