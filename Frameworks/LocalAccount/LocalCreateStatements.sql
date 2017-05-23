/*articleID is a hash of [something]+feedID. When there's a guid, [something] is a guid. Otherwise it's a combination of non-null properties.*/

CREATE TABLE if not EXISTS articles (articleID TEXT NOT NULL PRIMARY KEY, feedID TEXT NOT NULL, guid TEXT, title TEXT, body TEXT, datePublished DATE, dateModified DATE, link TEXT, permalink TEXT, author TEXT);

CREATE TABLE if not EXISTS statuses (articleID TEXT NOT NULL PRIMARY KEY, read BOOL NOT NULL DEFAULT 0, starred BOOL NOT NULL DEFAULT 0, userDeleted BOOL NOT NULL DEFAULT 0, dateArrived DATE NOT NULL DEFAULT 0);

/*Indexes*/

CREATE INDEX if not EXISTS feedIndex on articles (feedID);
