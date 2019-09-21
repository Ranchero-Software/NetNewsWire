function mouseDidEnterLink(anchor) {
	window.webkit.messageHandlers.mouseDidEnter.postMessage(anchor.href);
}

function mouseDidExitLink(anchor) {
	window.webkit.messageHandlers.mouseDidExit.postMessage(anchor.href);
}

function wrapFrames() {
	document.querySelectorAll("iframe").forEach(element => {
		var wrapper = document.createElement("div");
		wrapper.classList.add("iframeWrap");
		element.parentNode.insertBefore(wrapper, element);
		wrapper.appendChild(element);
	});
}

function stripStyles() {
	document.getElementsByTagName("body")[0].querySelectorAll("style, link[rel=stylesheet]").forEach(element => element.remove());
	document.getElementsByTagName("body")[0].querySelectorAll("[style]").forEach(element => element.removeAttribute("style"));
}

function linkHover() {
	var anchors = document.getElementsByTagName("a");
	for (var i = 0; i < anchors.length; i++) {
		anchors[i].addEventListener("mouseenter", function() { mouseDidEnterLink(this) });
		anchors[i].addEventListener("mouseleave", function() { mouseDidExitLink(this) });
	}
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
}
