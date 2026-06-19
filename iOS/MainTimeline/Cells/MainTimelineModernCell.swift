//
//  MainTimelineModernCell.swift
//  NetNewsWire-iOS
//
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import UIKit

final class MainTimelineModernCell: UICollectionViewCell {

	// MARK: - Layout Constants

	private let thumbnailSize: CGFloat = 72.0
	private let horizontalPadding: CGFloat = 16.0
	private let verticalPadding: CGFloat = 12.0
	private let leftRightGap: CGFloat = 12.0
	// Used when estimating title line count, since bounds may not be laid out yet.
	private let estimatedLeftTextWidth: CGFloat = 270.0

	// MARK: - UI Components

	private let containerView: UIView = {
		let view = UIView()
		view.backgroundColor = .clear
		view.translatesAutoresizingMaskIntoConstraints = false
		return view
	}()

	private let leftContentContainer: UIView = {
		let view = UIView()
		view.backgroundColor = .clear
		view.translatesAutoresizingMaskIntoConstraints = false
		return view
	}()

	private let feedIconView: UIImageView = {
		let imageView = UIImageView()
		imageView.contentMode = .scaleAspectFit
		imageView.clipsToBounds = true
		imageView.layer.cornerRadius = 10
		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.backgroundColor = .systemRed
		return imageView
	}()

	private let metadataLabel: UILabel = {
		let label = UILabel()
		label.font = .systemFont(ofSize: 12, weight: .regular)
		label.textColor = .secondaryLabel
		label.translatesAutoresizingMaskIntoConstraints = false
		label.lineBreakMode = .byTruncatingTail
		return label
	}()

