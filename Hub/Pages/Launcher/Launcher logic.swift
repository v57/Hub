//
//  Launcher.swift
//  Hub
//
//  Created by Dmitry Kozlov on 1/6/25.
//

import SwiftUI

struct UnknownValueError: Error { }

// Launcher api
extension Hub {
  var launcher: Launcher { Launcher(hub: self) }
  struct Launcher {
    let hub: Hub
    func app(id: String) -> AppApi {
      AppApi(hub: hub, id: id)
    }
    func create(_ create: Create) async throws {
      try await hub.client.send("launcher/app/create", create)
    }
    func checkForUpdates() async throws {
      try await hub.client.send("launcher/update/check/all")
    }
    func updateAll() async throws {
      try await hub.client.send("launcher/update/all")
    }
    func pro(_ key: String) async throws {
      try await hub.client.send("launcher/pro", key)
    }
    struct AppApi {
      let hub: Hub
      let id: String
      func stop() async throws {
        try await hub.client.send("launcher/app/stop", id)
      }
      func start() async throws {
        try await hub.client.send("launcher/app/start", id)
      }
      func uninstall() async throws {
        try await hub.client.send("launcher/app/uninstall", id)
      }
    }
    struct App: Identifiable, Hashable {
      let id: String
      var info: AppInfo?
      var status: AppStatus?
    }
    struct Apps: Decodable, Hashable {
      var apps: [AppInfo]
    }
    struct Status: Decodable, Hashable {
      var apps: [AppStatus]
    }
    struct AppInfo: Decodable, Hashable {
      var name: String
      var active: Bool
      var restarts: Bool
      var updateAvailable: Bool
      var instances: Int
      enum CodingKeys: CodingKey {
        case name
        case active
        case restarts
        case updateAvailable
        case instances
      }
      
      init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.active = try container.decodeIfPresent(Bool.self, forKey: .active) ?? false
        self.restarts = try container.decodeIfPresent(Bool.self, forKey: .restarts) ?? false
        self.updateAvailable = try container.decodeIfPresent(Bool.self, forKey: .updateAvailable) ?? false
        self.instances = try container.decodeIfPresent(Int.self, forKey: .instances) ?? 1
      }
    }
    struct AppStatus: Decodable, Hashable {
      var name: String
      var checkingForUpdates: Bool?
      var updating: Bool?
      var crashes: Int
      var processes: [ProcessStatus]?
      var started: Date?
    }
    struct ProcessStatus: Decodable, Hashable, Identifiable {
      var id: Int { pid }
      var pid: Int
      var cpu: Double?
      var memory: Double?
    }
    struct Create: Codable {
      let name: String
      let active: Bool
      let restarts: Bool
      let setup: Setup
      
      private enum CodingKeys: CodingKey {
        case name, active, restarts
      }
      
      init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        active = try container.decode(Bool.self, forKey: .active)
        restarts = try container.decode(Bool.self, forKey: .restarts)
        setup = try Setup(from: decoder)
      }
      
      func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(active, forKey: .active)
        try container.encode(restarts, forKey: .restarts)
        try setup.encode(to: encoder)
      }
    }
    enum Setup: Codable {
      case bun(Bun)
      struct Bun: Codable {
        let repo: String
        let commit: String?
        let command: String?
      }
      case sh(Sh)
      struct Sh: Codable {
        let directory: String?
        let install: [String]?
        let uninstall: [String]?
        let run: String
      }
      
      private enum CodingKeys: CodingKey {
        case type
      }
      init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "bun":
          self = try .bun(.init(from: decoder))
        case "sh":
          self = try .sh(.init(from: decoder))
        default: throw UnknownValueError()
        }
      }
      
      func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .bun(let bun):
          try container.encode("bun", forKey: .type)
          try bun.encode(to: encoder)
        case .sh(let sh):
          try container.encode("sh", forKey: .type)
          try sh.encode(to: encoder)
        }
      }
    }
  }
}

#if PRO
@Observable
class Launcher {
  static var main = Launcher()
  var isInstalled: Bool = false
  var status: Status
  enum Status {
    case installed, offline, running, stopping
    case notInstalled
    case status(LocalizedStringKey), installationFailed
  }
  static var url: URL {
    URL.homeDirectory.appendingPathComponent("hub-launcher", conformingTo: .directory)
  }
  var url: URL { Launcher.url }
  var git: GitHub { GitHub(directory: url) }
  init() {
    if FileManager.default.fileExists(atPath: Launcher.url.path()) {
      status = .offline
    } else {
      status = .notInstalled
    }
  }
  func install() async {
    do {
      status = .status("Downloading")
      try await git.clone("v57/hub-launcher")
      status = .status("Installing")
      try await sh("""
source .zshrc
cd hub-launcher
bun i
""")
      status = .installed
    } catch {
      status = .installationFailed
    }
  }
  func launch() async {
    do {
      status = .status("Launching")
      try await sh("""
source .zshrc
if screen -ls | grep v57launcher >/dev/null; then
  screen -X -S v57launcher quit
fi
cd hub-launcher
screen -dmS v57launcher bun .
""")
    } catch {
      status = .offline
    }
  }
  func stop(hub: Hub) async {
    do {
      status = .stopping
      _ = try await hub.client.send("launcher/stop") as Int?
    } catch {
      status = .offline
    }
  }
  func update() async {
    try? await git.pull()
  }
  func checkForUpdates() async -> Bool {
    await git.checkForUpdates()
  }
}
#endif
