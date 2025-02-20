//
//  Launcher.swift
//  Hub
//
//  Created by Dmitry Kozlov on 19/2/25.
//

#if os(macOS)
import SwiftUI

struct LauncherView: View {
  var launcher: Launcher { .main }
  @State var apps: [App] = []
  var status: Launcher.Status {
    launcher.status
  }
  var body: some View {
    let isConnected = hub.status?.services.contains(where: {
      $0.name == "launcher"
    }) ?? false
    List {
      HStack {
        VStack(alignment: .leading) {
          Text("Launcher")
          Text(status.statusText).font(.caption2)
            .foregroundStyle(.secondary)
        }
        Spacer()
        if let buttonIcon = status.buttonIcon {
          Button {
            Task {
              switch status {
              case .notInstalled, .installationFailed:
                await Launcher.main.install()
              case .installed, .offline:
                await Launcher.main.launch()
              case .running:
                await Launcher.main.stop()
              case .status: break
              }
            }
          } label: { Image(systemName: buttonIcon) }.buttonStyle(.borderless)
        }
      }.contextMenu {
        Button("Update") {
          Task {
            
          }
        }
      }
      if isConnected {
        ForEach(apps) { app in
          AppView(app: app)
        }
      }
    }.task(id: isConnected) {
      if isConnected {
        launcher.status = .running
      } else {
        if case .running = Launcher.main.status {
          launcher.status = .offline
        }
      }
    }.task(id: isConnected) {
      guard isConnected else { return }
      await syncApps()
    }.task(id: isConnected) {
      guard isConnected else { return }
      await syncStatus()
    }
  }
  func syncApps() async {
    print("syncApps")
    do {
      let apps: Apps = try await hub.client.send("launcher/info")
      self.apps = apps.apps.map { App(id: $0.name, info: $0) }
    } catch { print(error) }
  }
  func syncStatus() async {
    print("syncStatus")
    do {
      while true {
        let apps: Status = try await hub.client.send("launcher/status")
        if apps.apps.count != self.apps.count {
          await syncApps()
        }
        apps.apps.forEach { status in
          guard let index = self.apps.firstIndex(where: { $0.id == status.name }) else { return }
          self.apps[index].status = status
        }
        try await Task.sleep(for: .seconds(0.5))
      }
    } catch {
      print(error)
    }
  }
  struct AppView: View {
    let app: App
    var body: some View {
      HStack {
        VStack(alignment: .leading) {
          Text(app.id)
          if let status {
            status.font(.caption2).foregroundStyle(.secondary)
          }
        }
      }
    }
    var status: Text? {
      if let info = app.info, !info.active {
        return Text("Not running")
      } else if let status = app.status, let mem = status.memory {
        if let cpu = status.cpu {
          return Text("\(Int(cpu))% \(mem.description)MB")
        } else {
          return Text("\(mem.description)MB")
        }
      } else {
        return nil
      }
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
    enum CodingKeys: CodingKey {
      case name
      case active
      case restarts
    }
    
    init(from decoder: any Decoder) throws {
      let container: KeyedDecodingContainer<LauncherView.AppInfo.CodingKeys> = try decoder.container(keyedBy: LauncherView.AppInfo.CodingKeys.self)
      self.name = try container.decode(String.self, forKey: .name)
      self.active = try container.decodeIfPresent(Bool.self, forKey: .active) ?? false
      self.restarts = try container.decodeIfPresent(Bool.self, forKey: .restarts) ?? false
    }
  }
  struct AppStatus: Decodable, Hashable {
    var name: String
    var crashes: Int
    var cpu: Double?
    var memory: Double?
  }
}
extension Launcher.Status {
  var statusText: LocalizedStringKey {
    switch self {
    case .notInstalled: "Not installed"
    case .installationFailed: "Installation failed"
    case .installed: "Installed"
    case .status(let s): s
    case .offline: "Offline"
    case .running: "Running"
    }
  }
  var buttonTitle: LocalizedStringKey? {
    switch self {
    case .notInstalled: "Install"
    case .installed, .offline: "Launch"
    case .running: "Stop"
    default: nil
    }
  }
  var buttonIcon: String? {
    switch self {
    case .notInstalled: "plus"
    case .installed, .offline: "play.fill"
    case .running: "pause.fill"
    default: nil
    }
  }
}

@Observable
class Launcher {
  static var main = Launcher()
  var isInstalled: Bool = false
  var status: Status
  enum Status {
    case installed, offline, running
    case notInstalled
    case status(LocalizedStringKey), installationFailed
  }
  static var url: URL {
    .homeDirectory.appendingPathComponent("hub-launcher", conformingTo: .directory)
  }
  var url: URL { Launcher.url }
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
      try await sh("git clone https://github.com/v57/hub-launcher")
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
  func stop() async {
    do {
      status = .status("Stopping")
      _ = try await hub.client.send("launcher/stop") as Int?
    } catch {
      status = .offline
    }
  }
  func update() async {
    try? await sh("git pull", from: url)
  }
}

#Preview {
  LauncherView().frame(width: 300, height: 200)
}
#endif
