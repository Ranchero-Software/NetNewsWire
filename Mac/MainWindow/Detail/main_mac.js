// These mouse functions are used by NetNewsWire for Mac to display link previews
function mouseDidEnterLink(anchor) {
	window.webkit.messageHandlers.mouseDidEnter.postMessage(anchor.href);
}
function mouseDidExitLink(anchor) {
	window.webkit.messageHandlers.mouseDidExit.postMessage(anchor.href);
}

// Add the mouse listeners for the above functions
function linkHover() {
	document.querySelectorAll("a").forEach(element => {
		element.addEventListener("mouseenter", function() { mouseDidEnterLink(this) });
		element.addEventListener("mouseleave", function() { mouseDidExitLink(this) });
	});
}

function postRenderProcessing() {
	linkHover()
}
