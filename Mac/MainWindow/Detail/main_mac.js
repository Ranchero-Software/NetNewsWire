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

// The selection as an HTML fragment — links, bold, and so on included.
function selectedHTML() {
	var selection = window.getSelection();
	var container = document.createElement("div");
	for (var i = 0; i < selection.rangeCount; i++) {
		container.appendChild(selection.getRangeAt(i).cloneContents());
	}
	// Relative URLs would break outside this page.
	container.querySelectorAll("a[href]").forEach(function(anchor) {
		anchor.setAttribute("href", anchor.href);
	});
	// A single-paragraph selection doesn't need its <p> wrapper.
	if (container.childNodes.length === 1 && container.firstChild.nodeName === "P") {
		return container.firstChild.innerHTML;
	}
	return container.innerHTML;
}

function postRenderProcessing() {
	scrollDetection();
	linkHover();
}
