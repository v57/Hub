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

struct ConnectionsView: View {
  @State private var isCreating: Bool = false
  @State private var hubs = Hubs.main
  @State private var merging: Hub?
  @State var selected: Hub.ID?
  var body: some View {
    List(selection: $selected) {
      if isCreating {
        Create(isCreating: $isCreating)
      }
      ForEach(hubs.list) { (hub: Hub) in
        ItemView(hubs: hubs, merging: $merging).environment(hub)
          .id(hub.id)
      }.onMove { set, target in
        hubs.list.move(fromOffsets: set, toOffset: target)
        hubs.save()
      }.onDelete { index in
        let deleted = index.map { hubs.list[$0] }
        deleted.forEach { hub in
          hubs.remove(with: hub.settings)
        }
      }
    }.toolbar {
      if merging != nil {
        Button("Done") {
          self.merging = nil
        }
      }
      if !isCreating && hubs.list.isEmpty {
        Button("Add Local") {
          hubs.insert(with: Hub.Settings(name: "My Mac", address: HubClient.local))
        }
      }
      Button("Connect", systemImage: "plus", role: isCreating ? .cancel : nil) {
        isCreating.toggle()
      }.buttonBorderShape(.capsule)
        .navigationTitle("Connections")
        .task { selected = hubs.selected }
        .task(id: selected) { hubs.selected = selected }
    }
  }
  struct ItemView: View {
    let hubs: Hubs
    @Binding var merging: Hub?
    
    @Environment(Hub.self) private var hub
    var canBeMerged: Bool {
      guard let merging else { return false }
      return !merging.isMerged(to: hub) && !hub.isMerged(to: merging)
    }
    var body: some View {
      let isOwner = hub.isConnected && hub.permissions.contains("owner")
      HStack {
        VStack(alignment: .leading, spacing: 0) {
          HStack(spacing: 6) {
            Text(hub.settings.name)
            if isOwner {
              Text("owner").secondary()
            }
            hub.onlineStatus.view
          }
          Text(hub.settings.address.description).secondary()
          ForEach(hub.merge, id: \.address) { status in
            Text(status.address).secondary()
          }
        }.hubStream("hub/merge/status") { hub.merge = $0 }
        if let merging, merging.id != hub.id && isOwner {
          Spacer()
          if merging.isMerged(to: hub) {
            AsyncButton("Leave") {
              try await merging.unmerge(other: hub)
            }
          } else if canBeMerged {
            AsyncButton("Join") {
              try await merging.merge(other: hub)
            }
          }
        }
      }.contextMenu {
        if isOwner && merging == nil {
          Button("Merge") {
            merging = hub
          }
        }
        Button("Remove") {
          hubs.remove(with: hub.settings)
        }
      }
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
        Text(url?.absoluteString ?? "Add connection").secondary()
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
    if host == nil, !path.isEmpty || scheme != nil {
      var components = path.components(separatedBy: "/")
      if scheme != nil {
        host = scheme
        scheme = nil
        if let port = Int(components[0]) {
          self.port = port
          components.removeFirst()
        }
      } else {
        let host = components.removeFirst()
        if let port = Int(host) {
          self.port = port
          self.host = "localhost"
        } else {
          self.host = host
        }
      }
      if components.filter({ !$0.isEmpty }).count > 0 {
        path = "/" + components.joined(separator: "/")
      } else {
        path = ""
      }
    }
    // Getting scheme if needed {
    if let host, !host.isEmpty {
      if scheme == nil {
        scheme = host.isIp || host.isLocal ? "ws" : "wss"
      }
      if port == nil && scheme == "ws" {
        port = 1997
      }
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
    let dots = host.components(separatedBy: ".")
    if host.isIp {
      if let port, port != 1997 {
        return "\(host):\(port)"
      } else {
        return "\(host)"
      }
    } else if let port, dots.count == 1, port != 1997 {
      return port.description // localhost:1998 -> 1998
    } else {
      var name = host.secondDomain.capitalized
      let pathName = path().components(separatedBy: "/")
        .last!.components(separatedBy: "?")[0].capitalized
      if !pathName.isEmpty {
        name += " \(pathName)"
      }
      return name // apple.com -> Apple
    }
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
  ConnectionsView()
}

extension Hub {
  func isMerged(to hub: Hub) -> Bool {
    var addresses = Set<String>()
    return isMerged(address: settings.address.absoluteString, addresses: &addresses)
  }
  private func isMerged(address: String, addresses: inout Set<String>) -> Bool {
    for status in merge {
      guard addresses.insert(status.address).inserted else { continue }
      guard let hub = Hubs.main.list.first(where: { $0.settings.address.absoluteString == status.address })
      else { continue }
      guard hub.isMerged(address: address, addresses: &addresses) else { continue }
      return true
    }
    return false
  }
  func addOwner(_ key: String) async throws {
    try await client.send("auth/keys/add", KeyAdd(key: key, type: .key, permissions: ["owner"]))
  }
  func merge(other: Hub) async throws {
    let key: String = try await client.send("hub/key")
    try await other.client.send("auth/keys/add", KeyAdd(key: key, type: .key, permissions: ["merge"]))
    try await client.send("hub/merge/add", other.settings.address.absoluteString)
  }
  func unmerge(other: Hub) async throws {
    let key: String = try await client.send("hub/key")
    try await other.client.send("auth/keys/remove", key)
    try await client.send("hub/merge/remove", other.settings.address.absoluteString)
  }
  struct KeyAdd: Encodable {
    enum KeyType: String, Encodable {
      case key, hmac
    }
    let key: String
    let type: KeyType
    let permissions: [String]
  }
  struct MergeStatus: Decodable, Equatable {
    let address: String
    let error: String?
    let isConnected: Bool
  }
}
