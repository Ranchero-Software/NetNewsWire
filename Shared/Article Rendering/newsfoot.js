// @ts-check
 (function () {
	/** @param {Node | null} el */
	const remove = (el) => { if (el) el.parentElement.removeChild(el) };

	const stripPx = (s) => +s.slice(0, -2);

	/** @param {string} tag
	 * @param {string} cls
	 * @returns HTMLElement
	 */
	function newEl(tag, cls) {
		const el = document.createElement(tag);
		el.classList.add(cls);
		return el;
	}

	const clsPrefix = "newsfoot-footnote-";
	const CONTAINER_CLS = `${clsPrefix}container`;
	const POPOVER_CLS = `${clsPrefix}popover`;
    const POPOVER_INNER_CLS = `${clsPrefix}popover-inner`;
    const POPOVER_ARROW_CLS = `${clsPrefix}popover-arrow`;
	// Slightly longer than the closing fade in core.css.
	const CLOSE_FALLBACK_MS = 300;

	/**
	 * @param {string} content
	 * @returns {HTMLElement}
	 */
	function footnoteMarkup(content) {
		const popover = newEl("div", POPOVER_CLS);
		const arrow = newEl("div", POPOVER_ARROW_CLS);
        const inner = newEl("div", POPOVER_INNER_CLS);
		popover.appendChild(inner);
		popover.appendChild(arrow);
		inner.innerHTML = content;
		return popover;
	}

	class Footnote {
		/**
		 * @param {string} content
		 * @param {Element} fnref
		 */
		constructor(content, fnref) {
			this.popover = footnoteMarkup(content);
			this.style = window.getComputedStyle(this.popover);
			this.fnref = fnref;
			let container = this.fnref.closest(`.${CONTAINER_CLS}`);
			container.insertBefore(this.popover, fnref);
			container.style.zIndex = 1;
			/** @type {HTMLElement} */
		    this.arrow = this.popover.querySelector(`.${POPOVER_ARROW_CLS}`);
			this.reposition();
  
			/** @type {(ev:MouseEvent) => void} */
			this.clickoutHandler = (ev) => {
				if (!(ev.target instanceof Element)) return;
				// Keep this popover open for clicks anywhere inside it, including a nested footnote popover.
				// <https://github.com/Ranchero-Software/NetNewsWire/issues/2372>
				if (this.popover.contains(ev.target)) return;
				if (ev.target === this.fnref) {
				    ev.stopPropagation();
					ev.preventDefault();
				}
				this.cleanup();
			}
			document.addEventListener("click", this.clickoutHandler, {capture: true});
  
			this.resizeHandler = () => this.reposition();
			window.addEventListener("resize", this.resizeHandler);
		}
  
		cleanup() {
			document.removeEventListener("click", this.clickoutHandler, {capture: true});
			window.removeEventListener("resize", this.resizeHandler);

			const popover = this.popover;
			const container = this.fnref.closest(`.${CONTAINER_CLS}`);
			let finished = false;
			const finish = () => {
				if (finished) return;
				finished = true;
				remove(popover);
				if (!container.querySelector(`.${POPOVER_CLS}`)) container.style.zIndex = 0;
			};

			popover.classList.add("is-closing");
			popover.addEventListener("transitionend", (ev) => {
				if (ev.target !== popover || ev.propertyName !== "opacity") return;
				finish();
			});
			// Naughty themes can disable or change the fade, which stops transitioned
			setTimeout(finish, CLOSE_FALLBACK_MS);
		}
  
		reposition() {
			const refRect = this.fnref.getBoundingClientRect();
			const containerRect = this.fnref.closest(`.${CONTAINER_CLS}`).getBoundingClientRect();
			const articleBody = this.fnref.closest(".articleBody");
			const visibleRect = articleBody ? articleBody.getBoundingClientRect() : document.documentElement.getBoundingClientRect();
			const maximumWidth = stripPx(this.style.maxWidth);
			const popoverWidth = Math.min(visibleRect.width, maximumWidth);
			const refCenter = refRect.left + (refRect.width / 2);
			const minimumLeft = visibleRect.left;
			const maximumLeft = visibleRect.right - popoverWidth;
			const popoverLeft = Math.min(
				Math.max(refCenter - (popoverWidth / 2), minimumLeft),
				maximumLeft
			);

			// Keep the popover inside the visible article column while centering it on the
			// footnote reference whenever there is enough room.
			this.popover.style.left = `${popoverLeft - containerRect.left}px`;
			this.popover.style.width = `${popoverWidth}px`;

			const arrowWidth = this.arrow.getBoundingClientRect().width / Math.SQRT2;
			const arrowCenter = refCenter - popoverLeft;
			const insetArrowCenter = Math.min(
				Math.max(arrowCenter, arrowWidth),
				popoverWidth - arrowWidth
			);
			this.arrow.style.left = `${insetArrowCenter - (arrowWidth / 2) - this.popover.clientLeft}px`;
		}
	}

	/** @param {HTMLAnchorElement} a */
	function installContainer(a) {
		if (!a.parentElement.matches(`.${CONTAINER_CLS}`)) {
			const container = newEl("div", CONTAINER_CLS);
			a.parentElement.insertBefore(container, a);
			container.appendChild(a);
		}
	}
			
	function idFromHash(target) {
		if (!target.hash) return;
		return decodeURIComponent(target.hash.substring(1));
	}
	/**
	 * @type {{
	 *   fnref(target:HTMLAnchorElement): string|undefined,
	 *   content(targetElement:HTMLElement): string
	 * }[]}
	 */
	const footnoteFormats = [
		{ // Substack: the ref <a id="footnote-anchor-N" href="#footnote-N">
		  // points at a backlink <a id="footnote-N">N</a> whose note text lives
		  // in the sibling elements that follow it, not inside the anchor.
			fnref(target) {
				if (!target.matches("a[id^='footnote-anchor-']")) return;
				return idFromHash(target);
			},
			content(targetElement) {
				let html = "";
				let node = targetElement.nextElementSibling;
				while (node && !node.matches("a[id^='footnote-']")) {
					html += node.outerHTML;
					node = node.nextElementSibling;
				}
				return html;
			}
		},
		{ // Multimarkdown
			fnref(target) {
				if (!target.matches(".footnote")) return;
				return idFromHash(target);
			},
			content(targetElement) {
				return targetElement.innerHTML;
			}
		}
	];
	
	// Handle clicks on the footnote reference
	document.addEventListener("click", (ev) => {
		if (!(ev.target && ev.target instanceof HTMLAnchorElement)) return;

		let targetId = undefined;
		let format = undefined;
		for(const f of footnoteFormats) {
			targetId = f.fnref(ev.target);
			if (targetId) {
				format = f;
				break;
			}
		}
		if (targetId === undefined) return;

		// Only override the default behaviour when we know we can find the
		// target element
		const targetElement = document.getElementById(targetId);
		if (targetElement === null) return;

		ev.preventDefault();

		installContainer(ev.target);

		void new Footnote(format.content(targetElement), ev.target);
    });
										   
	// Handle clicks on the footnote reverse link
    document.addEventListener("click", (ev) =>
    {
	    if (!(ev.target && ev.target instanceof HTMLAnchorElement)) return;
        if (!ev.target.matches(".footnotes .reversefootnote, .footnotes .footnoteBackLink, .footnotes .footnote-return, .footnotes a[href*='#fn'], .footnotes a[href^='#']")) return;
		const id = idFromHash(ev.target);
		if (!id) return;
		const fnref = document.getElementById(id);

		window.scrollTo({ top: fnref.getBoundingClientRect().top + window.scrollY });
	    ev.preventDefault();
	});
}());
