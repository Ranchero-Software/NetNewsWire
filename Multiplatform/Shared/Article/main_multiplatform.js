var activeImageViewer = null;

class ImageViewer {
	constructor(img) {
		this.img = img;
		this.loadingInterval = null;
		this.activityIndicator = "data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9Im5vIj8+PHN2ZyB4bWxuczpzdmc9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIiB2ZXJzaW9uPSIxLjAiIHdpZHRoPSI2NHB4IiBoZWlnaHQ9IjY0cHgiIHZpZXdCb3g9IjAgMCAxMjggMTI4IiB4bWw6c3BhY2U9InByZXNlcnZlIj48Zz48cGF0aCBkPSJNNTkuNiAwaDh2NDBoLThWMHoiIGZpbGw9IiMwMDAwMDAiLz48cGF0aCBkPSJNNTkuNiAwaDh2NDBoLThWMHoiIGZpbGw9IiNjY2NjY2MiIHRyYW5zZm9ybT0icm90YXRlKDMwIDY0IDY0KSIvPjxwYXRoIGQ9Ik01OS42IDBoOHY0MGgtOFYweiIgZmlsbD0iI2NjY2NjYyIgdHJhbnNmb3JtPSJyb3RhdGUoNjAgNjQgNjQpIi8+PHBhdGggZD0iTTU5LjYgMGg4djQwaC04VjB6IiBmaWxsPSIjY2NjY2NjIiB0cmFuc2Zvcm09InJvdGF0ZSg5MCA2NCA2NCkiLz48cGF0aCBkPSJNNTkuNiAwaDh2NDBoLThWMHoiIGZpbGw9IiNjY2NjY2MiIHRyYW5zZm9ybT0icm90YXRlKDEyMCA2NCA2NCkiLz48cGF0aCBkPSJNNTkuNiAwaDh2NDBoLThWMHoiIGZpbGw9IiNiMmIyYjIiIHRyYW5zZm9ybT0icm90YXRlKDE1MCA2NCA2NCkiLz48cGF0aCBkPSJNNTkuNiAwaDh2NDBoLThWMHoiIGZpbGw9IiM5OTk5OTkiIHRyYW5zZm9ybT0icm90YXRlKDE4MCA2NCA2NCkiLz48cGF0aCBkPSJNNTkuNiAwaDh2NDBoLThWMHoiIGZpbGw9IiM3ZjdmN2YiIHRyYW5zZm9ybT0icm90YXRlKDIxMCA2NCA2NCkiLz48cGF0aCBkPSJNNTkuNiAwaDh2NDBoLThWMHoiIGZpbGw9IiM2NjY2NjYiIHRyYW5zZm9ybT0icm90YXRlKDI0MCA2NCA2NCkiLz48cGF0aCBkPSJNNTkuNiAwaDh2NDBoLThWMHoiIGZpbGw9IiM0YzRjNGMiIHRyYW5zZm9ybT0icm90YXRlKDI3MCA2NCA2NCkiLz48cGF0aCBkPSJNNTkuNiAwaDh2NDBoLThWMHoiIGZpbGw9IiMzMzMzMzMiIHRyYW5zZm9ybT0icm90YXRlKDMwMCA2NCA2NCkiLz48cGF0aCBkPSJNNTkuNiAwaDh2NDBoLThWMHoiIGZpbGw9IiMxOTE5MTkiIHRyYW5zZm9ybT0icm90YXRlKDMzMCA2NCA2NCkiLz48YW5pbWF0ZVRyYW5zZm9ybSBhdHRyaWJ1dGVOYW1lPSJ0cmFuc2Zvcm0iIHR5cGU9InJvdGF0ZSIgdmFsdWVzPSIwIDY0IDY0OzMwIDY0IDY0OzYwIDY0IDY0OzkwIDY0IDY0OzEyMCA2NCA2NDsxNTAgNjQgNjQ7MTgwIDY0IDY0OzIxMCA2NCA2NDsyNDAgNjQgNjQ7MjcwIDY0IDY0OzMwMCA2NCA2NDszMzAgNjQgNjQiIGNhbGNNb2RlPSJkaXNjcmV0ZSIgZHVyPSIxMDgwbXMiIHJlcGVhdENvdW50PSJpbmRlZmluaXRlIj48L2FuaW1hdGVUcmFuc2Zvcm0+PC9nPjwvc3ZnPg==";
	}

