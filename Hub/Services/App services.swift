//
//  Video encoder service.swift
//  Hub
//
//  Created by Linux on 19.07.25.
//

import Foundation
import AVFoundation
import HubClient
import Combine

extension HubService.Group {
  func videoService() -> Self {
    app(App(header: .init(type: .app, name: "Video Encoder", path: "video/encode/ui"), body: [
      .fileOperation(.init(title: nil, value: "videos.mov", action: .init(path: "video/encode/hevc", body: .void)))
    ], data: [:]))
    .post("video/encode/hevc") { (request: EncodeRequest) in
      try await Self.encodeVideo(from: request.from, to: request.to)
    }
  }
  func imageService() -> Self {
    app(App(header: .init(type: .app, name: "Image Encoder", path: "image/encode/ui"), body: [
      .fileOperation(.init(title: nil, value: "images.heic", action: .init(path: "image/encode/heic", body: .void)))
    ], data: [:]))
    .post("image/encode/heic") { (request: EncodeRequest) in
      try await Self.encodeImage(from: request.from, to: request.to)
    }
  }
  func sensitiveContentService() -> Self {
    post("image/sensitive") { (url: URL) -> Bool in
      try await Self.download(from: url).isSensitive()
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
  var chat: HubService.Group?
  let video: HubService.Group
  let image: HubService.Group
  let sensitiveContent: HubService.Group
  var translation = TranslationGroups()
  @Published var translationEnabled = false
  private var enabled: Set<String> = [] {
    didSet {
      guard enabled != oldValue else { return }
      let list = enabled
      saveTask = Task {
        try await Task.sleep(for: .seconds(1))
        UserDefaults.standard.setValue(Array(list).sorted(), forKey: "services/\(hub.id)")
      }
    }
  }
  private var saveTask: Task<Void, Error>? {
    didSet { oldValue?.cancel() }
  }
  private var tasks = Set<AnyCancellable>()
  init(hub: Hub) {
    self.hub = hub
    enabled = Set(UserDefaults.standard.array(forKey: "services/\(hub.id)") as? [String] ?? [])
    if #available(macOS 26.0, iOS 26.0, *) {
      chat = hub.service.group(enabled: enabled.contains("text/llm")).chat()
    }
    video = hub.service.group(enabled: enabled.contains("video/encode")).videoService()
    image = hub.service.group(enabled: enabled.contains("image/encode")).imageService()
    sensitiveContent = hub.service.group(enabled: enabled.contains("image/sensitive")).sensitiveContentService()
    if #available(macOS 15.0, iOS 18.0, *) {
      translationEnabled = enabled.contains("text/translate")
      translationGroups(enabled: $translationEnabled)
    }
    assign(chat?.$isEnabled, to: "text/llm")
    assign(video.$isEnabled, to: "video/encode")
    assign(image.$isEnabled, to: "image/encode")
    assign(sensitiveContent.$isEnabled, to: "image/sensitive")
    assign($translationEnabled, to: "text/translate")
  }
  private func save() {
    enabled = Set(UserDefaults.standard.array(forKey: "services/\(hub.id)") as? [String] ?? [])
  }
  private func assign(_ publisher: Published<Bool>.Publisher?, to key: String) {
    publisher?.sink { [unowned self] isEnabled in
      if isEnabled {
        enabled.insert(key)
      } else {
        enabled.remove(key)
      }
    }.store(in: &tasks)
  }
}
