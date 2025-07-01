//
//  Services.swift
//  Hub
//
//  Created by Dmitry Kozlov on 16/2/25.
//

import SwiftUI
import HubClient

extension String {
  func copyToClipboard() {
    #if os(macOS)
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(self, forType: .string)
    #else
    UIPasteboard.general.string = self
    #endif
  }
}

struct Services: View {
  @Environment(Hub.self) var hub
  @State var status: Status?
  var body: some View {
    List {
      if let status {
        ForEach(status.services, id: \.name) { service in
          Service(service: service)
        }
      }
    }.navigationTitle("\(status?.requests ?? 0) requests").toolbar {
      Text(hub.isConnected ? "Connected" : "Disconnected").badgeStyle()
      ForEach(hub.permissions.sorted(), id: \.self) { permission in
        Text(permission).badgeStyle()
      }
      Button("Copy Key", systemImage: "key.fill") {
        KeyChain.main.publicKey().copyToClipboard()
      }
    }.hubStream("hub/status", to: $status)
  }
}
struct Service: View {
  let service: Status.Service
  var onlineStatus: OnlineStatus {
    if service.services > 0 {
      OnlineStatus.online
    } else if (service.disabled ?? 0) > 0 {
      OnlineStatus.unauthorized
    } else {
      OnlineStatus.offline
    }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 6) {
        Text(service.name)
        onlineStatus.view
      }
      if service.requests > 0 {
        Text("\(service.requests) requests").secondary()
      }
    }
  }
}

#Preview {
  Services()
    .environment(Hub.test)
}
