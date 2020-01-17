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

// Convert all Feedbin proxy images to be used as src, otherwise change image locations to be absolute
function convertImgSrc() {
	document.querySelectorAll("img").forEach(element => {
		if (element.hasAttribute("data-camo-src")) {
			element.src = element.getAttribute("data-camo-src")
		} else {
			element.src = new URL(element.src, document.baseURI).href;
		}
	});
}

// Wrap tables in an overflow-x: auto; div
function wrapTables() {
	var tables = document.querySelector("div.articleBody").getElementsByTagName("table");

	for (table of tables) {
		var wrapper = document.createElement("div");
		wrapper.className = "nnw-overflow";
		table.parentNode.insertBefore(wrapper, table);
		wrapper.appendChild(table);
	}
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
	wrapTables()
	stripStyles()
	convertImgSrc()
	flattenPreElements()

	postRenderProcessing()
}
