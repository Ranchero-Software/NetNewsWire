//
//  ArticleContainerView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/2/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Articles

struct ArticleContainerView: View {
	
	var body: some View {
		GeometryReader { metrics in
			ScrollView {
				ArticleView()
					.frame(width: metrics.size.width, height: metrics.size.height)
					.modifier(ArticleToolbarModifier())
			}
			
		}
		
		
	}
	
}
