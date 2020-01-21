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
		canvas.width = this.img.naturalWidth;
		canvas.height = this.img.naturalHeight;
		canvas.getContext("2d").drawImage(this.img, 0, 0);

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
			if (event.target.matches("img")) {
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

// Add the playsinline attribute to any HTML5 videos that don"t have it.
// Without this attribute videos may autoplay and take over the whole screen
// on an iphone when viewing an article.
function inlineVideos() {
	document.querySelectorAll("video").forEach(element => {
		element.setAttribute("playsinline", true)
		element.setAttribute("controls", true)
	});
}

function postRenderProcessing() {
	ImageViewer.init();
	inlineVideos();
}

function stopMediaPlayback() {
	document.querySelectorAll("iframe").forEach(element => {
		var iframeSrc = element.src;
		element.src = iframeSrc;
	});

	document.querySelectorAll("video, audio").forEach(element => {
		element.pause();
	});
}
