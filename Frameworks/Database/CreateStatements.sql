CREATE TABLE if not EXISTS articles (articleID TEXT NOT NULL PRIMARY KEY, feedID TEXT NOT NULL, uniqueID TEXT NOT NULL, title TEXT, contentHTML TEXT, contentText TEXT, url TEXT, externalURL TEXT, summary TEXT, imageURL TEXT, bannerImageURL TEXT, datePublished DATE, dateModified DATE, accountInfo BLOB);

CREATE TABLE if not EXISTS statuses (articleID TEXT NOT NULL PRIMARY KEY, read BOOL NOT NULL DEFAULT 0, starred BOOL NOT NULL DEFAULT 0, userDeleted BOOL NOT NULL DEFAULT 0, dateArrived DATE NOT NULL DEFAULT 0, accountInfo BLOB);

CREATE TABLE if not EXISTS authors (authorID TEXT NOT NULL PRIMARY KEY, name TEXT, url TEXT, avatarURL TEXT, emailAddress TEXT);
CREATE TABLE if not EXISTS authorLookup (authorID TEXT NOT NULL, articleID TEXT NOT NULL, PRIMARY KEY(authorID, articleID));

CREATE TABLE if not EXISTS tags(tagName TEXT NOT NULL, articleID TEXT NOT NULL, PRIMARY KEY(tagName, articleID));

CREATE TABLE if not EXISTS attachments(articleID TEXT NOT NULL, url TEXT NOT NULL, mimeType TEXT, title TEXT, sizeInBytes INTEGER, durationInSeconds INTEGER, PRIMARY KEY(articleID, url));

CREATE INDEX if not EXISTS feedIndex on articles (feedID);

CREATE INDEX if not EXISTS tags_tagName_index on tags(tagName COLLATE NOCASE);

