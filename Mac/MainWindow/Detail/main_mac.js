// Add the mouse listeners for the above functions
function linkHover() {
	window.onmouseover = function(event) {
		if (event.target.matches('a')) {
			window.webkit.messageHandlers.mouseDidEnter.postMessage(event.target.href);
		}
	}
	window.onmouseout = function(event) {
		if (event.target.matches('a')) {
			window.webkit.messageHandlers.mouseDidExit.postMessage(event.target.href);
		}
	}
}

function postRenderProcessing() {
	linkHover()
}
