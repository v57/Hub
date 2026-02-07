//
//  Hub state.swift
//  Hub
//
//  Created by Linux on 07.02.26.
//

import Foundation
import Combine
import SwiftUI

@MainActor
struct HubStateStorage {
  let users = Sync("hub/connections", [UserConnections.User]())
  let groups = Sync("hub/group/list", GroupList())
  let permissions = Sync("hub/group/names", PermissionList())
  
  @MainActor @Observable
  class Sync<T: Decodable> {
    @ObservationIgnored let path: String
    @ObservationIgnored weak var subscription: AnyCancellable?
    var value: T
    init(_ path: String, _ defaultValue: T) {
      self.value = defaultValue
      self.path = path
    }
    func subscribe(hub: Hub) -> AnyCancellable {
      if let subscription {
        return subscription
      } else {
        let path = path
        let subscription = Task { [weak self] in
          do {
            for try await value: T in hub.client.values(path) {
              EventDelayManager.main.execute {
                self?.value = value
              }
            }
          } catch {
            print("Catch", error)
          }
          print("Done")
        }.cancellable()
        self.subscription = subscription
        return subscription
      }
    }
  }
}

@MainActor
@propertyWrapper
struct HubState<T: Decodable>: DynamicProperty {
  @Environment(Hub.self) var hub
  typealias Path = KeyPath<HubStateStorage, HubStateStorage.Sync<T>>
  @State var storage = Storage()
  let path: Path
  var wrappedValue: T {
    storage.subscribeIfNeeded(hub: hub, path: path)
    return hub.state[keyPath: path].value
  }
  var projectedValue: Binding<T> {
    Binding(get: { hub.state[keyPath: path].value }, set: { hub.state[keyPath: path].value = $0 })
  }
  init(_ path: Path) {
    self.path = path
  }
  class Storage {
    var hub: Hub?
    var subscription: AnyCancellable?
    @MainActor
    func subscribeIfNeeded(hub: Hub, path: Path) {
      guard self.hub?.id != hub.id else { return }
      self.hub = hub
      subscription = hub.state[keyPath: path].subscribe(hub: hub)
    }
  }
}
