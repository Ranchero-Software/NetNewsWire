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

// Here we are making iframes responsive.  Particularly useful for inline Youtube videos.
function wrapFrames() {
	document.querySelectorAll("iframe").forEach(element => {
		var wrapper = document.createElement("div");
		wrapper.classList.add("iframeWrap");
		element.parentNode.insertBefore(wrapper, element);
		wrapper.appendChild(element);
	});
}

// Strip out all styling so that we have better control over layout
function stripStyles() {
	document.getElementsByTagName("body")[0].querySelectorAll("style, link[rel=stylesheet]").forEach(element => element.remove());
	document.getElementsByTagName("body")[0].querySelectorAll("[style]").forEach(element => element.removeAttribute("style"));
}

// Add the playsinline attribute to any HTML5 videos that don't have it.
// Without this attribute videos may autoplay and take over the whole screen
// on an iphone when viewing an article.
function inlineVideos() {
	document.querySelectorAll("video").forEach(element => {
		element.setAttribute("playsinline", true)
	});
}

function error() {
	document.body.innerHTML = "error";
}

function render(data) {
	document.getElementsByTagName("style")[0].innerHTML = data.style;
	document.body.innerHTML = data.body;
	
	window.scrollTo(0, 0);
	
	wrapFrames()
	stripStyles()
	linkHover()
	inlineVideos()
}
