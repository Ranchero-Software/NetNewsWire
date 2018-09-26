CREATE TABLE if not EXISTS articles (articleID TEXT NOT NULL PRIMARY KEY, feedID TEXT NOT NULL, uniqueID TEXT NOT NULL, title TEXT, contentHTML TEXT, contentText TEXT, url TEXT, externalURL TEXT, summary TEXT, imageURL TEXT, bannerImageURL TEXT, datePublished DATE, dateModified DATE);

CREATE TABLE if not EXISTS statuses (articleID TEXT NOT NULL PRIMARY KEY, read BOOL NOT NULL DEFAULT 0, starred BOOL NOT NULL DEFAULT 0, userDeleted BOOL NOT NULL DEFAULT 0, dateArrived DATE NOT NULL DEFAULT 0);

CREATE TABLE if not EXISTS authors (authorID TEXT NOT NULL PRIMARY KEY, name TEXT, url TEXT, avatarURL TEXT, emailAddress TEXT);
CREATE TABLE if not EXISTS authorsLookup (authorID TEXT NOT NULL, articleID TEXT NOT NULL, PRIMARY KEY(authorID, articleID));

CREATE TABLE if not EXISTS attachments(attachmentID TEXT NOT NULL PRIMARY KEY, url TEXT NOT NULL, mimeType TEXT, title TEXT, sizeInBytes INTEGER, durationInSeconds INTEGER);
CREATE TABLE if not EXISTS attachmentsLookup(attachmentID TEXT NOT NULL, articleID TEXT NOT NULL, PRIMARY KEY(attachmentID, articleID));

CREATE INDEX if not EXISTS articles_feedID_datePublished_articleID on articles (feedID, datePublished, articleID);

CREATE INDEX if not EXISTS statuses_starred_index on statuses (starred);
