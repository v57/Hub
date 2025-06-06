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
  @State var permissions = [String]()
  var body: some View {
    List {
      if let status = hub.status {
        ForEach(status.services, id: \.name) { service in
          Service(service: service)
        }
      }
    }.navigationTitle("\(hub.status?.requests ?? 0) requests").toolbar {
      ForEach(permissions, id: \.self) { permission in
        Text(permission).font(.caption2).foregroundStyle(.white)
          .padding(.horizontal, 6).padding(.vertical, 2)
          .background(.red, in: .capsule)
      }
      Button("Copy Key", systemImage: "key.fill") {
        KeyChain.main.publicKey().copyToClipboard()
      }
    }.task {
      do {
        permissions = try await hub.client.permissions().sorted()
      } catch { }
    }
  }
}
struct Service: View {
  let service: Status.Service
  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 6) {
        Text(service.name)
        OnlineStatus.online.view
      }
      Text("\(service.requests) requests").font(.caption2)
        .foregroundStyle(.secondary)
    }
  }
}

#Preview {
  Services()
}
