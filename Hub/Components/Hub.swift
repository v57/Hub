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
let hub = Hub()
@MainActor
@Observable class Hub {
  let client = HubClient(keyChain: .main)
  var status: Status?
  var isConnected: Bool = false
  @ObservationIgnored
  var connectionTask: AnyCancellable?
  init() {
    Task { try await keepUpdating() }
    connectionTask = client.isConnected.sink { [unowned self] isConnected in
      self.isConnected = isConnected
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

extension HubClient {
  func permissions() async throws -> [String] {
    try await send("hub/permissions")
  }
}
