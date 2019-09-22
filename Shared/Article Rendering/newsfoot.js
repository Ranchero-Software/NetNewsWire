 (function () {
	// @ts-check
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

	/** @type {<T extends any[]>(fn: (...args: T) => void, t: number) => ((...args: T) => void)} */
	function debounce(f, ms) {
		let t = Date.now();
		return (...args) => {
			const now = Date.now();
			if (now - t < ms) return;
			t = now;
			f(...args);
		};
	}

	const clsPrefix = "newsfoot-footnote-";
	const CONTAINER_CLS = `${clsPrefix}container`;
	const POPOVER_CLS = `${clsPrefix}popover`;

	/**
	 * @param {Node} content
	 * @returns {HTMLElement}
	 */
	function footnoteMarkup(content) {
		const popover = newEl("div", POPOVER_CLS);
		popover.appendChild(content);
		return popover;
	}

	class Footnote {
		/**
		 * @param {Node} content
		 * @param {Element} fnref
		 */
		constructor(content, fnref) {
			this.popover = footnoteMarkup(content);
			this.style = window.getComputedStyle(this.popover);
			this.fnref = fnref;
			this.fnref.closest(`.${CONTAINER_CLS}`).appendChild(this.popover);
			this.reposition();
  
			/** @type {(ev:MouseEvent) => void} */
			this.clickoutHandler = (ev) => {
				if (!(ev.target instanceof Element)) return;
				if (ev.target.closest(`.${POPOVER_CLS}`) === this.popover) return;
				this.cleanup();
			}
			document.addEventListener("click", this.clickoutHandler, {capture: true});
  
			this.resizeHandler = debounce(() => this.reposition(), 20);
			window.addEventListener("resize", this.resizeHandler);
		}
  
		cleanup() {
			remove(this.popover);
			document.removeEventListener("click", this.clickoutHandler, {capture: true});
			window.removeEventListener("resize", this.resizeHandler);
			delete this.popover;
			delete this.clickoutHandler;
			delete this.resizeHandler;
		}
  
		reposition() {
			const refRect = this.fnref.getBoundingClientRect();
			const center = refRect.left + (refRect.width / 2);
			const popoverHalfWidth = this.popover.clientWidth / 2;
			const marginLeft = stripPx(this.style.marginLeft);
			const marginRight = stripPx(this.style.marginRight);
  
			let offset = 0;
			if (center + popoverHalfWidth + marginRight > window.innerWidth) {
				offset = -((center + popoverHalfWidth + marginRight) - window.innerWidth);
			}
			else if (center - (popoverHalfWidth + marginLeft) < 0) {
				offset = (popoverHalfWidth + marginLeft) - center;
			}
			this.popover.style.transform = `translate(${offset}px)`;
		}
	}

	/** @param {Node} n */
	function fragFromContents(n) {
		const frag = document.createDocumentFragment();
		n.childNodes.forEach((ch) => frag.appendChild(ch));
		return frag;
	}

	/** @param {HTMLAnchorElement} a */
	function installContainer(a) {
		if (!a.parentElement.matches(`.${CONTAINER_CLS}`)) {
			const container = newEl("div", CONTAINER_CLS);
			a.parentElement.insertBefore(container, a);
			container.appendChild(a);
		}
	}

	document.addEventListener("click", (ev) => {
		if (!(ev.target && ev.target instanceof HTMLAnchorElement)) return;
		if (!ev.target.matches(".footnote")) return;
		ev.preventDefault();

		const content = document.querySelector(`[id='${ev.target.hash.substring(1)}']`).cloneNode(true);
	    if (content instanceof HTMLElement) {
		    remove(content.querySelector(".reversefootnote"));
        }
		installContainer(ev.target);
		void new Footnote(fragFromContents(content), ev.target);
    });
}());
