# RSDatabase
This is utility code for using SQLite via FMDB. It’s not a persistence framework — it’s lower-level.

It builds as a couple frameworks — one for Mac, one for iOS.

It has no additional dependencies, but that’s because FMDB is actually included — you might want to instead make sure you have the [latest FMDB](https://github.com/ccgus/fmdb), which isn’t necessarily included here.

#### What to look at

The main thing is `RSDatabaseQueue`, which allows you to talk to SQLite-via-FMDB using a serial queue.

The second thing is `FMDatabase+RSExtras`, which provides methods for a bunch of common queries and updates, so you don’t have to write as much SQL.
