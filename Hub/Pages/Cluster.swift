//
//  Cluster.swift
//  Hub
//
//  Created by Dmitry Kozlov on 16/2/25.
//

import SwiftUI
import HubClient

enum OnlineStatus: Comparable {
  case online, unauthorized, offline
  var view: some View {
    Circle().fill(background.opacity(1)).frame(width: 6)
  }
  var background: Color {
    switch self {
    case .online: .blue
    case .offline: .red
    case .unauthorized: .orange
    }
  }
}

extension Hub {
  var onlineStatus: OnlineStatus {
    isConnected ? .online : .offline
  }
}

struct Cluster: View {
  @State var isCreating: Bool = false
  let hubs = Hubs.main
  var body: some View {
    NavigationStack {
      List {
        if isCreating {
          Create(isCreating: $isCreating)
        } else if !hubs.hasLocal {
          Button("Add local") {
            hubs.insert(with: Hub.Settings(name: "My Mac", address: HubClient.local))
          }
        }
        ForEach(hubs.list) { (hub: Hub) in
          VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
              Text(hub.settings.name)
              hub.onlineStatus.view
            }
            Text(hub.settings.address.description).font(.caption2).foregroundStyle(.secondary)
          }.contextMenu {
            Button("Remove") {
              hubs.remove(with: hub.settings)
            }
          }
        }
      }.toolbar {
        Button("Connect", systemImage: "plus", role: isCreating ? .cancel : nil) {
          isCreating.toggle()
        }.buttonBorderShape(.capsule)
      }.navigationTitle("Connections")
    }
  }
  struct Create: View {
    @State private var name = ""
    @State private var address = ""
    @Binding var isCreating: Bool
    private let hubs = Hubs.main
    var url: URL? {
      guard var components = URLComponents(string: address) else { return nil }
      components.hub()
      guard let url = components.url else { return nil }
      guard !url.absoluteString.isEmpty else { return nil }
      return url
    }
    var providedName: String? { name.isEmpty ? url?.name : name }
    var body: some View {
      VStack(alignment: .leading) {
        Text(url?.absoluteString ?? "Add connection")
          .font(.caption2).foregroundStyle(.secondary)
        TextField("Address", text: $address)
        TextField(url?.name ?? "Name", text: $name)
        if let url, let providedName {
          Button("Connect") {
            hubs.insert(with: Hub.Settings(name: providedName, address: url))
            self.name = ""
            self.address = ""
            self.isCreating = false
          }
        }
      }
    }
  }
}

private extension URLComponents {
  mutating func hub() {
    if host == nil, !path.isEmpty {
      var components = path.components(separatedBy: "/")
      host = components.removeFirst()
      if components.count > 0 {
        path = "/" + components.joined(separator: "/")
      } else {
        path = ""
      }
    }
    // Getting scheme if needed {
    if scheme == nil, let host, !host.isEmpty {
      scheme = host.isIp || host.isLocal ? "ws" : "wss"
    }
  }
}
private extension URL {
  var pathName: String {
    return path().components(separatedBy: "/")
      .last!.components(separatedBy: "?")[0]
  }
  var name: String? {
    guard let host = host() else { return nil }
    var name = host.secondDomain.capitalized
    let pathName = path().components(separatedBy: "/")
      .last!.components(separatedBy: "?")[0].capitalized
    if !pathName.isEmpty {
      name += " \(pathName)"
    }
    return name
  }
}
private extension String {
  var isIp: Bool {
    let ipv4Regex = /^((25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)$/
    let ipv6Regex = /^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$/
    return wholeMatch(of: ipv4Regex) != nil || self.wholeMatch(of: ipv6Regex) != nil
  }
  var isLocal: Bool {
    let components = components(separatedBy: ".")
    return components.count < 2 || components.last == "local" || components.last?.isEmpty ?? true
  }
  var secondDomain: String {
    let components = components(separatedBy: ".")
    guard components.count > 1 else { return self }
    return components[components.count - 2]
  }
}

#Preview {
  Cluster()
}
