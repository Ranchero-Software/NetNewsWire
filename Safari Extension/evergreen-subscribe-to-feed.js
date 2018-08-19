// Prevent injecting the JavaScript in IFRAMES, and from acting before Safari is ready...
if ((window.top === window) && 	(typeof safari != 'undefined') && (document.location != null)) {
	document.addEventListener("DOMContentLoaded", function(event) {
		if (window.top === window)
		{
			var thisPageLinkObjects = null;

			// I convert the native "link" node into an object that I can pass out to the global page
			function objectFromLink(theLink)
			{
				var linkObject = new Object();

				linkObject.href = theLink.href;
				linkObject.type = theLink.type;
				linkObject.title = theLink.title;

				return linkObject;
			}

			// Some sites will list feeds with inappropriate or at least less-than-ideal information
			// in the MIME type attribute. We cover some edge cases here that allow to be passed through,
			// where they will successfully open as "feed://" URLs in the browser.
			function isValidFeedLink(theLink)
			{
				var isValid = false;

				switch (theLink.type)
				{
					case "application/atom+xml":
					case "application/x.atom+xml":
					case "application/rss+xml":
						// These types do not require other criteria.
						isValid = (theLink.href != null);

					case "text/xml":
					case "application/rdf+xml":
						// These types require a title that has "RSS" in it.
						if (theLink.title && theLink.title.search(/RSS/i) != -1)
						{
							isValid = (theLink.href != null);
						}
				}

				return isValid;
			}

			function scanForSyndicationFeeds()
			{
				// In case we don't find any, we establish that we have at least tried by setting the
				// variables to empty instead of null.
				thisPageLinkObjects = []

				thisPageLinks = document.getElementsByTagName("link");

				for (thisLinkIndex = 0; thisLinkIndex < thisPageLinks.length; thisLinkIndex++)
				{
					var thisLink = thisPageLinks[thisLinkIndex];
					var thisLinkRel = thisLink.getAttribute("rel");
					if (thisLinkRel == "alternate")
					{
						if (isValidFeedLink(thisLink))
						{
							thisPageLinkObjects.push(objectFromLink(thisLink));
						}
					}
				}
			}

			function subscribeToFeed(theFeed)
			{
				// Convert the URL to a feed:// scheme because Safari
				// will refuse to load e.g. a feed that is listed merely
				// as "text/xml". We do some preflighting of the link rel
				// in the PageLoadEnd.js so we can be more confident it's a
				// good feed: URL.
				var feedURL = theFeed.href;
				if (feedURL.match(/^http[s]?:\/\//))
				{
					feedURL = feedURL.replace(/^http[s]?:\/\//, "feed://");
				}
				else if (feedURL.match(/^feed:/) == false)
				{
					feedURL = "feed:" + feedURL;
				}

				safari.extension.dispatchMessage("subscribeToFeed", { "url": feedURL });
			}

			safari.self.addEventListener("message", function(event)
			{
				if (event.name === "toolbarButtonClicked")
				{
					// Workaround Radar #31182842, in which residual copies of our
					// app extension may remain loaded in context of pages in Safari,
					// causing multiple responses to broadcast message about toolbar
					// button being clicked. In the case of the "extra" injections,
					// the document location is null, so we can avoid doing on anything.
					if ((document.location != null) && (thisPageLinkObjects.length > 0))
					{
						feedToOpen = thisPageLinkObjects[0];
						subscribeToFeed(feedToOpen);
					}
				}										 
				else if (event.name === "ping")
				{
					// Just a hack to get the toolbar icon validation to work as expected.
					// If we don't pong back, the extension knows we are not loaded in a page.

					// There is a bug in Safari where the messageHandler is apparently held on to by Safari
					// even after an extension is disabled. So an effort to "ping" an extension's scripts will
					// succeed even if its been disabled and the page reloaded. Checking for the existance of
					// document.location seems to ensure we have enough of a handle still on the document that
					// we can do something useful with it.
					var shouldValidate = (document.location != null) && (thisPageLinkObjects.length > 0);

					// Pass back the same validationID we were handed so they can look up the correlated validationHandler
					safari.extension.dispatchMessage("pong", { "validationID": event.message.validationID, "shouldValidate": shouldValidate });
				}
			}, false);

			scanForSyndicationFeeds();
		}
	});
}
