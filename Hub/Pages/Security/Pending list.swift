//
//  Pending list.swift
//  Hub
//
//  Created by Linux on 07.02.26.
//

import SwiftUI
import HubClient

struct PendingListView: View {
  @Environment(Hub.self) private var hub
  @HubState(\.hostPending) private var hostPending
  var body: some View {
    List(hostPending.list) { item in
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
    }
  }
  struct Allow: Encodable {
    let services: [String]
    let permission: String
  }
}
