//
//  MacPreferencesView.swift
//  macOS
//
//  Created by Stuart Breckenridge on 27/6/20.
//

import SwiftUI

struct MacPreferenceViewModel {
    
    enum PreferencePane: Int, CaseIterable {
        case general = 0
        case accounts = 1
        case advanced = 2
        
        var description: String {
            switch self {
            case .general:
                return "General"
            case .accounts:
                return "Accounts"
            case .advanced:
                return "Advanced"
            }
        }
    }
    
    var currentPreferencePane: PreferencePane = PreferencePane.general
    
}

struct MacPreferencesView: View {
    
    @EnvironmentObject var defaults: AppDefaults
    @State private var viewModel = MacPreferenceViewModel()
    
    var body: some View {
        VStack {
            if viewModel.currentPreferencePane == .general {
				AnyView(GeneralPreferencesView().environmentObject(defaults))
            }
            else if viewModel.currentPreferencePane == .accounts {
				AnyView(AccountsPreferencesView().environmentObject(defaults))
            }
            else {
				AnyView(AdvancedPreferencesView().environmentObject(defaults))
            }
        }
        .toolbar {
            ToolbarItem {
                Button(action: {
                    viewModel.currentPreferencePane = .general
                }, label: {
                    Image(systemName: "checkmark.rectangle")
                    Text("General")
                })
            }
            ToolbarItem {
                Button(action: {
                    viewModel.currentPreferencePane = .accounts
                }, label: {
                    Image(systemName: "network")
                    Text("Accounts")
                })
            }
            ToolbarItem {
                Button(action: {
                    viewModel.currentPreferencePane = .advanced
                }, label: {
                    Image(systemName: "gearshape.fill")
                    Text("Advanced")
                })
            }
    }
        .presentedWindowToolbarStyle(UnifiedCompactWindowToolbarStyle())
        .presentedWindowStyle(TitleBarWindowStyle())
        .navigationTitle(Text(viewModel.currentPreferencePane.description))
    }
}




struct MacPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        MacPreferencesView()
    }
}
