//
//  Client.swift
//  Hub
//
//  Created by Dmitry Kozlov on 17/2/25.
//

import Foundation
import HubClient
import Combine

extension KeyChain {
  static let main = KeyChain(keyChain: "me.v57.hub")
}

@MainActor
let hub = Hub(name: "local")
@MainActor
@Observable class Hub {
  let name: String
  let client: HubClient
  var status: Status?
  var isConnected: Bool = false
  @ObservationIgnored
  var connectionTask: AnyCancellable?
  var permissions = Set<String>()
  init(name: String, url: URL = HubClient.local) {
    self.name = name
    self.client = HubClient(keyChain: .main)
    Task { try await keepUpdating() }
    connectionTask = client.isConnected.sink { [unowned self] isConnected in
      self.isConnected = isConnected
      if isConnected {
        Task { permissions = try await client.send("hub/permissions") }
      }
    }
  }
  func keepUpdating() async throws {
    do {
      for try await status: Status in client.values("hub/status") {
        self.status = status
      }
    } catch { }
  }
}

struct Status: Decodable, Hashable {
  let requests: Int
  let services: [Service]
  struct Service: Decodable, Hashable {
    let name: String
    let services: Int
    let disabled: Int
    let requests: Int
  }
}

@MainActor
@Observable
class Hubs {
  static let main = Hubs()
  var selected: Int?
  var hubs = [Hub]()
  var infos = [HubInfo]()
  var hasLocal: Bool { infos.contains(where: { $0.address.absoluteString.starts(with: "ws:") })}
  init() {
    load()
  }
  func insert(info: HubInfo) {
    if let index = infos.firstIndex(where: { $0.id == info.id }) {
      infos[index] = info
      selected = index
    } else {
      let hub = Hub(name: info.name, url: info.address)
      hubs.append(hub)
      infos.append(info)
      selected = self.hubs.count - 1
    }
    save()
  }
  func remove(info: HubInfo) {
    if let index = self.infos.firstIndex(where: { $0.id == info.id }) {
      infos.remove(at: index)
      hubs.remove(at: index)
      save()
    }
  }
  func save() {
    do {
      let data = try JSONEncoder().encode(infos)
      UserDefaults.standard.set(data, forKey: "hubs")
    } catch { }
  }
  func load() {
    guard let data = UserDefaults.standard.data(forKey: "hubs") else { return }
    do {
      infos = try JSONDecoder().decode([HubInfo].self, from: data)
      hubs = []
      for info in infos {
        let hub = Hub(name: info.name, url: info.address)
        hubs.append(hub)
      }
    } catch {}
  }
}
struct HubInfo: Codable, Identifiable, Hashable {
  var id: URL { address }
  var name: String
  var address: URL
}
