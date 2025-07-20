//
//  Video encoder service.swift
//  Hub
//
//  Created by Linux on 19.07.25.
//

import Foundation
import AVFoundation
import HubClient

@MainActor
class EncoderService {
  let hub: Hub
  init(hub: Hub) {
    self.hub = hub
    _ = hub.service.app(App(header: .init(type: .app, name: "Video Encoder", path: "video/encode/ui"), body: [], data: [:]))
      .post("video/encode/hevc") { (request: EncodeRequest) in
        try await EncoderService.encode(from: request.from, to: request.to)
      }
  }
  struct EncodeRequest: Decodable, Sendable {
    let from: URL
    let to: URL
  }
  static func encode(from: URL, to: URL) async throws {
    let asset = AVURLAsset(url: from)
    let target = URL.temporaryDirectory.appending(path: UUID().uuidString + ".mov", directoryHint: .notDirectory)
    try await VideoEncoder().encode(from: asset, to: to, settings: .hevc(quality: 0.8, size: nil, frameReordering: true)) { _, _ in
      
    }
    var request = URLRequest(url: to)
    request.httpMethod = "PUT"
    defer { try? FileManager.default.removeItem(at: target) }
    _ = try await URLSession.shared.upload(for: request, fromFile: target)
  }
  struct ServiceAdd: Encodable {
    var add: [String]
    var addApps: [AddApp]
    struct AddApp: Encodable {
      var type: String
      var name: String
      var path: String
    }
  }
}
