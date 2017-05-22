# RSXML

This is utility code for parsing XML and HTML using libXML2’s SAX parser.

It builds two framework targets: one for Mac, one for iOS. It does not depend on any other third-party frameworks. The code is Objective-C with ARC.

#### The gist

To parse XML, create an `RSSAXParserDelegate`. (There are examples in the framework that you can crib from.)

To parse HTML, create an `RSSAXHTMLParserDelegate`. (There are examples for this too.)

#### Goodies and Extras

There are three XML parsers included, for OPML, RSS, and Atom. To parse OPML, see `RSOPMLParser`. To parse RSS and Atom, see `RSFeedParser`.

These parsers may or may not be complete enough for your needs. You could, in theory, start writing an RSS reader just with these. (And, if you want to, go for it, with my blessing.)

There are two HTML parsers included. `RSHTMLMetadataParser` pulls metadata from the head section of an HTML document. `RSHTMLLinkParser` pulls all the links (anchors, &lt;a href=…&gt; tags) from an HTML document.

Other possibly interesting things:

`RSDateParser` makes it easy to parse dates in the formats found in various types of feeds.

`NSString+RSXML` decodes HTML entities.

Also note: there are some unit tests.

#### Why use libXML2’s SAX API?

SAX is kind of a pain because of all the state you have to manage. But it’s fastest and uses the least amount of memory.

An alternative is to use `NSXMLParser`, which is event-driven like SAX. However, RSXML was written to avoid allocating Objective-C objects except when absolutely needed. You’ll note use of things like `memcp` and `strncmp`.

Normally I avoid this kind of thing *strenuously*. I prefer to work at the highest level possible.

But my more-than-a-decade of experience parsing XML has led me to this solution, which — last time I checked, which was, admittedly, a few years ago — was not only fastest but also uses the least memory. (The two things are related, of course: creating objects is bad for performance, so this code attempts to do the minimum possible.)

All that low-level stuff is encapsulated, however. If you parse a feed, for instance, the caller gets an `RSParsedFeed` which contains `RSParsedArticle`s, and they’re standard Objective-C objects. It’s only inside your `RSSAXParserDelegate` and `RSSAXHTMLParserDelegate` where you’ll need to deal with C.