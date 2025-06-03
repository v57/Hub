//
//  Launcher.swift
//  Hub
//
//  Created by Dmitry Kozlov on 19/2/25.
//

import SwiftUI
import HubClient

struct LauncherView: View {
  typealias App = Hub.Launcher.App
  @MainActor
  @Observable class Manager {
    var apps: [App] = []
    func syncApps() async {
      guard hub.isLauncherConnected else { return }
      print("syncApps")
      do {
        self.apps = try await hub.launcher.info().apps.map { App(id: $0.name, info: $0) }
      } catch { print(error) }
    }
    func syncStatus() async {
      guard hub.isLauncherConnected else { return }
      print("syncStatus")
      do {
        while true {
          let apps = try await hub.launcher.status()
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
#endif
  @State var manager = Manager()
  @State var creating = false
  var body: some View {
    let isConnected = hub.isLauncherConnected
    List {
      LauncherCell()
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
        switch Launcher.main.status {
        case .running, .stopping:
          launcher.status = .offline
        default: break
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
  struct LauncherCell: View {
#if PRO
    var launcher: Launcher { .main }
    var status: Launcher.Status {
      launcher.status
    }
    @State var updatesAvailable = false
#endif
    var body: some View {
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
              case .status, .stopping: break
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
        Spacer()
        if app.id == "Hub Lite" {
          AsyncButton("Upgrade to Pro") {
            try await hub.launcher.pro(KeyChain.main.publicKey())
          }.buttonStyle(.link)
        }
      }.contextMenu {
        if let status = app.status {
          if status.isRunning {
            AsyncButton("Stop", systemImage: "stop.fill") {
              try await hub.launcher.app(id: app.id).stop()
              await manager.syncApps()
            }
          } else {
            AsyncButton("Start", systemImage: "play.fill") {
              try await hub.launcher.app(id: app.id).start()
              await manager.syncApps()
            }
            AsyncButton("Uninstall", systemImage: "trash.fill", role: .destructive) {
              try await hub.launcher.app(id: app.id).uninstall()
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
}
#if PRO
extension Launcher.Status {
  var statusText: LocalizedStringKey {
    switch self {
    case .notInstalled: "Not installed"
    case .installationFailed: "Installation failed"
    case .installed: "Installed"
    case .status(let s): s
    case .stopping: "Stopping"
    case .offline: "Offline"
    case .running: "Running"
    }
  }
  var buttonTitle: LocalizedStringKey? {
    switch self {
    case .notInstalled: "Install"
    case .installed, .offline: "Launch"
    case .running: "Stop"
    case .stopping: "Stopping"
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
