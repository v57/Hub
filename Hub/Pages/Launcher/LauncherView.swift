//
//  Launcher.swift
//  Hub
//
//  Created by Dmitry Kozlov on 19/2/25.
//

import SwiftUI

struct LauncherView: View {
  @Observable class Manager {
    var apps: [App] = []
    var isConnected: Bool {
      hub.status?.services.contains(where: {
        $0.name == "launcher"
      }) ?? false
    }
    func syncApps() async {
      guard isConnected else { return }
      print("syncApps")
      do {
        let apps: Apps = try await hub.client.send("launcher/info")
        self.apps = apps.apps.map { App(id: $0.name, info: $0) }
      } catch { print(error) }
    }
    func syncStatus() async {
      guard isConnected else { return }
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
  }
  
#if PRO
  var launcher: Launcher { .main }
  var status: Launcher.Status {
    launcher.status
  }
#endif
  @State var manager = Manager()
  @State var creating = false
  @State var updatesAvailable = false
  var body: some View {
    let isConnected = hub.status?.services.contains(where: {
      $0.name.starts(with: "launcher/")
    }) ?? false
    List {
      HStack {
        VStack(alignment: .leading) {
          Text("Launcher")
          #if PRO
          Text(status.statusText).font(.caption2)
            .foregroundStyle(.secondary)
          #endif
        }
        Spacer()
#if PRO
        
        HStack {
          if updatesAvailable {
            AsyncButton("Update", systemImage: "square.and.arrow.down.fill") {
              await launcher.update()
              updatesAvailable = false
            }.help("Update")
          }
          if let buttonIcon = status.buttonIcon, let buttonTitle = status.buttonTitle {
            AsyncButton(buttonTitle, systemImage: buttonIcon) {
              switch status {
              case .notInstalled, .installationFailed:
                await Launcher.main.install()
              case .installed, .offline:
                await Launcher.main.launch()
              case .running:
                await Launcher.main.stop()
              case .status: break
              }
            }.help(buttonTitle)
          }
        }.labelStyle(.iconOnly).buttonStyle(.borderless)
#endif
      }.contextMenu {
        if updatesAvailable {
          AsyncButton("Update") {
            await launcher.update()
            updatesAvailable = false
          }
        } else {
          AsyncButton("Check for Updates") {
            updatesAvailable = await launcher.checkForUpdates()
          }
        }
      }
      if isConnected {
        ForEach(manager.apps) { app in
          AppView(app: app)
        }.environment(manager)
      }
    }.toolbar {
      Button("Create", systemImage: "plus") {
        creating.toggle()
      }.labelStyle(.iconOnly)
    }.sheet(isPresented: $creating) {
      CreateApp().padding().frame(maxWidth: 300)
    }.task(id: isConnected) {
#if PRO
      if isConnected {
        launcher.status = .running
      } else {
        if case .running = Launcher.main.status {
          launcher.status = .offline
        }
      }
#endif
    }.task(id: isConnected) {
      guard isConnected else { return }
      await manager.syncApps()
    }.task(id: isConnected) {
      guard isConnected else { return }
      await manager.syncStatus()
    }
  }
  struct AppView: View {
    @Environment(Manager.self) var manager
    let app: App
    var body: some View {
      HStack {
        VStack(alignment: .leading) {
          Text(app.id)
          if let status {
            status.font(.caption2).foregroundStyle(.secondary)
          }
        }
      }.contextMenu {
        if let status = app.status {
          if status.isRunning {
            AsyncButton("Stop", systemImage: "stop.fill") {
              try await hub.client.send("launcher/app/stop", app.id)
              await manager.syncApps()
            }
          } else {
            AsyncButton("Start", systemImage: "play.fill") {
              try await hub.client.send("launcher/app/start", app.id)
              await manager.syncApps()
            }
            AsyncButton("Uninstall", systemImage: "trash.fill", role: .destructive) {
              try await hub.client.send("launcher/app/uninstall", app.id)
              await manager.syncApps()
            }
          }
        }
      }.labelStyle(.titleAndIcon)
    }
    var status: Text? {
      if let status = app.status {
        if status.isRunning, let mem = status.memory {
          if let cpu = status.cpu {
            return Text("\(Int(cpu))% \(mem.description)MB")
          } else {
            return Text("\(mem.description)MB")
          }
        }
      }
      return Text("Not running")
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
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.name = try container.decode(String.self, forKey: .name)
      self.active = try container.decodeIfPresent(Bool.self, forKey: .active) ?? false
      self.restarts = try container.decodeIfPresent(Bool.self, forKey: .restarts) ?? false
    }
  }
  struct AppStatus: Decodable, Hashable {
    var name: String
    var isRunning: Bool
    var crashes: Int
    var cpu: Double?
    var memory: Double?
  }
}
#if PRO
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
#endif

#Preview {
  LauncherView().frame(width: 300, height: 200)
}
