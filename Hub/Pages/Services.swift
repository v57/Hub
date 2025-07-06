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
    }.navigationTitle(hub.isConnected ? "\(status?.requests ?? 0) requests" : "Disconnected").toolbar {
      if hub.isConnected {
        ForEach(hub.permissions.sorted(), id: \.self) { permission in
          PermissionView(permission: permission)
        }
      }
      Button("Copy Key", systemImage: "key.fill") {
        KeyChain.main.publicKey().copyToClipboard()
      }
    }.hubStream("hub/status", initial: Status(requests: 0, services: []), to: $status)
  }
  struct PermissionView: View {
    let permission: String
    var body: some View {
      switch permission {
      case "owner":
        Button {
          
        } label: {
          Image(systemName: "macbook.badge.shield.checkmark")
        }.accessibilityHint("Owner")
      default:
        Text(permission.prefix(8)).padding(.horizontal)
      }
    }
  }
}
struct Service: View {
  typealias Balancer = Status.BalancerType
  @Environment(Hub.self) private var hub
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
      HStack {
        if service.requests > 0 {
          Label("\(service.requests)", systemImage: "number")
        }
        if service.balancerType != .counter {
          Image(systemName: service.balancerType.icon).secondary()
        }
        if let running = service.running, running > 0 {
          Label("\(running)", systemImage: "clock.arrow.2.circlepath")
        }
        if let pending = service.pending, pending > 0 {
          Label("\(pending)", systemImage: "tray.full")
        }
      }.secondary().labelStyle(BadgeLabelStyle())
    }.contextMenu {
      Section("Load balancer") {
        ForEach(Balancer.all, id: \.rawValue) { balancer in
          AsyncButton(balancer.name, systemImage: balancer.icon) {
            try await update(balancer: balancer)
          }
        }
      }
    }
  }
  func update(balancer: Balancer) async throws {
    try await hub.client.send("hub/balancer/set", UpdateBalancer(path: service.name, type: balancer.rawValue))
  }
  private struct UpdateBalancer: Codable {
    let path: String
    let type: String
  }
  struct BadgeLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
      HStack(spacing: 4) {
        configuration.icon
        configuration.title
      }
    }
  }
}

extension Status.BalancerType {
  var icon: String {
    switch self {
    case .random: "dice"
    case .counter: "arrow.triangle.2.circlepath"
    case .first: "line.3.horizontal.decrease"
    case .available: "arrow.clockwise.circle"
    case .unknown: "Unknown"
    }
  }
  var name: LocalizedStringKey {
    switch self {
    case .random: "Random"
    case .counter: "Round-robin"
    case .first: "Queued Non Distributed"
    case .available: "Queued Distributed"
    case .unknown: "Unknown"
    }
  }
}

#Preview {
  Services()
    .environment(Hub.test)
}
