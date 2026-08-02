var thisPageFeedCandidates = null;

// The detection rules here mirror the app's FeedFinder module (HTMLMetadata.resolveFeedLinks,
// HTMLFeedFinder, FeedSpecifier.calculatedScore) as closely as page-context JavaScript can.
// The extension can't make network requests, so it only suspects feeds — validation happens
// in the app, which runs everything we send through FeedFinder.

var feedURLWordsToMatch = ["feed", "xml", "rss", "atom", "json"];

// Matches by MIME type suffix, like the app.
function isFeedType(type) {
	return type.endsWith("/rss+xml") || type.endsWith("/atom+xml") || type.endsWith("/json");
}

function isSupportedScheme(href) {
	return href.startsWith("http://") || href.startsWith("https://") || href.startsWith("feed:") || href.startsWith("feeds:");
}

function isValidFeedLink(theLink) {
	if (!theLink.href || !isSupportedScheme(theLink.href))
	{
		return false;
	}

	// An alternate with media or hreflang is another version of the page (mobile, translation), not a feed.
	if (theLink.getAttribute("media") || theLink.getAttribute("hreflang"))
	{
		return false;
	}

	// An explicit non-feed type is rejected, but a missing type is fine — some sites leave it off.
	var type = theLink.getAttribute("type");
	if (type)
	{
		return isFeedType(type.toLowerCase());
	}
	return true;
}

function urlStringMightBeFeed(urlString) {
	// Mask "buzzfeed" so it doesn't match on "feed".
	var massagedURLString = urlString.toLowerCase().split("buzzfeed").join("_");

	for (var i = 0; i < feedURLWordsToMatch.length; i++)
	{
		if (massagedURLString.includes(feedURLWordsToMatch[i]))
		{
			return true;
		}
	}
	return false;
}

function scanForSyndicationFeeds() {
	// In case we don't find any, we establish that we have at least tried by setting the
	// variables to empty instead of null.
	thisPageFeedCandidates = [];

	var orderFound = 0;

	// First tier: declared feed links in the head.
	var headLinks = document.querySelectorAll("link[href][rel~='alternate']");
	for (var i = 0; i < headLinks.length; i++)
	{
		var headLink = headLinks[i];
		if (isValidFeedLink(headLink))
		{
			orderFound += 1;
			thisPageFeedCandidates.push({ "href": headLink.href, "title": headLink.title, "isHeadLink": true, "orderFound": orderFound });
		}
	}

	// Second tier: anchors anywhere in the page whose URLs look feed-like.
	var seenHrefs = {};
	var bodyLinks = document.links;
	for (var i = 0; i < bodyLinks.length; i++)
	{
		var href = bodyLinks[i].href;
		if (!href || seenHrefs[href] || !isSupportedScheme(href) || !urlStringMightBeFeed(href))
		{
			continue;
		}
		seenHrefs[href] = true;
		orderFound += 1;
		thisPageFeedCandidates.push({ "href": href, "title": bodyLinks[i].textContent, "isHeadLink": false, "orderFound": orderFound });
	}
}

function scoreForCandidate(candidate) {
	var score = 0;
	var url = candidate.href.toLowerCase();

	if (candidate.isHeadLink)
	{
		score += 50;
	}
	score -= (candidate.orderFound - 1) * 5;

	if (url.includes("comments"))
	{
		score -= 10;
	}
	if (url.includes("podcast"))
	{
		score -= 10;
	}
	if (url.includes("rss"))
	{
		score += 5;
	}
	if (url.endsWith("/index.xml"))
	{
		score += 5;
	}
	if (url.endsWith("/feed/"))
	{
		score += 5;
	}
	if (url.endsWith("/feed"))
	{
		score += 4;
	}
	if (url.includes("json"))
	{
		score += 3;
	}
	if (candidate.title && candidate.title.toLowerCase().includes("comments"))
	{
		score -= 10;
	}

	return score;
}

function bestFeedCandidate() {
	var bestCandidate = null;
	var bestScore = -Infinity;

	for (var i = 0; i < thisPageFeedCandidates.length; i++)
	{
		var score = scoreForCandidate(thisPageFeedCandidates[i]);
		if (score > bestScore)
		{
			bestScore = score;
			bestCandidate = thisPageFeedCandidates[i];
		}
	}
	return bestCandidate;
}

function subscribeToFeed(urlString) {
	// Convert the URL to a feed:// scheme because Safari
	// will refuse to load e.g. a feed that is listed merely
	// as "text/xml".
	var feedURL = urlString;
	if (!feedURL.startsWith('feed:') && !feedURL.startsWith('feeds:'))
	{
		feedURL = 'feed:' + feedURL;
	}

	safari.extension.dispatchMessage("subscribeToFeed", { "url": feedURL });
}

function messageHandler(event) {
	if (event.name === "toolbarButtonClicked")
	{
		// Workaround Radar #31182842, in which residual copies of our
		// app extension may remain loaded in context of pages in Safari,
		// causing multiple responses to broadcast message about toolbar
		// button being clicked. In the case of the "extra" injections,
		// the document location is null, so we can avoid doing on anything.
		if ((document.location != null) && (thisPageFeedCandidates.length > 0))
		{
			var candidate = bestFeedCandidate();

			// A head link is a declared feed URL — send it directly. A body link is only
			// a guess, so send the page URL and let the app find and validate the real feed.
			var urlToSend = candidate.isHeadLink ? candidate.href : document.location.href;
			subscribeToFeed(urlToSend);
		}
	}
	else if (event.name === "ping")
	{
		// Just a hack to get the toolbar icon validation to work as expected.
		// If we don't pong back, the extension knows we are not loaded in a page.

		// There is a bug in Safari where the messageHandler is apparently held on to by Safari
		// even after an extension is disabled. So an effort to "ping" an extension's scripts will
		// succeed even if its been disabled and the page reloaded. Checking for the existence of
		// document.location seems to ensure we have enough of a handle still on the document that
		// we can do something useful with it.
		var shouldValidate = (document.location != null) && (thisPageFeedCandidates.length > 0);

		// Pass back the same validationID we were handed so they can look up the correlated validationHandler
		safari.extension.dispatchMessage("pong", { "validationID": event.message.validationID, "shouldValidate": shouldValidate });
	}
}

document.addEventListener("DOMContentLoaded", function(event) {
	// Prevent injecting the JavaScript in IFRAMES, and from acting before Safari is ready...
	if ((window.top === window) && 	(typeof safari != 'undefined') && (document.location != null))
	{
		safari.self.addEventListener("message", messageHandler, false)
		scanForSyndicationFeeds();
	}
});