	isLoaded() {
		return this.img.classList.contains("nnwLoaded");
	}

	clicked() {
		this.showLoadingIndicator();
		if (this.isLoaded()) {
			this.showViewer();
		} else {
			var callback = () => {
				if (this.isLoaded()) {
					clearInterval(this.loadingInterval);
					this.showViewer();
				}
			}
			this.loadingInterval = setInterval(callback, 100);
		}
	}
	cancel() {
		clearInterval(this.loadingInterval);
		this.hideLoadingIndicator();
	}

	showViewer() {
		this.hideLoadingIndicator();

		var canvas = document.createElement("canvas");
		var pixelRatio = window.devicePixelRatio;
		do {
			canvas.width = this.img.naturalWidth * pixelRatio;
			canvas.height = this.img.naturalHeight * pixelRatio;
			pixelRatio--;
		} while (pixelRatio > 0 && canvas.width * canvas.height > 16777216)
		canvas.getContext("2d").drawImage(this.img, 0, 0, canvas.width, canvas.height);
		
		const rect = this.img.getBoundingClientRect();
		const message = {
			x: rect.x,
			y: rect.y,
			width: rect.width,
			height: rect.height,
			imageTitle: this.img.title,
			imageURL: canvas.toDataURL(),
		};

		var jsonMessage = JSON.stringify(message);
		window.webkit.messageHandlers.imageWasClicked.postMessage(jsonMessage);
	}

	hideImage() {
		this.img.style.opacity = 0;
	}

	showImage() {
		this.img.style.opacity = 1
	}

	showLoadingIndicator() {
		var wrapper = document.createElement("div");
		wrapper.classList.add("activityIndicatorWrap");
		this.img.parentNode.insertBefore(wrapper, this.img);
		wrapper.appendChild(this.img);

		var activityIndicatorImg = document.createElement("img");
		activityIndicatorImg.classList.add("activityIndicator");
		activityIndicatorImg.style.opacity = 0;
		activityIndicatorImg.src = this.activityIndicator;
		wrapper.appendChild(activityIndicatorImg);

		activityIndicatorImg.style.opacity = 1;
	}

	hideLoadingIndicator() {
		var wrapper = this.img.parentNode;
		if (wrapper.classList.contains("activityIndicatorWrap")) {
			var wrapperParent = wrapper.parentNode;
			wrapperParent.insertBefore(this.img, wrapper);
			wrapperParent.removeChild(wrapper);
		}
	}

	static init() {
		cancelImageLoad();

		// keep track of when an image has finished downloading for ImageViewer
		document.querySelectorAll("img").forEach(element => {
			element.onload = function() {
				this.classList.add("nnwLoaded");
			}
		});

		// Add the click listener for images
		window.onclick = function(event) {
			if (event.target.matches("img") && !event.target.classList.contains("nnw-nozoom")) {
				if (activeImageViewer && activeImageViewer.img === event.target) {
					cancelImageLoad();
				} else {
					cancelImageLoad();
					activeImageViewer = new ImageViewer(event.target);
					activeImageViewer.clicked();
				}
			}
		}
	}
}

function cancelImageLoad() {
	if (activeImageViewer) {
		activeImageViewer.cancel();
		activeImageViewer = null;
	}
}

function hideClickedImage() {
	if (activeImageViewer) {
		activeImageViewer.hideImage();
	}
}

// Used to animate the transition from a fullscreen image
function showClickedImage() {
	if (activeImageViewer) {
		activeImageViewer.showImage();
	}
	window.webkit.messageHandlers.imageWasShown.postMessage("");
}

