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
  init() {
    Task {
      try await keepUpdating()
    }
  }
  func keepUpdating() async throws {
    do {
      while true {
        status = try? await client.status()
        try await Task.sleep(for: .seconds(5))
      }
    } catch { }
  }
}

struct Status: Decodable {
  let requests: Int
  let services: [Service]
  struct Service: Decodable {
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
