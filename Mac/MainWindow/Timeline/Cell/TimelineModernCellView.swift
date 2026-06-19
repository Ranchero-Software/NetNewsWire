//
//  TimelineModernCellView.swift
//  NetNewsWire
//
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSCore

// Modern horizontal-split timeline cell (left: text / right: thumbnail) for macOS.
// Uses manual frame layout per NetNewsWire guidelines (no Auto Layout in table cells).
final class TimelineModernCellView: NSView {

	// MARK: - UI Components

	private let feedIconView: NSImageView = {
		let imageView = NSImageView()
		imageView.imageScaling = .scaleProportionallyUpOrDown
		imageView.wantsLayer = true
		imageView.layer?.cornerRadius = 10
		imageView.layer?.masksToBounds = true
		imageView.layer?.backgroundColor = NSColor.systemRed.cgColor
		imageView.autoresizingMask = []
		return imageView
	}()

	private let metadataLabel: NSTextField = {
		let label = NSTextField(labelWithString: "")
		label.font = .systemFont(ofSize: 11, weight: .regular)
		label.textColor = .secondaryLabelColor
		label.lineBreakMode = .byTruncatingTail
		label.cell?.truncatesLastVisibleLine = true
		label.autoresizingMask = []
		return label
	}()

	private let titleLabel: NSTextField = {
		let label = NSTextField(labelWithString: "")
		label.font = .systemFont(ofSize: 14, weight: .semibold)
		label.textColor = .labelColor
		label.maximumNumberOfLines = 2
		label.lineBreakMode = .byWordWrapping
		label.cell?.wraps = true
		label.cell?.truncatesLastVisibleLine = true
		label.autoresizingMask = []
		return label
	}()

	private let summaryLabel: NSTextField = {
		let label = NSTextField(labelWithString: "")
		label.font = .systemFont(ofSize: 12, weight: .regular)
		label.textColor = .secondaryLabelColor
		label.maximumNumberOfLines = 2
		label.lineBreakMode = .byWordWrapping
		label.cell?.wraps = true
		label.cell?.truncatesLastVisibleLine = true
		label.autoresizingMask = []
		return label
	}()

	private let thumbnailImageView: NSImageView = {
		let imageView = NSImageView()
		imageView.imageScaling = .scaleProportionallyUpOrDown
		imageView.wantsLayer = true
		imageView.layer?.masksToBounds = true
		imageView.layer?.cornerRadius = 6
		imageView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
		imageView.imageAlignment = .alignCenter
		imageView.autoresizingMask = []
		return imageView
	}()

	private let separatorView: NSView = {
		let view = NSView()
		view.wantsLayer = true
		view.layer?.backgroundColor = NSColor.separatorColor.cgColor
		view.autoresizingMask = []
		return view
	}()

	// MARK: - Properties

	var cellData: TimelineCellData! {
		didSet {
			configureWithCellData()
			needsLayout = true
		}
	}

	private var imageLoadTask: URLSessionDataTask?

	// Flipped so layout coordinates run top-to-bottom.
	override var isFlipped: Bool {
		return true
	}

	// MARK: - Initialization

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		setupViews()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setupViews()
	}

	deinit {
		imageLoadTask?.cancel()
	}

	// MARK: - Setup

	private func setupViews() {
		addSubview(feedIconView)
		addSubview(metadataLabel)
		addSubview(titleLabel)
		addSubview(summaryLabel)
		addSubview(thumbnailImageView)
		addSubview(separatorView)
	}

	override func layout() {
		super.layout()

		guard let cellData, bounds.width > 0 else {
			return
		}

		let layout = TimelineModernCellLayout(width: bounds.width, cellData: cellData)
		feedIconView.frame = layout.feedIconRect
		metadataLabel.frame = layout.metadataRect
		titleLabel.frame = layout.titleRect
		summaryLabel.frame = layout.summaryRect
		thumbnailImageView.frame = layout.thumbnailRect
		thumbnailImageView.isHidden = layout.thumbnailRect == .zero
		separatorView.frame = layout.separatorRect
	}

	// MARK: - Configuration

	private func configureWithCellData() {
		guard let cellData else {
			return
		}

		// NSTableView reuse has no prepareForReuse callback, so cancel any in-flight
		// load and clear the image to avoid flashing the previous article's thumbnail.
		imageLoadTask?.cancel()
		imageLoadTask = nil
		thumbnailImageView.image = nil

		if let iconImage = cellData.iconImage {
			feedIconView.image = iconImage.image
			feedIconView.layer?.backgroundColor = NSColor.clear.cgColor
		} else {
			feedIconView.image = nil
			feedIconView.layer?.backgroundColor = NSColor.systemRed.cgColor
		}

		metadataLabel.stringValue = "\(cellData.feedName) • \(cellData.dateString)"

		titleLabel.stringValue = cellData.title
		titleLabel.textColor = cellData.read ? .secondaryLabelColor : .labelColor

		summaryLabel.stringValue = cellData.text

		if let url = cellData.thumbnailURL {
			loadImage(from: url)
		}
	}

	private func loadImage(from url: URL) {
		imageLoadTask?.cancel()

		if let cachedImage = MacImageCache.shared.image(for: url) {
			thumbnailImageView.image = cachedImage
			return
		}

		imageLoadTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
			guard let self,
				  let data = data,
				  let image = NSImage(data: data),
				  error == nil else {
				return
			}

			// Cropping is CPU work; stay off the main thread.
			let croppedImage = image.cropToSquare()

			// MacImageCache is MainActor-isolated.
			DispatchQueue.main.async { [weak self] in
				MacImageCache.shared.storeImage(croppedImage, for: url)
				self?.thumbnailImageView.image = croppedImage
			}
		}

		imageLoadTask?.resume()
	}
}

// MARK: - Image Cache for macOS

@MainActor
final class MacImageCache {
	static let shared = MacImageCache()

	private let cache = NSCache<NSURL, NSImage>()

	private init() {
		cache.countLimit = 100
		cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
	}

	func image(for url: URL) -> NSImage? {
		return cache.object(forKey: url as NSURL)
	}

	func storeImage(_ image: NSImage, for url: URL) {
		cache.setObject(image, forKey: url as NSURL)
	}
}

// MARK: - NSImage Extension for Square Cropping

extension NSImage {
	/// Crops the image to a centered square.
	func cropToSquare() -> NSImage {
		guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
			return self
		}

		let width = cgImage.width
		let height = cgImage.height
		let minDimension = min(width, height)
		let x = (width - minDimension) / 2
		let y = (height - minDimension) / 2

		if let croppedCGImage = cgImage.cropping(to: CGRect(x: x, y: y, width: minDimension, height: minDimension)) {
			return NSImage(cgImage: croppedCGImage, size: NSSize(width: minDimension, height: minDimension))
		}

		return self
	}
}
