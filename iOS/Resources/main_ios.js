// Used to pop a resizable image view
function imageWasClicked(img) {
	window.webkit.messageHandlers.imageWasClicked.postMessage(img.src);
}

// Add the click listeners for images
function imageClicks() {
	document.querySelectorAll("img").forEach(element => {
		element.addEventListener("click", function() { imageWasClicked(this) });
	});
}

// Add the playsinline attribute to any HTML5 videos that don't have it.
// Without this attribute videos may autoplay and take over the whole screen
// on an iphone when viewing an article.
function inlineVideos() {
	document.querySelectorAll("video").forEach(element => {
		element.setAttribute("playsinline", true)
	});
}

function postRenderProcessing() {
	imageClicks()
	inlineVideos()
}
