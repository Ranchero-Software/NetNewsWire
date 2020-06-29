//
//  AccountsPreferencesView.swift
//  macOS
//
//  Created by Stuart Breckenridge on 27/6/20.
//

import SwiftUI

struct AccountPreferencesViewModel {
    let accountTypes = ["On My Mac", "FeedBin"]
    var selectedAccount = Int?.none
}

struct AccountsPreferencesView: View {
   
    @State private var viewModel = AccountPreferencesViewModel()
    @State private var addAccountViewModel = AccountPreferencesViewModel()
    @State private var showAddAccountView: Bool = false
    
    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading) {
                    List(selection: $viewModel.selectedAccount, content: {
                        ForEach(0..<viewModel.accountTypes.count, content: { i in
                            AccountDetailRow(imageName: "desktopcomputer", accountName: viewModel.accountTypes[i]).padding(.vertical, 8)
                        })
                    })
                    HStack {
                        Button("+", action: {
                            showAddAccountView.toggle()
                        })
                        Button("-", action: {})
                            .disabled(viewModel.selectedAccount == nil)
                        Spacer()
                    }
                }.frame(width: 225, height: 300, alignment: .leading)
                VStack(alignment: .leading) {
                    viewModel.selectedAccount == nil ? Text("Select Account") : Text(viewModel.accountTypes[viewModel.selectedAccount!])
                    Spacer()
                }.frame(width: 225, height: 300, alignment: .leading)
            }
            Spacer()
        }.sheet(isPresented: $showAddAccountView,
                onDismiss: { showAddAccountView.toggle() },
                content: {
                    AddAccountView()
        })
    }
    
}

struct AccountDetailRow: View {
    
    var imageName: String
    var accountName: String
    
    var body: some View {
        HStack {
            Image(systemName: imageName).font(.headline)
            Text(accountName).font(.headline)
        }
    }
    
}

struct AddAccountView: View {
    
    @Environment(\.presentationMode) var presentationMode
    let accountTypes = ["On My Mac", "FeedBin"]
    @State var selectedAccount: Int = 0
    @State private var userName: String = ""
    @State private var password: String = ""

    var body: some View {
        
        VStack(alignment: .leading) {
            Text("Add an Account").font(.headline)
            Form {
                Picker("Account Type",
                       selection: $selectedAccount,
                       content: {
                            ForEach(0..<accountTypes.count, content: {
                                AccountDetailRow(imageName: "desktopcomputer", accountName: accountTypes[$0])
                            })
                       })
                
                if selectedAccount == 1 {
                    TextField("Email", text: $userName)
                    SecureField("Password", text: $password)
                }
            }
            Spacer()
            HStack {
                Spacer()
                
                
                Button(action: { presentationMode.wrappedValue.dismiss() }, label: {
                    Text("Cancel")
                })
                
                if selectedAccount == 0 {
                    Button("Add", action: {})
                }
                
                if selectedAccount != 0 {
                    Button("Create", action: {})
                        .disabled(userName.count == 0 || password.count == 0)
                }
                
                
            }
        }.frame(width: 300, alignment: .top).padding()
        
    }
    
}


class AddAccountModel: ObservableObject {
    let accountTypes = ["On My Mac", "FeedBin"]
    @Published var selectedAccount = Int?.none
}
    
    

