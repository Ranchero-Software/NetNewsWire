//
//  AboutViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/25/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class AboutViewController: UITableViewController {

	@IBOutlet weak var aboutTextView: UITextView!
	@IBOutlet weak var creditsTextView: UITextView!
	@IBOutlet weak var acknowledgmentsTextView: UITextView!
	@IBOutlet weak var thanksTextView: UITextView!
	@IBOutlet weak var dedicationTextView: UITextView!
	
	override func viewDidLoad() {
		
		super.viewDidLoad()
		
		configureCell(file: "About", textView: aboutTextView)
		configureCell(file: "Credits", textView: creditsTextView)
		configureCell(file: "Acknowledgments", textView: acknowledgmentsTextView)
		configureCell(file: "Thanks", textView: thanksTextView)
		configureCell(file: "Dedication", textView: dedicationTextView)

		let buildLabel = NonIntrinsicLabel(frame: CGRect(x: 20.0, y: 0.0, width: 0.0, height: 0.0))
		buildLabel.font = UIFont.systemFont(ofSize: 11.0)
		buildLabel.textColor = UIColor.gray
		buildLabel.text = NSLocalizedString("Copyright © 2002-2019 Ranchero Software", comment: "Copyright")
		buildLabel.numberOfLines = 0
		buildLabel.sizeToFit()
		buildLabel.translatesAutoresizingMaskIntoConstraints = false
		tableView.tableFooterView = buildLabel
		
	}

	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return UITableView.automaticDimension
	}
	
}

private extension AboutViewController {
	
	func configureCell(file: String, textView: UITextView) {
		let url = Bundle.main.url(forResource: file, withExtension: "rtf")!
		let string = try! NSAttributedString(url: url, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
		textView.attributedText = string
		textView.textColor = UIColor.label
		textView.adjustsFontForContentSizeCategory = true
		textView.font = .preferredFont(forTextStyle: .body)
	}
	
}
