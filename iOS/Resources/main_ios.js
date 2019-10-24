var imageIsLoading = false;

// Used to pop a resizable image view
async function imageWasClicked(img) {
	img.classList.add("nnwClicked");
	
	try {
		showNetworkLoading(img);
		const response = await fetch(img.src);
		if (!response.ok) {
			throw new Error('Network response was not ok.');
		}

		const imgBlob = await response.blob();
		hideNetworkLoading(img);
		
		var reader = new FileReader();
		reader.readAsDataURL(imgBlob);
		reader.onloadend = function() {
			
			const rect = img.getBoundingClientRect();
			var message = {
				x: rect.x,
				y: rect.y,
				width: rect.width,
				height: rect.height
			};
			message.imageURL = reader.result;
			
			var jsonMessage = JSON.stringify(message);
			window.webkit.messageHandlers.imageWasClicked.postMessage(jsonMessage);
			
		}
	} catch (error) {
		hideNetworkLoading(img);
		console.log('There has been a problem with your fetch operation: ', error.message);
	}
	
}

function showNetworkLoading(img) {
	imageIsLoading = true;

	var wrapper = document.createElement("div");
	wrapper.classList.add("activityIndicatorWrap");
	img.parentNode.insertBefore(wrapper, img);
	wrapper.appendChild(img);

	var activityIndicatorImg = document.createElement("img");
	activityIndicatorImg.classList.add("activityIndicator");
	activityIndicatorImg.style.opacity = 0;
	activityIndicatorImg.src = activityIndicator;
	wrapper.appendChild(activityIndicatorImg);
	
	// Wait a bit before showing the indicator
	function showActivityIndicator() {
		activityIndicatorImg.style.opacity = 1;
	}
	setTimeout(showActivityIndicator, 300);
}

function hideNetworkLoading(img) {
	var wrapper = img.parentNode;
	var wrapperParent = wrapper.parentNode;
	wrapperParent.insertBefore(img, wrapper);
	wrapperParent.removeChild(wrapper);

	imageIsLoading = false;
}

// Used to animate the transition to a fullscreen image
function hideClickedImage() {
	var img = document.querySelector('.nnwClicked')
	img.style.opacity = 0
}

// Used to animate the transition from a fullscreen image
function showClickedImage() {
	var img = document.querySelector('.nnwClicked')
	img.classList.remove("nnwClicked");
	img.style.opacity = 1
	window.webkit.messageHandlers.imageWasShown.postMessage("");
}

// Add the click listener for images
function imageClicks() {
	window.onclick = function(event) {
		if (event.target.matches('img') && !imageIsLoading) {
			imageWasClicked(event.target);
		}
	}
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

const activityIndicator = "data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9Im5vIj8+PHN2ZyB4bWxuczpzdmc9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIiB2ZXJzaW9uPSIxLjAiIHdpZHRoPSI2NHB4IiBoZWlnaHQ9IjY0cHgiIHZpZXdCb3g9IjAgMCAxMjggMTI4IiB4bWw6c3BhY2U9InByZXNlcnZlIj48Zz48cGF0aCBkPSJNNTkuNiAwaDh2NDBoLThWMHoiIGZpbGw9IiMwMDAwMDAiLz48cGF0aCBkPSJNNTkuNiAwaDh2NDBoLThWMHoiIGZpbGw9IiNjY2NjY2MiIHRyYW5zZm9ybT0icm90YXRlKDMwIDY0IDY0KSIvPjxwYXRoIGQ9Ik01OS42IDBoOHY0MGgtOFYweiIgZmlsbD0iI2NjY2NjYyIgdHJhbnNmb3JtPSJyb3RhdGUoNjAgNjQgNjQpIi8+PHBhdGggZD0iTTU5LjYgMGg4djQwaC04VjB6IiBmaWxsPSIjY2NjY2NjIiB0cmFuc2Zvcm09InJvdGF0ZSg5MCA2NCA2NCkiLz48cGF0aCBkPSJNNTkuNiAwaDh2NDBoLThWMHoiIGZpbGw9IiNjY2NjY2MiIHRyYW5zZm9ybT0icm90YXRlKDEyMCA2NCA2NCkiLz48cGF0aCBkPSJNNTkuNiAwaDh2NDBoLThWMHoiIGZpbGw9IiNiMmIyYjIiIHRyYW5zZm9ybT0icm90YXRlKDE1MCA2NCA2NCkiLz48cGF0aCBkPSJNNTkuNiAwaDh2NDBoLThWMHoiIGZpbGw9IiM5OTk5OTkiIHRyYW5zZm9ybT0icm90YXRlKDE4MCA2NCA2NCkiLz48cGF0aCBkPSJNNTkuNiAwaDh2NDBoLThWMHoiIGZpbGw9IiM3ZjdmN2YiIHRyYW5zZm9ybT0icm90YXRlKDIxMCA2NCA2NCkiLz48cGF0aCBkPSJNNTkuNiAwaDh2NDBoLThWMHoiIGZpbGw9IiM2NjY2NjYiIHRyYW5zZm9ybT0icm90YXRlKDI0MCA2NCA2NCkiLz48cGF0aCBkPSJNNTkuNiAwaDh2NDBoLThWMHoiIGZpbGw9IiM0YzRjNGMiIHRyYW5zZm9ybT0icm90YXRlKDI3MCA2NCA2NCkiLz48cGF0aCBkPSJNNTkuNiAwaDh2NDBoLThWMHoiIGZpbGw9IiMzMzMzMzMiIHRyYW5zZm9ybT0icm90YXRlKDMwMCA2NCA2NCkiLz48cGF0aCBkPSJNNTkuNiAwaDh2NDBoLThWMHoiIGZpbGw9IiMxOTE5MTkiIHRyYW5zZm9ybT0icm90YXRlKDMzMCA2NCA2NCkiLz48YW5pbWF0ZVRyYW5zZm9ybSBhdHRyaWJ1dGVOYW1lPSJ0cmFuc2Zvcm0iIHR5cGU9InJvdGF0ZSIgdmFsdWVzPSIwIDY0IDY0OzMwIDY0IDY0OzYwIDY0IDY0OzkwIDY0IDY0OzEyMCA2NCA2NDsxNTAgNjQgNjQ7MTgwIDY0IDY0OzIxMCA2NCA2NDsyNDAgNjQgNjQ7MjcwIDY0IDY0OzMwMCA2NCA2NDszMzAgNjQgNjQiIGNhbGNNb2RlPSJkaXNjcmV0ZSIgZHVyPSIxMDgwbXMiIHJlcGVhdENvdW50PSJpbmRlZmluaXRlIj48L2FuaW1hdGVUcmFuc2Zvcm0+PC9nPjwvc3ZnPg==";
