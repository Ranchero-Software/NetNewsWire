function scrollDetection() {
	window.onscroll = function(event) {
		window.webkit.messageHandlers.windowDidScroll.postMessage(window.scrollY);
	}
}

function linkHover() {
	window.onmouseover = function(event) {
		var closestAnchor = event.target.closest('a')
		if (closestAnchor) {
			window.webkit.messageHandlers.mouseDidEnter.postMessage(closestAnchor.href);
		}
	}
	window.onmouseout = function(event) {
		var closestAnchor = event.target.closest('a')
		if (closestAnchor) {
			window.webkit.messageHandlers.mouseDidExit.postMessage(closestAnchor.href);
		}
	}
}

function postRenderProcessing() {
	scrollDetection();
	linkHover();
}
