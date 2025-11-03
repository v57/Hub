//
//  Home.swift
//  Hub
//
//  Created by Linux on 02.11.25.
//

import SwiftUI
import HubClient

struct HomeView: View {
  enum TextFieldFocus: Hashable {
    case joinHubAddress
    case joinHubName
  }
  @FocusState var focus: TextFieldFocus?
  var isFocusing: Bool {
    focus == .joinHubAddress || focus == .joinHubName
  }
  @State var hubs = Hubs.main
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading) {
          Text("Hubs").sectionTitle()
          LazyVGrid(columns: [.init(.adaptive(minimum: isFocusing ? 360 : 180))]) {
            JoinHubView(focus: $focus)
            Text("Make your own").blockBackground()
            ForEach(Hubs.main.list) { hub in
              HubView(hub: hub).blockBackground()
            }
          }.animation(.smooth, value: isFocusing)
          ForEach(Hubs.main.list) { hub in
            HubSection().environment(hub)
          }
          Text("My Apps").sectionTitle()
          LazyVGrid(columns: [.init(.adaptive(minimum: 180))]) {
            ForEach(AppServicesView.Service.allCases, id: \.self) { item in
              ServiceContent(item: item, isSharing: nil)
            }
          }
          Text("Support this Project").sectionTitle()
          SupportView()
        }.animation(.smooth, value: hubs.list.count)
      }.safeAreaPadding(.horizontal).navigationTitle("Home").scrollDismissesKeyboard(.immediately)
    }
  }
  struct HubSection: View {
    typealias App = Hub.Launcher.App
    @Environment(Hub.self) var hub
    @State var manager = LauncherView.Manager()
    @State var hasLauncher: Bool = false
    @State var pending: [SecurityView.PendingAuthorization] = []
    @State var status = Status(requests: 0, services: [])
    var body: some View {
      let task = LauncherView.TaskId(hub: hub.id, isConnected: hub.isConnected && hasLauncher)
      HStack {
        Text(hub.settings.name).sectionTitle(padding: false)
        if hub.permissions.contains("owner") {
          Text("owner").secondary()
        }
        Spacer()
        if hub.permissions.contains("owner") {
          NavigationLink {
            StoreView().environment(manager).environment(hub)
          } label: {
            Label("Get apps", systemImage: "arrow.down.circle.fill")
          }
        }
      }.padding(.top, 16).padding(.trailing)
      LazyVGrid(columns: [.init(.adaptive(minimum: 180))]) {
        if hub.permissions.contains("owner") {
          if !status.services.isEmpty {
            NavigationLink {
              Services().environment(hub)
            } label: {
              ServicesView(status: status)
            }.buttonStyle(.plain)
          }
          if !pending.isEmpty {
            PermissionsView(pending: pending)
          }
        }
        ForEach(manager.apps) { app in
          AppView(app: app)
        }
        if status.hasStorage {
          NavigationLink {
            StorageView().environment(hub)
          } label: {
            Label("Files", systemImage: "folder.fill").blockBackground()
          }.buttonStyle(.plain)
        } else if hub.permissions.contains("owner") {
          NavigationLink {
            
          } label: {
            Label("Connect Storage", systemImage: "shippingbox.fill").blockBackground()
          }
        }
      }.task(id: task) {
        guard task.isConnected else { return }
        await manager.syncStatus(hub: hub)
      }.task(id: task) {
        guard task.isConnected else { return }
        await manager.syncApps(hub: hub)
      }.hubStream("hub/status") { (status: Status) in
        hasLauncher = status.contains(service: "launcher")
      }.hubStream("hub/permissions/pending", initial: [], to: $pending)
        .hubStream("hub/status", initial: Status(requests: 0, services: []), to: $status)
    }
    struct ServicesView: View {
      @Environment(Hub.self) var hub
      let status: Status
      var body: some View {
        VStack(alignment: .leading) {
          Text("Services")
          ForEach(status.services.sorted(by: { $0.requests > $1.requests }).prefix(3), id: \.name) { service in
            HStack {
              VStack(alignment: .leading) {
                Text(service.name).foregroundStyle(.primary)
                HStack {
                  if service.requests > 0 {
                    Label("\(service.requests)", systemImage: "number")
                  }
                  if service.balancerType != .counter {
                    Image(systemName: service.balancerType.icon).secondary()
                  }
                  if let running = service.running, running > 0 {
                    Label("\(running)", systemImage: "clock.arrow.2.circlepath")
                  }
                  if let pending = service.pending, pending > 0 {
                    Label("\(pending)", systemImage: "tray.full")
                  }
                }
              }.secondary()
            }
          }
        }.blockBackground()
      }
    }
    struct PermissionsView: View {
      @Environment(Hub.self) var hub
      let pending: [SecurityView.PendingAuthorization]
      var body: some View {
        VStack(alignment: .leading) {
          Text("Service requests")
          ForEach(pending.prefix(3), id: \.id) { item in
            HStack {
              VStack(alignment: .leading) {
                Text(item.name).foregroundStyle(.primary).secondary()
                Text(item.id.prefix(8)).secondary()
              }
              Spacer()
              AsyncButton("Allow", systemImage: "plus.capsule.fill") {
                try await hub.client.send("hub/permissions/add", SecurityView.Allow(services: item.pending, permission: item.id))
              }.labelStyle(.iconOnly)
            }
          }
        }.blockBackground()
      }
    }
    struct AppView: View {
      @Environment(Hub.self) var hub
      let app: App
      var installationStatus: LocalizedStringKey? {
        guard let status = app.status else { return nil }
        if status.updating ?? false {
          return "Updating"
        } else if status.checkingForUpdates ?? false {
          return "Checking for updates"
        } else if app.info?.updateAvailable ?? false {
          return "Update"
        } else {
          return nil
        }
      }
      @State private var instances: Int = 0
      @State private var showsInstances = false
      var body: some View {
        HStack(alignment: .top) {
          VStack(alignment: .leading) {
            Text(app.id)
            if showsInstances || (app.info?.instances ?? 0) > 1 {
              HStack {
  #if !os(tvOS)
                Stepper("Instances", value: $instances)
                  .labelsHidden()
                  .task(id: instances) { try? await updateInstances() }
  #endif
                Text("\(instances)").secondary()
              }
            }
            Spacer()
            HStack(alignment: .firstTextBaseline) {
              VStack(alignment: .leading) {
                ForEach(app.status?.processes ?? []) { process in
                  status(process: process)
                }
              }
              if (app.status?.processes?.count ?? 0) > 0 {
                if let date = app.status?.started {
                  Text(date, style: .offset)
                }
              } else {
                Text("Not running")
              }
            }.secondary()
          }
          Spacer()
          if app.id == "Hub Lite" {
            AsyncButton("Upgrade to Pro") {
              try await hub.launcher.pro(KeyChain.main.publicKey())
            }.buttonStyle(.borderedProminent)
          }
        }.overlay(alignment: .topTrailing) {
          if let installationStatus {
            Text(installationStatus).badgeStyle()
          }
        }.blockBackground().contextMenu {
          if let info = app.info {
            if info.active {
              if let info = app.info, info.instances == 1 {
                Button("Cluster", systemImage: "list.number") {
                  showsInstances = true
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
        try await hub.client.send("launcher/app/cluster", LauncherView.AppView.SetInstances(name: info.name, count: instances))
      }
    }
  }
  struct HubView: View {
    typealias StatusBadges = ContentView.StatusBadges
    let hub: Hub
    @State var statusBadges = StatusBadges()
    var body: some View {
      VStack(alignment: .leading) {
        Text(hub.settings.name)
        VStack(alignment: .leading) {
          Text("\(statusBadges.services) services")
          if let security = statusBadges.security, security > 0 {
            Text("\(security) service requests").foregroundStyle(.green)
          }
        }.fontWeight(.medium).secondary()
        .hubStream("hub/status/badges", initial: StatusBadges(), to: $statusBadges)
        .environment(hub)
      }
    }
  }
  struct JoinHubView: View {
    let hubs = Hubs.main
    @State var address: String = ""
    @State var name: String = ""
    let focus: FocusState<TextFieldFocus?>.Binding
    var url: URL? {
      guard var components = URLComponents(string: address) else { return nil }
      components.hub()
      guard let url = components.url else { return nil }
      guard !url.absoluteString.isEmpty else { return nil }
      return url
    }
    var providedName: String? { name.isEmpty ? url?.name : name }
    var body: some View {
      VStack(alignment: .leading) {
        HStack {
          Text(url?.absoluteString ?? "Join Hub")
          Spacer()
          if let url, let providedName {
            Button("Connect") {
              hubs.insert(with: Hub.Settings(name: providedName, address: url))
              self.name = ""
              self.address = ""
            }
          }
        }
        TextField("Address", text: $address).focused(focus, equals: .joinHubAddress)
        if !address.isEmpty {
          TextField(url?.name ?? "Name", text: $name).focused(focus, equals: .joinHubAddress)
            .transition(.blurReplace)
        }
      }.animation(.smooth, value: address.isEmpty).textFieldStyle(.roundedBorder).blockBackground()
    }
    struct Create: View {
      @State private var name = ""
      @State private var address = ""
      @Binding var isCreating: Bool
      private let hubs = Hubs.main
      var url: URL? {
        guard var components = URLComponents(string: address) else { return nil }
        components.hub()
        guard let url = components.url else { return nil }
        guard !url.absoluteString.isEmpty else { return nil }
        return url
      }
      var providedName: String? { name.isEmpty ? url?.name : name }
      var body: some View {
        VStack(alignment: .leading) {
          Text(url?.absoluteString ?? "Add connection").secondary()
          TextField("Address", text: $address)
          TextField(url?.name ?? "Name", text: $name)
          if let url, let providedName {
            Button("Connect") {
              hubs.insert(with: Hub.Settings(name: providedName, address: url))
              self.name = ""
              self.address = ""
              self.isCreating = false
            }
          }
        }
      }
    }
  }
  struct ServiceContent: View {
    let item: AppServicesView.Service
    let isSharing: Bool?
    var body: some View {
      VStack(alignment: .leading) {
        Image(systemName: item.image).resizable().scaledToFit()
          .frame(width: 24, height: 24)
        Text(item.title).lineLimit(2)
        Text(item.description).secondary().lineLimit(3)
      }.blockBackground()
    }
  }
  struct SupportView: View {
    var body: some View {
      LazyVGrid(columns: [.init(.adaptive(minimum: 240))]) {
        Button("Join Discord") { }
        Button("Patreon") { }
        Button("Boosty") { }
        Button("GitHub") { }
        Button("Buy Me a Coffee") { }
        Button("Ko-Fi") { }
        Button("USDT") { }
        Button("BTC") { }
      }.buttonStyle(LinkButtonStyle())
    }
  }
  struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
      configuration.label.multilineTextAlignment(.leading).blockBackground()
    }
  }
}
extension View {
  func sectionTitle(padding: Bool = true) -> some View {
    font(.title3).fontWeight(.medium).padding(.leading, 5).padding(.top, padding ? 16 : 0)
  }
  func blockBackground() -> some View {
    VStack(alignment: .leading) {
      self
    }.padding().frame(maxHeight: .infinity, alignment: .top)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 16))
      .transition(.blurReplace)
  }
}

#Preview {
  HomeView()
}
