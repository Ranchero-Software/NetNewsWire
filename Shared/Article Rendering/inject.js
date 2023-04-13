function fixYouTube() {
	var checkForVideoTimer = null;
	
	function callback(event) {
		var fullScreenButtonOld = document.querySelector("button.ytp-fullscreen-button");
		var fullScreenButton = fullScreenButtonOld.cloneNode(true);
		fullScreenButton.style = false;
		fullScreenButton.setAttribute("aria-disabled", "false");
		fullScreenButton.onclick = function() {
			var player = document.querySelector("video");
			player.webkitRequestFullScreen();
		};
		fullScreenButtonOld.parentNode.replaceChild(fullScreenButton, fullScreenButtonOld);
	}
	
	function checkForVideo() {
		var video = document.querySelector("video");
		if (video) {
			clearInterval(checkForVideoTimer);

			var goFullScreen = function() {
				video.webkitRequestFullScreen();
			};
			
			var fullScreenButtonOld = document.querySelector("button.ytp-fullscreen-button");
			var fullScreenButton = fullScreenButtonOld.cloneNode(true);
			fullScreenButton.style = false;
			fullScreenButton.setAttribute("aria-disabled", "false");
			fullScreenButton.onclick = goFullScreen;
			fullScreenButtonOld.parentNode.replaceChild(fullScreenButton, fullScreenButtonOld);
		}
	}
	
	const hostname = window.location.hostname;
	if (hostname.endsWith(".youtube.com") || hostname.endsWith(".youtube-nocookie.com")) {
		checkForVideoTimer = setInterval(checkForVideo, 100);
	}
	
	document.addEventListener('webkitfullscreenchange', fullScreenChange, true);
}

document.addEventListener("DOMContentLoaded", function(event) {
	fixYouTube();
});
