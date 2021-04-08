// Here we are making iframes responsive.  Particularly useful for inline Youtube videos.
function wrapFrames() {
	document.querySelectorAll("iframe").forEach(element => {
		if (element.height > 0 || parseInt(element.style.height) > 0)
			return;
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

// Strip inline styles that could harm readability.
function stripStyles() {
	document.getElementsByTagName("body")[0].querySelectorAll("style, link[rel=stylesheet]").forEach(element => element.remove());
	// Removing "background" and "font" will also remove properties that would be reflected in them, e.g., "background-color" and "font-family"
	document.getElementsByTagName("body")[0].querySelectorAll("[style]").forEach(element => stripStylesFromElement(element, ["color", "background", "font", "max-width", "max-height", "position"]));
}

// Constrain the height of iframes whose heights are defined relative to the document body to be at most
// 50% of the viewport width.
function constrainBodyRelativeIframes() {
	let iframes = document.getElementsByTagName("iframe");

	for (iframe of iframes) {
		if (iframe.offsetParent === document.body) {
			let heightAttribute = iframe.style.height;

			if (/%|vw|vh$/i.test(heightAttribute)) {
				iframe.classList.add("nnw-constrained");
			}
		}
	}
}

// Convert all Feedbin proxy images to be used as src, otherwise change image locations to be absolute if not already
function convertImgSrc() {
	document.querySelectorAll("img").forEach(element => {
		if (element.hasAttribute("data-canonical-src")) {
			element.src = element.getAttribute("data-canonical-src")
		} else if (!/^[a-z]+\:\/\//i.test(element.src)) {
			element.src = new URL(element.src, document.baseURI).href;
		}
	});
}

// Wrap tables in an overflow-x: auto; div
function wrapTables() {
	var tables = document.querySelectorAll("div.articleBody table");

	for (table of tables) {
		var wrapper = document.createElement("div");
		wrapper.className = "nnw-overflow";
		table.parentNode.insertBefore(wrapper, table);
		wrapper.appendChild(table);
	}
}

// Add the playsinline attribute to any HTML5 videos that don"t have it.
// Without this attribute videos may autoplay and take over the whole screen
// on an iphone when viewing an article.
function inlineVideos() {
	document.querySelectorAll("video").forEach(element => {
		element.setAttribute("playsinline", true);
		if (!element.classList.contains("nnwAnimatedGIF")) {
			element.setAttribute("controls", true);
			element.removeAttribute("autoplay");
		}
	});
}

// Remove some children (currently just spans) from pre elements to work around a strange clipping issue
var ElementUnwrapper = {
	unwrapSelector: "span",
	unwrapElement: function (element) {
		var parent = element.parentNode;
		var children = Array.from(element.childNodes);

		for (child of children) {
			parent.insertBefore(child, element);
		}

		parent.removeChild(element);
	},
	// `elements` can be a selector string, an element, or a list of elements
	unwrapAppropriateChildren: function (elements) {
		if (typeof elements[Symbol.iterator] !== 'function')
			elements = [elements];
		else if (typeof elements === "string")
			elements = document.querySelectorAll(elements);

		for (element of elements) {
			for (unwrap of element.querySelectorAll(this.unwrapSelector)) {
				this.unwrapElement(unwrap);
			}

			element.normalize()
		}
	}
};

function flattenPreElements() {
	ElementUnwrapper.unwrapAppropriateChildren("div.articleBody td > pre");
}

function reloadArticleImage(imageSrc) {
	var image = document.getElementById("nnwImageIcon");
	image.src = imageSrc;
}

function stopMediaPlayback() {
	document.querySelectorAll("iframe").forEach(element => {
		var iframeSrc = element.src;
		element.src = iframeSrc;
	});

	// We pause all videos that have controls.  Video without controls shouldn't
	// have sound and are actually converted gifs.  Basically if the user can't
	// start the video again, don't stop it.
	document.querySelectorAll("video, audio").forEach(element => {
		if (element.hasAttribute("controls")) {
			element.pause();
		}
	});
}

function updateTextSize(cssClass) {
	var bodyElement = document.getElementById("bodyContainer");
	bodyElement.classList.remove("smallText", "mediumText", "largeText", "xLargeText", "xxLargeText");
	bodyElement.classList.add(cssClass);
}

function error() {
	document.body.innerHTML = "error";
}

// Takes into account absoluting of URLs.
function isLocalFootnote(target) {
	return target.hash.startsWith("#fn") && target.href.indexOf(document.baseURI) === 0;
}

function styleLocalFootnotes() {
	for (elem of document.querySelectorAll("sup > a[href*='#fn'], sup > div > a[href*='#fn']")) {
		if (isLocalFootnote(elem)) {
			elem.classList.add("footnote");
		}
	}
}

// convert <img alt="📰" src="[...]" class="wp-smiley"> to a text node containing 📰
function removeWpSmiley() {
	for (const img of document.querySelectorAll("img.wp-smiley[alt]")) {
		 img.parentNode.replaceChild(document.createTextNode(img.alt), img);
	}
}

function processPage() {
	wrapFrames();
	wrapTables();
	inlineVideos();
	stripStyles();
	constrainBodyRelativeIframes();
	convertImgSrc();
	flattenPreElements();
	styleLocalFootnotes();
	removeWpSmiley()
	postRenderProcessing();
}
