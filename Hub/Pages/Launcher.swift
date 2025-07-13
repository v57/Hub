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
    var active: Set<String> = []
    func syncApps(hub: Hub) async {
      do {
        for try await apps: Hub.Launcher.Apps in hub.client.values("launcher/info") {
          active = Set(apps.apps.map(\.name))
          var array = self.apps.filter { active.contains($0.id) }
          var isChanged = array.count != self.apps.count
          apps.apps.forEach { info in
            if let index = array.firstIndex(where: { $0.id == info.name }) {
              if array[index].info != info {
                isChanged = true
                array[index].info = info
              }
            } else {
              isChanged = true
              array.append(.init(id: info.name, info: info))
            }
          }
          if isChanged {
            self.apps = array
          }
        }
      } catch is CancellationError {
        
      } catch {
        print("syncApps", error)
      }
    }
    func syncStatus(hub: Hub) async {
      do {
        for try await apps: Hub.Launcher.Status in hub.client.values("launcher/status") {
          var array = self.apps
          var isChanged = false
          apps.apps.forEach { status in
            guard let index = array.firstIndex(where: { $0.id == status.name }) else { return }
            guard array[index].status != status else { return }
            isChanged = true
            array[index].status = status
          }
          if isChanged {
            self.apps = array
          }
        }
      } catch is CancellationError {
        
      } catch {
        print("syncStatus", error)
      }
    }
  }
  
#if PRO
  var launcher: Launcher { .main }
#endif
  @Environment(Hub.self) var hub
  @State var editing: Hub.Launcher.AppInfo?
  @State var manager = Manager()
  @State var hasLauncher: Bool = false
  @State var creating = false
  @State var openStore = false
  var body: some View {
    let task = TaskId(hub: hub.id, isConnected: hub.isConnected && hasLauncher)
    List {
      LauncherCell()
      if task.isConnected {
        ListView(editing: $editing)
        Button("Get More", systemImage: "arrow.down.circle.fill") {
          withAnimation {
            openStore = true
          }
        }.buttonStyle(ActionButtonStyle())
      }
    }.toolbar {
      if task.isConnected {
        ToolbarView(creating: $creating)
      }
    }.sheet(isPresented: $creating) {
      CreateApp().padding().frame(maxWidth: 300)
    }.sheet(item: $editing) {
      EditApp(app: $0).environment(hub).frame(minHeight: 300)
    }.navigationDestination(isPresented: $openStore) {
      StoreView().environment(manager).environment(hub)
    }.task(id: task) {
#if PRO
      if task.isConnected {
        launcher.status = .running
      } else {
        switch Launcher.main.status {
        case .running, .stopping:
          launcher.status = .offline
        default: break
        }
      }
#endif
    }.task(id: task) {
      guard task.isConnected else { return }
      await manager.syncStatus(hub: hub)
    }.task(id: task) {
      guard task.isConnected else { return }
      await manager.syncApps(hub: hub)
    }.hubStream("hub/status") { (status: Status) in
      hasLauncher = status.contains(service: "launcher")
    }.environment(manager)
  }
  struct ListView: View {
    @Environment(LauncherView.Manager.self) var manager
    @Binding var editing: Hub.Launcher.AppInfo?
    var body: some View {
      ForEach(manager.apps) { app in
        AppView(app: app, editing: $editing)
      }
    }
  }
  struct ToolbarView: View {
    @Environment(Hub.self) var hub
    @Environment(LauncherView.Manager.self) var manager
    @Binding var creating: Bool
    var updateAvailable: Bool {
      manager.apps.contains(where: { $0.info?.updateAvailable ?? false })
    }
    var isUpdating: Bool {
      manager.apps.contains(where: { $0.status?.updating ?? false })
    }
    var isCheckingForUpdates: Bool {
      manager.apps.contains(where: { $0.status?.checkingForUpdates ?? false })
    }
    var body: some View {
      if updateAvailable && !isUpdating {
        AsyncButton("Update All", systemImage: "arrow.down.circle") {
          try await hub.launcher.updateAll()
        }
      }
      if !isCheckingForUpdates {
        AsyncButton("Check for Updates", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") {
          try await hub.launcher.checkForUpdates()
        }
      }
      Button("Create", systemImage: "plus") {
        creating.toggle()
      }.labelStyle(.iconOnly)
    }
  }
  struct TaskId: Hashable {
    var hub: Hub.ID
    var isConnected: Bool
  }
  struct LauncherCell: View {
#if PRO
    var launcher: Launcher { .main }
    var status: Launcher.Status {
      launcher.status
    }
    @State var updatesAvailable = false
    @Environment(Hub.self) var hub
#endif
    var body: some View {
      HStack {
        VStack(alignment: .leading) {
          Text("Launcher")
          #if PRO
          Text(status.statusText).secondary()
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
                await Launcher.main.stop(hub: hub)
              case .status, .stopping: break
              }
            }.help(buttonTitle)
          }
        }.labelStyle(.iconOnly).buttonStyle(.borderless)
