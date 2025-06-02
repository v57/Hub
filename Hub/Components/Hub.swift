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
  var attempts = 1
  @ObservationIgnored
  var connectionTask: AnyCancellable?
  init() {
    Task {
      try await keepUpdating()
    }
    connectionTask = client.isConnected.sink { [unowned self] isConnected in
      self.isConnected = isConnected
    }
  }
  func keepUpdating() async throws {
    do {
      while true {
        let status = try? await client.status()
        self.status = status
        if status?.services != self.status?.services {
          attempts = 1
        } else {
          attempts += 1
        }
        try await Task.sleep(for: .milliseconds(min(attempts, 100) * 100))
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
    let requests: Int
  }
}

extension HubClient {
  func status() async throws -> Status {
    try await send("hub/status")
  }
}
