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
	}
	
}
