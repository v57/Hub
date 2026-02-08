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
        if hub.host.canManage {
          AsyncButton("Allow") {
            try await hub.host.allow(key: item.id, paths: item.pending)
          }
        }
      }
    }
  }
}

#Preview {
  PendingListView().environment(Hub.test)
}
