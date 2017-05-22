# RSWeb

RSWeb is utility code — all Swift — for downloading things from the web. It builds a Mac framework and an iOS framework.

#### Easy way

See `OneShotDownload` for a top-level `download` function that takes a URL and a callback. The callback takes `Data`, `URLResponse`, and `Error` parameters. It’s easy.

#### Slightly less easy way

See `DownloadSession` and `DownloadSessionDelegate` for when you’re doing a bunch of downloads and you need to track progress.

#### Extras

`HTTPConditionalGetInfo` helps with supporting conditional GET, for when you’re downloading things that may not have changed. See [HTTP Conditional Get for RSS Hackers](http://fishbowl.pastiche.org/2002/10/21/http_conditional_get_for_rss_hackers/) for more about conditional GET. This is especially critical when polling for changes, such as with an RSS reader.

`MimeType` could use expansion, but is useful for some cases right now.

`MacWebBrowser` makes it easy to open a URL in the default browser. You can specify whether or not to open in background.