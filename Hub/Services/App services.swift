//
//  Video encoder service.swift
//  Hub
//
//  Created by Linux on 19.07.25.
//

import Foundation
import AVFoundation
import HubClient

extension HubService {
  @discardableResult
  func videoService() -> Self {
    app(App(header: .init(type: .app, name: "Video Encoder", path: "video/encode/ui"), body: [
      .fileOperation(.init(title: nil, value: "videos.mov", action: .init(path: "video/encode/hevc", body: .void)))
    ], data: [:]))
    .app(App(header: .init(type: .app, name: "Image Encoder", path: "image/encode/ui"), body: [
      .fileOperation(.init(title: nil, value: "images.heic", action: .init(path: "image/encode/heic", body: .void)))
    ], data: [:]))
    .post("video/encode/hevc") { (request: EncodeRequest) in
      try await HubService.encodeVideo(from: request.from, to: request.to)
    }
    .post("image/encode/heic") { (request: EncodeRequest) in
      print(request)
      try await HubService.encodeImage(from: request.from, to: request.to)
    }
  }
  struct EncodeRequest: Decodable, Sendable {
    let from: URL
    let to: URL
  }
  static func encodeImage(from: URL, to: URL) async throws {
    let heic = try await data(from: from).heic(quality: 0.8, metadata: false)
    try await upload(data: heic, to: to)
  }
  static func encodeVideo(from: URL, to: URL) async throws {
    let url = try await download(from: from)
    let asset = AVURLAsset(url: url)
    let target = URL.temporaryDirectory.appending(path: UUID().uuidString + ".mov", directoryHint: .notDirectory)
    try await VideoEncoder().encode(from: asset, to: target, settings: .hevc(quality: 0.6, size: nil, frameReordering: true)) { _, _ in }
    try await upload(file: target, to: to)
  }
  static func download(from: URL) async throws -> URL {
    let (tempDownload, _) = try await URLSession.shared.download(from: from)
    let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).\(from.lastPathComponent.components(separatedBy: ".").last!)", directoryHint: .notDirectory)
    try FileManager.default.moveItem(at: tempDownload, to: url)
    return url
  }
  static func data(from: URL) async throws -> Data {
    try await URLSession.shared.data(from: from).0
  }
  static func upload(file: URL, to: URL) async throws {
    var request = URLRequest(url: to)
    request.httpMethod = "PUT"
    defer { try? FileManager.default.removeItem(at: file) }
    _ = try await URLSession.shared.upload(for: request, fromFile: file)
  }
  static func upload(data: Data, to: URL) async throws {
    var request = URLRequest(url: to)
    request.httpMethod = "PUT"
    _ = try await URLSession.shared.upload(for: request, from: data)
  }
}

@MainActor
class AppServices {
  let hub: Hub
  init(hub: Hub) {
    self.hub = hub
    hub.service.videoService()
  }
}
