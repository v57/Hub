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
    }.navigationTitle("Security").hubStream("hub/permissions/pending", initial: [], to: $pending)
  }
  struct Allow: Encodable {
    let services: [String]
    let permission: String
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
