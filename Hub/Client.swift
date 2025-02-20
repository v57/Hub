//
//  Client.swift
//  Hub
//
//  Created by Dmitry Kozlov on 17/2/25.
//

import Foundation
import HubClient

let hub = Hub()
@Observable class Hub {
  @MainActor
  let client = HubClient()
  var status: Status?
  var attempts = 1
  init() {
    Task {
      try await keepUpdating()
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
