//
//  Home.swift
//  Hub
//
//  Created by Linux on 02.11.25.
//

import SwiftUI
import HubClient

struct HomeView: View {
  typealias StatusBadges = ContentView.StatusBadges
  enum TextFieldFocus: Hashable {
    case joinHubAddress
    case joinHubName
  }
  @FocusState var focus: TextFieldFocus?
  var isFocusing: Bool { focus == .joinHubAddress || focus == .joinHubName }
  @State var hubs = Hubs.main
  @State var merging: Hub?
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading) {
          HStack {
            Text("Hubs").sectionTitle()
            Spacer()
            Button("Copy Key", systemImage: "key.fill") {
              KeyChain.main.publicKey().copyToClipboard()
            }
          }
          LazyVGrid(columns: [.init(.adaptive(minimum: isFocusing ? 360 : 180))]) {
            JoinHubView(focus: $focus)
            NavigationLink {
              InstallationGuide()
            } label: {
              Text("Make your own").blockBackground()
            }.buttonStyle(.plain)
            ForEach(Hubs.main.list) { hub in
              HubView(hub: hub, merging: $merging)
            }
          }
          ForEach(Hubs.main.list) { hub in
            HubSection().environment(hub).transition(.home)
          }
          Text("My Apps").sectionTitle()
          LazyVGrid(columns: [.init(.adaptive(minimum: 180))]) {
            ForEach(AppServicesView.Service.allCases, id: \.self) { item in
              ServiceContent(item: item, isSharing: nil)
            }
          }
          Text("Support this Project").sectionTitle()
          SupportView()
        }.animation(.home, value: isFocusing)
          .animation(.home, value: hubs.list.count)
          .safeAreaPadding(.horizontal)
      }.navigationTitle("Home").scrollDismissesKeyboard(.immediately)
        .contentTransition(.numericText())
    }
  }
  struct HubSection: View {
    @Environment(Hub.self) var hub
    var body: some View {
      HubSectionContent(hub: hub)
    }
  }
  struct HubSectionContent: View {
    typealias App = Hub.Launcher.App
    @Bindable var hub: Hub
    var body: some View {
      let task = LauncherView.TaskId(hub: hub.id, isConnected: hub.isConnected && hub.hasLauncher)
      Title(manager: hub.manager).padding(.top, 16)
      LazyVGrid(columns: [.init(.adaptive(minimum: 180))]) {
        if hub.permissions.contains("owner") {
          if !hub.status.services.isEmpty {
            NavigationLink {
              Services().environment(hub)
            } label: {
              ServicesView(status: hub.status)
            }.buttonStyle(.plain).transition(.home)
          }
          if !hub.pending.isEmpty {
            PermissionsView(pending: hub.pending).transition(.home)
          }
        }
        ForEach(hub.manager.apps) { app in
          AppView(app: app)
        }
        Files(status: hub.status)
        ShareServicesView()
        if let apps = hub.statusBadges.apps, !apps.isEmpty {
          ForEach(apps) { app in
            NavigationLink(value: app) {
              Text(app.name).foregroundStyle(app.isOnline ? .primary : .tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .blockBackground()
            }.buttonStyle(.plain).transition(.home)
          }
        }
      }
      .task(id: task) {
        guard task.isConnected else { return }
        await hub.manager.syncStatus(hub: hub)
      }.task(id: task) {
        guard task.isConnected else { return }
        await hub.manager.syncApps(hub: hub)
      }
      .hubStream("hub/status") { (status: Status) in
        EventDelayManager.main.execute {
          hub.hasLauncher = status.contains(service: "launcher")
        }
      }
      .hubStream("hub/permissions/pending", to: $hub.pending, animation: .home)
      .hubStream("hub/status", to: $hub.status, animation: .home)
      .hubStream("hub/status/badges", to: $hub.statusBadges, animation: .home)
        .navigationDestination(for: AppHeader.self) { app in
          ServiceView(header: app).environment(hub)
        }
    }
    struct Title: View {
      @Environment(Hub.self) var hub
      let manager: LauncherView.Manager
      @State var addingOwner = false
      @State var ownerKey = ""
      var body: some View {
        VStack {
          HStack {
            Text(hub.settings.name).sectionTitle(padding: false)
            if hub.permissions.contains("owner") {
              Text("owner").secondary()
            }
            Spacer()
            if hub.isOwner && !addingOwner {
              Button("Add owner", systemImage: "person.fill.badge.plus") {
                addingOwner = true
              }.transition(.home)
            }
            if hub.permissions.contains("owner") {
              NavigationLink {
                StoreView().environment(manager).environment(hub)
              } label: {
                Label("Get apps", systemImage: "arrow.down.circle.fill")
              }.transition(.home)
            }
          }
          HStack {
            if hub.isOwner && addingOwner {
              SecureField("Key", text: $ownerKey).transition(.home)
              AsyncButton("Add") {
                addingOwner = false
                let key = ownerKey
                ownerKey = ""
                try await hub.addOwner(key)
              }.disabled(ownerKey.isEmpty).transition(.home)
              AsyncButton("Cancel") {
                addingOwner = false
                ownerKey = ""
              }.transition(.home)
            }
          }
        }.frame(maxWidth: .infinity, alignment: .trailing).padding(.leading, 10)
          .padding(.bottom, 4)
      }
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
        NavigationLink {
          SecurityView().environment(hub)
        } label: {
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
      @State private var editing: Hub.Launcher.AppInfo?
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
                  Spacer()
                  Text(date, style: .relative)
                }
              } else {
                Text("Not running")
              }
            }.secondary()
            if app.id == "Hub Lite" {
              AsyncButton("Upgrade to Pro") {
                try await hub.launcher.pro(KeyChain.main.publicKey())
              }.buttonStyle(.borderedProminent)
            }
          }
        }.frame(maxWidth: .infinity, alignment: .leading).overlay(alignment: .topTrailing) {
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
              AsyncButton("Restart", systemImage: "arrow.clockwise") {
                try await hub.launcher.app(id: app.id).restart()
              }
              if let app = app.info {
                Button("Settings", systemImage: "gear") {
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
              if let app = app.info {
                Button("Settings", systemImage: "gear") {
                  editing = app
                }
              }
              AsyncButton("Uninstall", systemImage: "trash.fill", role: .destructive) {
                try await hub.launcher.app(id: app.id).uninstall()
              }
            }
          }
        }.sheet(item: $editing) {
          EditApp(app: $0).environment(hub).frame(minHeight: 300)
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
    struct Files: View {
      @Environment(Hub.self) var hub
      let status: Status
      var body: some View {
        if status.hasStorage {
          NavigationLink {
            StorageView().environment(hub)
          } label: {
            Label("Files", systemImage: "folder.fill").blockBackground()
          }.buttonStyle(.plain).transition(.home)
        } else if hub.permissions.contains("owner") {
          NavigationLink {
            InstallS3().environment(hub)
          } label: {
            Label("Connect Storage", systemImage: "shippingbox.fill").blockBackground()
          }.buttonStyle(.plain).transition(.home)
        }
      }
    }
    struct ShareServicesView: View {
      @Environment(Hub.self) var hub
      typealias Service = AppServicesView.Service
      var body: some View {
        VStack(alignment: .leading) {
          Text("Share Services")
          LazyVGrid(columns: [.init(.adaptive(minimum: 48))]) {
            ForEach(Service.allCases, id: \.self) { service in
              if let publisher = service.servicePublisher(hub: hub) {
                ServiceToggle(publisher: publisher, service: service)
              }
            }
          }
        }.blockBackground()
      }
      struct ServiceToggle: View {
        @Environment(Hub.self) var hub
        let publisher: Published<Bool>.Publisher
        let service: Service
        @State var isEnabled: Bool = false
        var body: some View {
          Button {
            withAnimation(.home) {
              isEnabled.toggle()
            }
            service.setService(enabled: isEnabled, hub: hub)
          } label: {
            ZStack {
              Image(systemName: service.image)
            }.frame(maxWidth: .infinity)
              .padding(.vertical, 6)
              .background {
                RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemFill)).strokeBorder(.blue, lineWidth: isEnabled ? 1 : 0)
              }
              .font(.body).fontWeight(.medium)
          }.onReceive(publisher) { isEnabled = $0 }
            .buttonStyle(.plain)
        }
      }
    }
  }
  struct HubView: View {
    let hub: Hub
    @State var statusBadges = StatusBadges()
    @Binding var merging: Hub?
    var canBeMerged: Bool {
      guard let merging else { return false }
      return !merging.isMerged(to: hub) && !hub.isMerged(to: merging)
    }
    var body: some View {
      VStack(alignment: .leading) {
        Text(hub.settings.name)
        VStack(alignment: .leading) {
          Text("\(statusBadges.services) services")
          if let security = statusBadges.security, security > 0 {
            Text("\(security) service requests").foregroundStyle(.green)
          }
        }.fontWeight(.medium).secondary()
          .hubStream("hub/status/badges", initial: StatusBadges(), to: $statusBadges, animation: .home)
        .environment(hub)
        if let merging, merging.id != hub.id && hub.isOwner {
          Spacer()
          if merging.isMerged(to: hub) {
            AsyncButton("Leave") {
              try await merging.unmerge(other: hub)
            }
          } else if canBeMerged {
            AsyncButton("Join") {
              try await merging.merge(other: hub)
            }
          }
        }
      }.blockBackground().contextMenu {
        if hub.isOwner && merging == nil {
          Button("Merge") {
            merging = hub
          }
        }
        Button("Remove") {
          Hubs.main.remove(with: hub.settings)
        }
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
            .transition(.home)
        }
      }.animation(.home, value: address.isEmpty).textFieldStyle(.roundedBorder).blockBackground()
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
      NavigationLink {
        AppServicesView.ServicePage(service: item)
      } label: {
        VStack(alignment: .leading) {
          Image(systemName: item.image).resizable().scaledToFit()
            .frame(width: 24, height: 24)
          Text(item.title).lineLimit(2)
          Text(item.description).secondary().lineLimit(3)
        }.blockBackground()
      }.buttonStyle(.plain)
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
    }.padding()
      .frame(maxHeight: .infinity, alignment: .top)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.1), lineWidth: 1))
      .background(BackgroundColor(), in: RoundedRectangle(cornerRadius: 16))
      .modifier {
        #if os(macOS)
        $0
        #else
        $0.contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 16))
        #endif
      }
      .transition(.home)
  }
}

struct BackgroundColor: ShapeStyle {
  func resolve(in environment: EnvironmentValues) -> Color {
    if environment.colorScheme == .dark {
      Color(red: 0.2, green: 0.2, blue: 0.24)
    } else {
      Color(hue: 0, saturation: 0, brightness: 0.92)
    }
  }
}

extension AnyTransition {
  static var home: AnyTransition {
    AnyTransition.scale
  }
}

extension Animation {
  static var home: Animation { .spring(response: 0.5, dampingFraction: 0.7) }
}

#Preview {
  HomeView()
}