function showFeedInspectorSetup() {
	document.getElementById("nnwImageIcon").onclick = function(event) {
		window.webkit.messageHandlers.showFeedInspector.postMessage("");
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
	ImageViewer.init();
	showFeedInspectorSetup();
	linkHover();
}


function makeHighlightRect({left, top, width, height}, offsetTop=0, offsetLeft=0) {
	const overlay = document.createElement('a');

	Object.assign(overlay.style, {
		position: 'absolute',
		left: `${Math.floor(left + offsetLeft)}px`,
		top: `${Math.floor(top + offsetTop)}px`,
		width: `${Math.ceil(width)}px`,
		height: `${Math.ceil(height)}px`,
		backgroundColor: 'rgba(200, 220, 10, 0.4)',
		pointerEvents: 'none'
	});

	return overlay;
}

function clearHighlightRects() {
	let container = document.getElementById('nnw:highlightContainer')
	if (container) container.remove();
}

function highlightRects(rects, clearOldRects=true, makeHighlightRect=makeHighlightRect) {
	const article = document.querySelector('article');
	let container = document.getElementById('nnw:highlightContainer');

	article.style.position = 'relative';

	if (container && clearOldRects)
		container.remove();

	container = document.createElement('div');
	container.id = 'nnw:highlightContainer';
	article.appendChild(container);

	const {top, left} = article.getBoundingClientRect();
	return Array.from(rects, rect => 
		container.appendChild(makeHighlightRect(rect, -top, -left))
	);
}

FinderResult = class {
	constructor(result) {
		Object.assign(this, result);
	}

	range() {
		const range = document.createRange();
		range.setStart(this.node, this.offset);
		range.setEnd(this.node, this.offsetEnd);
		return range;
	}

	bounds() {
		return this.range().getBoundingClientRect();
	}

	rects() {
		return this.range().getClientRects();
	}

	highlight({clearOldRects=true, fn=makeHighlightRect} = {}) {
		highlightRects(this.rects(), clearOldRects, fn);
	}

	scrollTo() {
		scrollToRect(this.bounds(), this.node);
	}

	toJSON() {
		return {
			rects: Array.from(this.rects()),
			bounds: this.bounds(),
			index: this.index,
			matchGroups: this.match
		};
	}

	toJSONString() {
		return JSON.stringify(this.toJSON());
	}
}

Finder = class {
	constructor(pattern, options) {
		if (!pattern.global) {
			pattern = new RegExp(pattern, 'g');
		}

		this.pattern = pattern;
		this.lastResult = null;
		this._nodeMatches = [];
		this.options = {
			rootSelector: '.articleBody',
			startNode: null,
			startOffset: null,
		}

		this.resultIndex = -1

		Object.assign(this.options, options);

		this.walker = document.createTreeWalker(this.root, NodeFilter.SHOW_TEXT);
	}

	get root() {
		return document.querySelector(this.options.rootSelector)
	}

	get count() {
		const node = this.walker.currentNode;
		const index = this.resultIndex;
		this.reset();

		let result, count = 0;
		while ((result = this.next())) ++count;

		this.resultIndex = index;
		this.walker.currentNode = node;

		return count;
	}

	reset() {
		this.walker.currentNode = this.options.startNode || this.root;
		this.resultIndex = -1;
	}

	[Symbol.iterator]() {
		return this;
	}

	next({wrap = false} = {}) {
		const { startNode } = this.options;
		const { pattern, walker } = this;

		let { node, matchIndex = -1 } = this.lastResult || { node: startNode };

		while (true) {
			if (!node)
				node = walker.nextNode();

			if (!node) {
				if (!wrap || this.resultIndex < 0) break;

				this.reset();

				continue;
			}

			let nextIndex = matchIndex + 1;
			let matches = this._nodeMatches;

			if (!matches.length) {
				matches = Array.from(node.textContent.matchAll(pattern));
				nextIndex = 0;
			}
 
			if (matches[nextIndex]) {
				this._nodeMatches = matches;
				const m = matches[nextIndex];

				this.lastResult = new FinderResult({
					node,
					offset: m.index,
					offsetEnd: m.index + m[0].length,
					text: m[0],
					match: m,
					matchIndex: nextIndex,
					index: ++this.resultIndex,
				});

				return { value: this.lastResult, done: false };
			}

			this._nodeMatches = [];
			node = null;
		}

		return { value: undefined, done: true };
	}

	/// TODO Call when the search text changes
	retry() {
		if (this.lastResult) {
			this.lastResult.offsetEnd = this.lastResult.offset;
		}
		
	}

	toJSON() {
		const results = Array.from(this);
	}
}

function scrollParent(node) {
	let elt = node.nodeType === Node.ELEMENT_NODE ? node : node.parentElement;

	while (elt) {
		if (elt.scrollHeight > elt.clientHeight)
			return elt;
		elt = elt.parentElement;
	}
}
 
function scrollToRect({top, height}, node, pad=20, padBottom=60) {
	const scrollToTop = top - pad;

	let scrollBy = scrollToTop;

	if (scrollToTop >= 0) {
		const visible = window.visualViewport;
		const scrollToBottom = top + height + padBottom - visible.height;
		// The top of the rect is already in the viewport
		if (scrollToBottom <= 0 || scrollToTop === 0)
			// Don't need to scroll up--or can't
			return;

		scrollBy = Math.min(scrollToBottom, scrollBy);
	} 

	scrollParent(node).scrollBy({ top: scrollBy });
}

function withEncodedArg(fn) {
	return function(encodedData, ...rest) {
		const data = encodedData && JSON.parse(atob(encodedData));
		return fn(data, ...rest);
	}
}

function escapeRegex(s) {
	return s.replace(/[.?*+^$\\()[\]{}]/g, '\\$&');
}

class FindState {
	constructor(options) {
		let { text, caseSensitive, regex } = options;
		
		if (!regex)
			text = escapeRegex(text);
		
		const finder = new Finder(new RegExp(text, caseSensitive ? 'g' : 'ig'));
		this.results = Array.from(finder);
		this.index = -1;
		this.options = options;
	}
	
	get selected() {
		return this.index > -1 ? this.results[this.index] : null;
	}
	
	toJSON() {
		return {
			index: this.index > -1 ? this.index : null,
			results: this.results,
			count: this.results.length
		};
	}
	
	selectNext(step=1) {
		const index = this.index + step;
		const result = this.results[index];
		if (result) {
			this.index = index;
			result.highlight();
			result.scrollTo();
		}
		return result;
	}
	
	selectPrevious() {
		return this.selectNext(-1);
	}
}

CurrentFindState = null;

const ExcludeKeys = new Set(['top', 'right', 'bottom', 'left']);
updateFind = withEncodedArg(options => {
	// TODO Start at the current result position
	// TODO Introduce slight delay, cap the number of results, and report results asynchronously
	
	let newFindState;
	if (!options || !options.text) {
		clearHighlightRects();
		return
	}
	
	try {
		newFindState = new FindState(options);
	} catch (err) {
		clearHighlightRects();
		throw err;
	}
	
	if (newFindState.results.length) {
		let selected = CurrentFindState && CurrentFindState.selected;
		let selectIndex = 0;
		if (selected) {
			let {node: currentNode, offset: currentOffset} = selected;
			selectIndex = newFindState.results.findIndex(r => {
				if (r.node === currentNode) {
					return r.offset >= currentOffset;
				}
				
				let relation = currentNode.compareDocumentPosition(r.node);
				return Boolean(relation & Node.DOCUMENT_POSITION_FOLLOWING);
			});
		}
		
		newFindState.selectNext(selectIndex+1);
	} else {
		clearHighlightRects();
	}
	
	CurrentFindState = newFindState;
	return btoa(JSON.stringify(CurrentFindState, (k, v) => (ExcludeKeys.has(k) ? undefined : v)));
});

selectNextResult = withEncodedArg(options => {
	if (CurrentFindState)
		CurrentFindState.selectNext();
});

selectPreviousResult = withEncodedArg(options => {
	if (CurrentFindState)
		CurrentFindState.selectPrevious();
});

function endFind() {
	clearHighlightRects()
	CurrentFindState = null;
}
