// Used to pop a resizable image view
async function imageWasClicked(img) {
	img.classList.add("nnwClicked");

	const rect = img.getBoundingClientRect();
	
	var message = {
		x: rect.x,
		y: rect.y,
		width: rect.width,
		height: rect.height
	};
	
	try {
		const response = await fetch(img.src);
		if (!response.ok) {
			throw new Error('Network response was not ok.');
		}

		const imgBlob = await response.blob();

		var reader = new FileReader();
		reader.readAsDataURL(imgBlob);

		reader.onloadend = function() {
			message.imageURL = reader.result;
			var jsonMessage = JSON.stringify(message);
			window.webkit.messageHandlers.imageWasClicked.postMessage(jsonMessage);
		}
	} catch (error) {
		console.log('There has been a problem with your fetch operation: ', error.message);
	}
	
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
		if (event.target.matches('img')) {
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