#endif
      }.contextMenu {
#if PRO
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
#endif
      }
    }
  }
  struct AppView: View {
    @Environment(Hub.self) var hub
    @Environment(Manager.self) var manager
    var installationStatus: LocalizedStringKey? {
      guard let status = app.status else { return nil }
      if status.updating ?? false {
        return "Updating"
      } else if status.checkingForUpdates ?? false {
        return "Checking for updates"
      } else if app.info?.updateAvailable ?? false {
        return "Update available"
      } else {
        return nil
      }
    }
    let app: App
    @Binding var editing: Hub.Launcher.AppInfo?
    @State var instances: Int = 0
    @State var showsInstances = false
    var body: some View {
      HStack(alignment: .top) {
        VStack(alignment: .leading) {
          HStack {
            Text(app.id)
            if let installationStatus {
              Text(installationStatus).badgeStyle()
            }
          }
          HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading) {
              ForEach(app.status?.processes ?? []) { process in
                status(process: process)
              }
            }
            if (app.status?.processes?.count ?? 0) > 0 {
              if let date = app.status?.started {
                Text(date, style: .relative)
              }
            }
          }.secondary()
        }
        Spacer()
        if showsInstances || (app.info?.instances ?? 0) > 1 {
          HStack {
            Text("\(instances)").secondary()
            Stepper("Instances", value: $instances)
              .labelsHidden()
              .task(id: instances) { try? await updateInstances() }
          }
        }
        if app.id == "Hub Lite" {
          AsyncButton("Upgrade to Pro") {
            try await hub.launcher.pro(KeyChain.main.publicKey())
          }.buttonStyle(.borderedProminent)
        }
      }.contextMenu {
        if let info = app.info {
          if info.active {
            if let info = app.info, info.instances == 1 {
              Button("Cluster", systemImage: "list.number") {
                showsInstances = true
              }
            }
            if let app = app.info {
              Button("Edit", systemImage: "gear") {
                editing = app
              }
            }
            AsyncButton("Stop", systemImage: "stop.fill") {
              try await hub.launcher.app(id: app.id).stop()
            }
          } else {
            AsyncButton("Start", systemImage: "play.fill") {
              try await hub.launcher.app(id: app.id).start()
            }
            AsyncButton("Uninstall", systemImage: "trash.fill", role: .destructive) {
              try await hub.launcher.app(id: app.id).uninstall()
            }
          }
        }
      }.labelStyle(.titleAndIcon).task(id: app.info?.instances) {
        guard let info = app.info else { return }
        instances = info.instances
      }
    }
    func status(process: Hub.Launcher.ProcessStatus) -> Text? {
      if let mem = process.memory {
        if let cpu = process.cpu {
          return Text("\(Int(cpu))% \(mem.description)MB")
        } else {
          return Text("\(mem.description)MB")
        }
      } else {
        return Text("Not running")
      }
    }
    func updateInstances() async throws {
      guard instances > 0 else { return }
      guard let info = app.info else { return }
      guard instances != info.instances else { return }
      guard instances <= 1024 else { return }
      if !showsInstances {
        showsInstances = true
      }
      try await hub.client.send("launcher/app/cluster", SetInstances(name: info.name, count: instances))
    }
    struct SetInstances: Encodable {
      let name: String
      let count: Int
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
  LauncherView().frame(width: 500, height: 200)
    .environment(Hub.test)
}
