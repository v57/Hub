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
let hub = Hub(settings: .init(name: "Local", address: HubClient.local))
@MainActor
@Observable class Hub: @preconcurrency Identifiable {
  var id: Settings.ID { settings.id }
  var settings: Settings
  let client: HubClient
  var status: Status?
  var isConnected: Bool = false
  @ObservationIgnored
  var connectionTask: AnyCancellable?
  var permissions = Set<String>()
  init(settings: Settings) {
    self.settings = settings
    self.client = HubClient(settings.address, keyChain: .main)
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
  struct Settings: Codable, Identifiable, Hashable {
    var id: URL { address }
    var name: String
    var address: URL
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
  var selected: Hub.ID?
  var list = [Hub]()
  var selectedHub: Hub? {
    guard let selected else { return nil }
    return list.first(where: { $0.id == selected })
  }
  var hasLocal: Bool { list.contains(where: { $0.settings.address.absoluteString.starts(with: "ws:") })}
  init() {
    load()
  }
  func select(_ hub: Hub.ID?) {
    guard selected != hub else { return }
    selected = hub
    UserDefaults.standard.set(self.selected, forKey: "selected")
  }
  func insert(with settings: Hub.Settings) {
    if let index = list.firstIndex(where: { $0.id == settings.id }) {
      list[index].settings = settings
    } else {
      let hub = Hub(settings: settings)
      list.append(hub)
    }
    selected = settings.id
    UserDefaults.standard.set(self.selected, forKey: "selected")
    save()
  }
  func remove(with settings: Hub.Settings) {
    guard let index = self.list.firstIndex(where: { $0.id == settings.id }) else { return }
    if let selected, selected == settings.id {
      self.selected = list.first?.id
      UserDefaults.standard.set(self.selected, forKey: "selected")
    }
    list[index].client.stop()
    list.remove(at: index)
    save()
  }
  func save() {
    do {
      let data = try JSONEncoder().encode(list.map(\.settings))
      UserDefaults.standard.set(data, forKey: "hubs")
    } catch { }
  }
  func load() {
    guard let data = UserDefaults.standard.data(forKey: "hubs") else { return }
    do {
      list = []
      for settings in try JSONDecoder().decode([Hub.Settings].self, from: data) {
        let hub = Hub(settings: settings)
        list.append(hub)
      }
      if let selected = UserDefaults.standard.url(forKey: "selected") {
        self.selected = selected
      }
    } catch {}
  }
}
