// Here we are making iframes responsive.  Particularly useful for inline Youtube videos.
function wrapFrames() {
	document.querySelectorAll("iframe").forEach(element => {
		var wrapper = document.createElement("div");
		wrapper.classList.add("iframeWrap");
		element.parentNode.insertBefore(wrapper, element);
		wrapper.appendChild(element);
	});
}

// Strip out color and font styling

function stripStylesFromElement(element, propertiesToStrip) {
	for (name of propertiesToStrip) {
		element.style.removeProperty(name);
	}
}

function stripStyles() {
	document.getElementsByTagName("body")[0].querySelectorAll("style, link[rel=stylesheet]").forEach(element => element.remove());
	// Removing "background" and "font" will also remove properties that would be reflected in them, e.g., "background-color" and "font-family"
	document.getElementsByTagName("body")[0].querySelectorAll("[style]").forEach(element => stripStylesFromElement(element, ["color", "background", "font"]));
}

// Convert all image locations to be absolute
function convertImgSrc() {
	document.querySelectorAll("img").forEach(element => {
		element.src = new URL(element.src, document.baseURI).href;
	});
}

function reloadArticleImage() {
	var image = document.getElementById("nnwImageIcon");
	image.src = "nnwImageIcon://";
}

function error() {
	document.body.innerHTML = "error";
}

function render(data, scrollY) {
	document.getElementsByTagName("style")[0].innerHTML = data.style;
	document.body.innerHTML = data.body;
	
	window.scrollTo(0, scrollY);
	
	wrapFrames()
	stripStyles()
	convertImgSrc()
	
	postRenderProcessing()
}
