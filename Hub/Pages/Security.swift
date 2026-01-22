//
//  Security.swift
//  Hub
//
//  Created by Dmitry Kozlov on 7/6/25.
//

import SwiftUI

struct SecurityView: View {
  @Environment(Hub.self) var hub
  @State var pending: [PendingAuthorization] = []
  @State var ownerKey: String = ""
  @State var addingOwner: Bool = false
  var body: some View {
    List(pending) { item in
      HStack {
        VStack(alignment: .leading) {
          Text(item.name)
          Text(item.id).secondary()
            .textScale(.secondary)
            .fontDesign(.monospaced)
        }.lineLimit(2)
        Spacer()
        AsyncButton("Allow") {
          try await hub.client.send("hub/permissions/add", Allow(services: item.pending, permission: item.id))
        }
      }
    }.safeAreaInset(edge: .top) {
      HStack {
        if hub.permissions.contains("owner") {
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
        }
      }.frame(maxWidth: .infinity, alignment: .trailing).padding(.horizontal)
    }.navigationTitle("Security").hubStream("hub/permissions/pending", initial: [], to: $pending)
  }
  struct Allow: Encodable {
    let services: [String]
    let permission: String
  }
  struct AddPermissions: Encodable {
    let key: String
    let permissions: [String]
  }
  struct PendingAuthorization: Identifiable, Decodable {
    let id: String
    let pending: [String]
    var name: String {
      var set = Set<String>()
      pending.forEach { set.insert($0.components(separatedBy: "/")[0]) }
      return set.sorted().joined(separator: " & ")
    }
  }
}

#Preview {
  SecurityView().frame(width: 400, height: 200)
    .environment(Hub.test)
}
