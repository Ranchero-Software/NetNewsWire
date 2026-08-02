// The button is enabled on every web page. Clicking sends the page URL to the app,
// whose FeedFinder module does all feed discovery — head links, page scanning,
// URL guessing, special cases — so the logic lives in exactly one place.

function subscribeToPage() {
	safari.extension.dispatchMessage("subscribeToFeed", { "url": "feed:" + document.location.href });
}

function messageHandler(event) {
	if (event.name === "toolbarButtonClicked")
	{
		// Workaround Radar #31182842, in which residual copies of our
		// app extension may remain loaded in context of pages in Safari,
		// causing multiple responses to broadcast message about toolbar
		// button being clicked. In the case of the "extra" injections,
		// the document location is null, so we can avoid doing on anything.
		if (document.location != null)
		{
			subscribeToPage();
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
		var shouldValidate = (document.location != null);

		// Pass back the same validationID we were handed so they can look up the correlated validationHandler
		safari.extension.dispatchMessage("pong", { "validationID": event.message.validationID, "shouldValidate": shouldValidate });
	}
}

document.addEventListener("DOMContentLoaded", function(event) {
	// Prevent injecting the JavaScript in IFRAMES, and from acting before Safari is ready...
	if ((window.top === window) && 	(typeof safari != 'undefined') && (document.location != null))
	{
		safari.self.addEventListener("message", messageHandler, false)
	}
});
