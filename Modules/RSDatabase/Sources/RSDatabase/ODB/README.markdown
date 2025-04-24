# ODB

**NOTE**: This all has been excluded from building. It’s a work in progress, not ready for use.

ODB stands for Object Database.

“Object” doesn’t mean object in the object-oriented programming sense — it just means *thing*.

Think of the ODB as a nested Dictionary that’s *persistent*. It’s schema-less. Tables (which are like dictionaries) can contain other tables. It’s all key-value pairs.

The inspiration for this comes from [UserLand Frontier](http://frontier.userland.com/), which featured an ODB which made persistence for scripts easy.

You could write a script like `user.personalInfo.name = "Bull Mancuso"` — and, inside the `personalInfo` table, which is inside the `user` table, it would create or set a key/value pair: `name` would be the key, and `Bull Mancuso` would be the value.

Looking up the value later was as simple as referring to `user.personalInfo.name`.

This ODB implementation does *not* provide that scripting language. It also does not provide a user interface for the database (Frontier did). It provides just the lowest level: the actual storage and a Swift API for getting, setting, and deleting tables and values.

It’s built on top of SQLite. It may sound weird to build an ODB on top of a SQL database — but SQLite is amazingly robust and fast, and it’s the hammer I know best.

My hunch is that lots of apps could benefit from this kind of storage. It was the *only* kind I used for seven years in my early career, and we wrote lots of powerful software using Frontier’s ODB. (Blogging, RSS, podcasting, web services over HTTP, OPML — all these were invented or popularized or fleshed-out using Frontier and its ODB. Not that I take personal credit: I was an employee of UserLand Software, and the vision was Dave Winer’s.)

## How to use it

### Create an ODB

`let odb = ODB(filepath: somePath)` creates a new ODB for that path. If there’s an existing database on disk, it uses that one. Otherwise it creates a new one.

### Ensuring that a table exists

Let’s say you’re writing an RSS reader, and you want to make sure there’s a table at `RSS.feeds.[feedID]`. Given feedID and odb:

	let pathElements = ["RSS", "feeds", feedID]
	let path = ODBPath(elements: pathElements, odb: odb)
	ODB.perform {
		let _ = path.ensureTable()
		}

The `ensureTable` function returns an `ODBTable`. It makes sure that the entire path exists. The only way `ensureTable` would return nil is if something in the path exists and it’s a value instead of a table. `ensureTable` never deletes anything. 

There is a similar `createTable` function that deletes any existing table at that path and then creates a new table. It does *not* ensure that the entire path exists, and it returns nil if the necessary ancestor tables don’t exist.

Operations referencing `ODBTable` and `ODBValueObject` must be enclosed in an `ODB.perform` block. This is for thread safety. If you don’t use an `ODB.perform` block, it will crash deliberately with a `preconditionFailure`.

You should *not* hold a reference to an `ODBTable`, `ODBValueObject`, or `ODBObject` outside of the `perform` block. You *can* hold a reference to an `ODBPath` and to an `ODBValue`.

An `ODBObject` is either an `ODBTable` or `ODBValueObject`: it’s a protocol.

### Setting a value

Let’s say the user of your RSS reader can edit the name of a feed, and you want to store the edited name in the database. The key for the value is `editedName`. Assume that you’ve already used `ensureTable` as above.

	let path = ODBPath(elements: ["RSS", "feeds", feedID, "editedName"], odb: odb)
	let value = ODBValue(value: name, primitiveType: .string, applicationType: nil)
	ODB.perform {
		path.setValue(value)
	}

If `editedName` exists, it gets replaced. If it doesn’t exist, then it gets created.

(Yes, this would be so much easier in a scripting language. You’d just write: `RSS.feeds.[feedID].editedName = name` — the above is the equivalent of that.)

See `ODBValue` for the different types of values that can be stored. Each value must be one of a few primitive types — string, date, data, etc. — but each value can optionally have its own `applicationType`. For instance, you might store OPML text as a string, but then give it an `applicationType` of `"OPML"`, so that your application knows what it is and can encode/decode properly. This lets you store values of any arbitrary complexity.

In general, it’s good practice to use that ability sparingly. When you can break things down into simple primitive types, that’s best. Treating an entire table, with multiple stored values, as a unit is often the way to go. But not always.

### Getting a value

Let’s say you want to get back the edited name of the feed. You’d create the path the same way as before. And then:

	var nameValue: ODBValue? = nil
	ODB.perform {
		nameValue = path.value
	}
	let name = nameValue? as? String

The above is written to demonstrate that you can refer to `ODBValue` outside of a `perform` call. It’s an immutable struct with no connection to the database. But in reality you’d probably write the above code more like this:

	var name: String?
	ODB.perform {
		name = path.value? as? String
	}

It’s totally a-okay to use Swift’s built-in types this way instead of checking the ODBValue’s `primitiveType`. The primitive types map directly to `Bool`, `Int`, `Double`, `Date`, `String`, and `Data`.

### Deleting a table or value

Say the user undoes editing the feed’s name, and now you want to delete `RSS.feeds.[feedID].editedName` — given the path, you’d do this:

	ODB.perform {
		path.delete()
	}

This works on both tables and values. You can also call `delete()`  directly on an `ODBTable`, `ODBValueObject`, or `ODBObject`.

### ODBObject

Some functions take or return an `ODBObject`. This is a protocol — the object is either an `ODBTable` or `ODBValueObject`.

There is useful API to be aware of in ODBObject.swift. (But, again, an `ODBObject` reference is valid only with an `ODB.perform` call.)

### ODBTable

You can do some of the same things you can do with an `ODBPath`. You can also get the entire dictionary of `children`, look up any child object, delete all children, add child objects, and more.

### ODBValueObject

You won’t use this directly all that often. It wraps an `ODBValue`, which you’ll use way more often. The useful API for `ODBValueObject` is almost entirely in `ODBObject`.

## Notes

### The root table

The one table you can’t delete is the root table — every ODB has a top-level table named `root`. You don’t usually specify `root` as the first part of a path, but you could. It’s implied.

A path like `["RSS", "feeds"]` is precisely the same as `["root", "RSS", "feeds"]` — they’re interchangeable paths.

### Case-sensitivity

Frontier’s object database was case-insensitive: you could refer to the "feeds" table as the "FEeDs" table — it would be the same thing.

While I don’t know this for sure, I assume this was because the Mac’s file system is also case-insensitive. This was considered one of the user-friendly things about Macs.

We’re preserved this: this ODB is also case-insensitive. When comparing two keys it always uses the English locale, so that results are predictable no matter what the machine’s locale actually is. This is something to be aware of.

### Caching and Performance

The database is cached in memory as it is used. A table’s children are not read into memory until referenced.

For objects already in memory, reads are fast since there’s no need to query the SQLite database.

If this caching becomes a problem in production use — if it tends to use too much memory — we’ll make it smarter.

### Thread safety

Why is it okay to create and refer to `ODBPath` and `ODBValue` objects outside of an `ODB.perform` call, while it’s not okay with `ODBObject`, `ODBTable`, and `ODBValueObject`?

Because:

`ODBPath` represents a *query* rather than a direct reference. Each time you resolve the object it points to, it recalculates. You can create paths to things that don’t exist. The database can change while you hold an `ODBPath` reference, and that’s okay: it’s by design. Just know that you might get back something different every time you refer to `path.object`, `path.value`, and `path.table`.

`ODBValue` is an immutable struct with no connection to the database. Once you get one, it doesn’t change, even if the database object it came from changes. (In general these will be short-lived — you just use them for wrapping and unwrapping your app’s data.)

On the other hand, `ODBObject`, `ODBTable`, and `ODBValueObject` are direct references to the database. To prevent conflicts and maintain the structure of the database properly, it’s necessary to use a lock when working with these — that’s what `ODB.perform` does.

Say you have a particular table that your app uses a lot. It would seem natural to want to keep a reference to that particular `ODBTable`. Instead, create and keep a reference to an `ODBPath` and refer to `path.table` inside an `ODB.perform` block when you need the table.



