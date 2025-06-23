//
//  MainFeedCollectionViewCell.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 23/06/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore
import Account
import RSTree

class MainFeedCollectionViewCell: UICollectionViewCell {
    
	@IBOutlet weak var feedTitle: UILabel!
	@IBOutlet weak var faviconImageView: UIImageView!
	@IBOutlet weak var unreadCountLabel: UILabel!
	
    private var capsuleSelectedBackgroundView: UIView {
        let view = UIView()
		view.backgroundColor = UIColor.tertiarySystemFill
        view.layer.cornerRadius = 22
        view.layer.masksToBounds = true
        return view
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        if UIDevice.current.userInterfaceIdiom == .pad {
            selectedBackgroundView = capsuleSelectedBackgroundView
        }
    }

    override var isSelected: Bool {
        didSet {
            if UIDevice.current.userInterfaceIdiom == .pad {
				feedTitle.textColor = isSelected ? AppAssets.primaryAccentColor : .label
            }
        }
    }
		
}