	private let titleLabel: UILabel = {
		let label = UILabel()
		label.font = .systemFont(ofSize: 17, weight: .semibold)
		label.textColor = .label
		label.numberOfLines = 2
		label.lineBreakMode = .byTruncatingTail
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	private let summaryLabel: UILabel = {
		let label = UILabel()
		label.font = .systemFont(ofSize: 15, weight: .regular)
		label.textColor = .secondaryLabel
		label.numberOfLines = 2
		label.lineBreakMode = .byTruncatingTail
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	private let thumbnailContainerView: UIView = {
		let view = UIView()
		view.backgroundColor = .clear
		view.translatesAutoresizingMaskIntoConstraints = false
		view.clipsToBounds = true
		view.layer.cornerRadius = 6
		return view
	}()

	private let thumbnailImageView: UIImageView = {
		let imageView = UIImageView()
		imageView.contentMode = .scaleAspectFill
		imageView.clipsToBounds = true
		imageView.backgroundColor = .systemGray6
		imageView.translatesAutoresizingMaskIntoConstraints = false
		return imageView
	}()

	private let separatorView: UIView = {
		let view = UIView()
		view.backgroundColor = .separator
		view.translatesAutoresizingMaskIntoConstraints = false
		return view
	}()

	// MARK: - Properties

	var cellData: MainTimelineCellData! {
		didSet {
			configureWithCellData()
		}
	}

	// Two mutually exclusive leftContent.trailing constraints, swapped based on whether
	// a thumbnail is shown. The thumbnail container itself uses a fixed size + position,
	// which avoids conflicts with width=height-style constraints.
	private var isShowingThumbnail = false
	private var leftContentTrailingToContainer: NSLayoutConstraint?
	private var leftContentTrailingToThumbnail: NSLayoutConstraint?

	private var imageDataTask: URLSessionDataTask?

	// MARK: - Initialization

	override init(frame: CGRect) {
		super.init(frame: frame)
		setupViews()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setupViews()
	}

	override func prepareForReuse() {
		super.prepareForReuse()
		imageDataTask?.cancel()
		imageDataTask = nil
		thumbnailImageView.image = nil
		feedIconView.image = nil
	}

	// MARK: - Setup

	private func setupViews() {
		contentView.addSubview(containerView)
		containerView.addSubview(leftContentContainer)
		containerView.addSubview(thumbnailContainerView)
		containerView.addSubview(separatorView)

		leftContentContainer.addSubview(feedIconView)
		leftContentContainer.addSubview(metadataLabel)
		leftContentContainer.addSubview(titleLabel)
		leftContentContainer.addSubview(summaryLabel)

		thumbnailContainerView.addSubview(thumbnailImageView)

		setupConstraints()
	}

	private func setupConstraints() {
		let trailingToContainer = leftContentContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
		let trailingToThumbnail = leftContentContainer.trailingAnchor.constraint(equalTo: thumbnailContainerView.leadingAnchor, constant: -leftRightGap)
		leftContentTrailingToContainer = trailingToContainer
		leftContentTrailingToThumbnail = trailingToThumbnail

		NSLayoutConstraint.activate([
			containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: verticalPadding),
			containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalPadding),
			containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalPadding),
			containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -verticalPadding),

			separatorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			separatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			separatorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
			separatorView.heightAnchor.constraint(equalToConstant: 0.5),

			leftContentContainer.topAnchor.constraint(equalTo: containerView.topAnchor),
			leftContentContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
			leftContentContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
			trailingToContainer,

			thumbnailContainerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
			thumbnailContainerView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
			thumbnailContainerView.widthAnchor.constraint(equalToConstant: thumbnailSize),
			thumbnailContainerView.heightAnchor.constraint(equalToConstant: thumbnailSize),

			feedIconView.topAnchor.constraint(equalTo: leftContentContainer.topAnchor),
			feedIconView.leadingAnchor.constraint(equalTo: leftContentContainer.leadingAnchor),
			feedIconView.widthAnchor.constraint(equalToConstant: 20),
			feedIconView.heightAnchor.constraint(equalToConstant: 20),

			metadataLabel.centerYAnchor.constraint(equalTo: feedIconView.centerYAnchor),
			metadataLabel.leadingAnchor.constraint(equalTo: feedIconView.trailingAnchor, constant: 8),
			metadataLabel.trailingAnchor.constraint(equalTo: leftContentContainer.trailingAnchor),

			titleLabel.topAnchor.constraint(equalTo: feedIconView.bottomAnchor, constant: 8),
			titleLabel.leadingAnchor.constraint(equalTo: leftContentContainer.leadingAnchor),
			titleLabel.trailingAnchor.constraint(equalTo: leftContentContainer.trailingAnchor),

			// Pinned to the container bottom to complete the vertical chain so the list
			// layout can compute the self-sizing height.
			summaryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
			summaryLabel.leadingAnchor.constraint(equalTo: leftContentContainer.leadingAnchor),
			summaryLabel.trailingAnchor.constraint(equalTo: leftContentContainer.trailingAnchor),
			summaryLabel.bottomAnchor.constraint(equalTo: leftContentContainer.bottomAnchor),

			thumbnailImageView.topAnchor.constraint(equalTo: thumbnailContainerView.topAnchor),
			thumbnailImageView.leadingAnchor.constraint(equalTo: thumbnailContainerView.leadingAnchor),
			thumbnailImageView.trailingAnchor.constraint(equalTo: thumbnailContainerView.trailingAnchor),
			thumbnailImageView.bottomAnchor.constraint(equalTo: thumbnailContainerView.bottomAnchor),
		])

		thumbnailContainerView.isHidden = true
	}

	// MARK: - Configuration

	private func configureWithCellData() {
		guard let cellData = cellData else {
			return
		}

		imageDataTask?.cancel()
		imageDataTask = nil
		thumbnailImageView.image = nil

		if let iconImage = cellData.iconImage {
			feedIconView.image = iconImage.image
			feedIconView.backgroundColor = .clear
		} else {
			feedIconView.image = nil
			feedIconView.backgroundColor = .systemRed
		}

		metadataLabel.text = "\(cellData.feedName) • \(cellData.dateString)"

		titleLabel.text = cellData.title
		titleLabel.textColor = cellData.read ? .secondaryLabel : .label

		// A long title wraps to 2 lines; the summary then shrinks to 1 line to keep the
		// overall height balanced (1-line title → 2-line summary).
		let titleLines = calculateTitleLines(cellData.title)
		summaryLabel.numberOfLines = titleLines >= 2 ? 1 : 2

		summaryLabel.text = cellData.summary

		configureThumbnail(cellData.thumbnailURL)
	}

	/// Number of lines the title occupies (1 or 2).
	private func calculateTitleLines(_ text: String) -> Int {
		guard !text.isEmpty else {
			return 1
		}

		let label = UILabel()
		label.font = .systemFont(ofSize: 17, weight: .semibold)
		label.text = text
		label.numberOfLines = 2

		let actualSize = label.sizeThatFits(CGSize(width: estimatedLeftTextWidth, height: .greatestFiniteMagnitude))
		let lineHeight: CGFloat = 22

		return min(Int(ceil(actualSize.height / lineHeight)), 2)
	}

	private func configureThumbnail(_ url: URL?) {
		guard let url = url else {
			hideThumbnailAndExpandLeft()
			return
		}
		showThumbnailWithSplitLayout()
		loadImage(from: url)
	}

	private func hideThumbnailAndExpandLeft() {
		guard isShowingThumbnail else {
			return
		}

		isShowingThumbnail = false
		thumbnailContainerView.isHidden = true

		leftContentTrailingToThumbnail?.isActive = false
		leftContentTrailingToContainer?.isActive = true

		setNeedsLayout()
		layoutIfNeeded()
	}

	private func showThumbnailWithSplitLayout() {
		guard !isShowingThumbnail else {
			return
		}

		isShowingThumbnail = true
		thumbnailContainerView.isHidden = false

		leftContentTrailingToContainer?.isActive = false
		leftContentTrailingToThumbnail?.isActive = true

		setNeedsLayout()
		layoutIfNeeded()
	}

	private func loadImage(from url: URL) {
		imageDataTask?.cancel()

		if let cachedImage = ImageCache.shared.image(for: url) {
			thumbnailImageView.image = cachedImage
			return
		}

		imageDataTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
			guard let self,
				  let data = data,
				  let image = UIImage(data: data),
				  error == nil else {
				return
			}

			// Cropping is CPU work; stay off the main thread.
			let croppedImage = image.cropToSquare()

			// ImageCache is MainActor-isolated.
			DispatchQueue.main.async { [weak self] in
				ImageCache.shared.storeImage(croppedImage, for: url)
				self?.thumbnailImageView.image = croppedImage
			}
		}

		imageDataTask?.resume()
	}

	override var isHighlighted: Bool {
		didSet {
			containerView.alpha = isHighlighted ? 0.7 : 1.0
		}
	}
}

// MARK: - Image Cache

@MainActor
final class ImageCache {
	static let shared = ImageCache()

	private let cache = NSCache<NSURL, UIImage>()

	private init() {
		cache.countLimit = 100
		cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
	}

	func image(for url: URL) -> UIImage? {
		return cache.object(forKey: url as NSURL)
	}

	func storeImage(_ image: UIImage, for url: URL) {
		cache.setObject(image, forKey: url as NSURL)
	}
}

// MARK: - UIImage Extension for Square Cropping

extension UIImage {
	/// Crops the image to a centered square.
	func cropToSquare() -> UIImage {
		let minDimension = min(size.width, size.height)
		let x = (size.width - minDimension) / 2.0
		let y = (size.height - minDimension) / 2.0

		let cropRect = CGRect(x: x, y: y, width: minDimension, height: minDimension)

		if let cgImage = self.cgImage?.cropping(to: cropRect) {
			return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
		}

		return self
	}
}
