//
//  Security.swift
//  Hub
//
//  Created by Dmitry Kozlov on 7/6/25.
//

import SwiftUI

struct SecurityView: View {
  @Environment(Hub.self) private var hub
  @State private var ownerKey: String = ""
  @State private var addingOwner: Bool = false
  @State private var page: Page = .pending
  enum Page {
    case pending, connections, permissions
  }
  var body: some View {
    ZStack {
      switch page {
      case .pending:
        PendingListView()
      case .connections:
        UserConnections()
      case .permissions:
        PermissionGroups()
      }
    }.safeAreaInset(edge: .top) {
      HStack {
        if !addingOwner {
          Picker("Page", selection: $page) {
            Text("Requests").tag(Page.pending)
            Text("Connections").tag(Page.connections)
            Text("Permissions").tag(Page.permissions)
          }.pickerStyle(.segmented).labelsHidden()
          Spacer()
        }
        if addingOwner {
          SecureField("Key", text: $ownerKey)
          if ownerKey.isEmpty {
            Button("Cancel") {
              addingOwner = false
            }
          } else {
            AsyncButton("Add") {
              addingOwner = false
              let key = ownerKey
              ownerKey = ""
              try await hub.addOwner(key)
            }.disabled(ownerKey.isEmpty)
          }
        } else {
          Button("Add owner") {
            addingOwner = true
          }
        }
      }.padding(.horizontal)
    }.navigationTitle("Security")
  }
  struct AddPermissions: Encodable {
    let key: String
    let permissions: [String]
  }
}

#Preview {
  SecurityView()//.frame(width: 400, height: 200)
    .environment(Hub.test)
}
