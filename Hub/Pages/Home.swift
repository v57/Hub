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
  var body: some View {
    NavigationStack {
      GeometryReader { view in
        ScrollView {
          VStack(alignment: .leading) {
            HeaderSection(focus: $focus)
            ForEach(Hubs.main.list) { hub in
              HubSection().environment(hub).transition(.home)
            }
            Text("My Apps").sectionTitle()
            HomeGrid {
              ForEach(AppServicesView.Service.allCases, id: \.self) { item in
                ServiceContent(item: item, isSharing: nil)
              }
            }
            Text("Support this Project").sectionTitle()
            SupportView()
          }.padding(.top).animation(.home, value: isFocusing)
            .animation(.home, value: hubs.list.count)
            .safeAreaPadding(.horizontal, 8)
            .animation(.smooth, value: view.size.width)
        }.environment(\.homeGridSpacing, HomeGrid.spacing(width: view.size.width - 16))
      }.navigationTitle("Home")
        .scrollDismissesKeyboard(.immediately)
        .toolbarTitleDisplayMode(.inline)
        .contentTransition(.numericText())
        .scrollIndicators(.hidden)
    }
  }
  struct HeaderSection: View {
    @FocusState.Binding var focus: TextFieldFocus?
    @State private var copied = false
    @State var address: String = ""
    @State var merging: Hub?
    var body: some View {
      HomeGrid {
        JoinHubView(address: $address.animation(), focus: $focus)
          .gridSize(address.isEmpty ? .x21 : .x42)
        NavigationLink {
          InstallationGuide()
        } label: {
          ZStack {
            Text("Make your own").font(.callout.weight(.semibold))
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Text("Learn how to host your own Hub")
              .secondary()
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
          }.padding(8).blockBackground()
        }.buttonStyle(.plain).gridSize(.x21)
        ForEach(Hubs.main.list) { hub in
          HubView(merging: $merging).environment(hub)
            .gridSize(.x21)
        }
        Button {
          Task {
            withAnimation {
              copied = true
            }
            KeyChain.main.publicKey().copyToClipboard()
            try await Task.sleep(for: .seconds(3))
            withAnimation {
              copied = false
            }
          }
        } label: {
          AppIcon(title: copied ? "Copied" : "My Key", systemImage: copied ? "checkmark.circle.fill" : "key")
        }.buttonStyle(.plain)
      }
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
    @HubState(\.statusBadges) var statusBadges
    @HubState(\.status) var status
    @Bindable var hub: Hub
    @State private var sheet: Sheet?
    enum Sheet: Identifiable {
      var id: Sheet { self }
      case pending, connections, permissions
    }
    var body: some View {
      let task = LauncherView.TaskId(hub: hub.id, isConnected: hub.isConnected && hub.hasLauncher)
      Text(hub.settings.name).sectionTitle()
      HomeGrid {
        if !status.services.isEmpty {
          NavigationLink {
            Services().environment(hub)
          } label: {
            ServicesView()
          }.buttonStyle(.plain).transition(.home).gridSize(.x22)
        }
        Button {
          sheet = .connections
        } label: {
          AppIcon(title: "Connections", systemImage: "wifi")
            .iconBadge(statusBadges.connections)
        }.buttonStyle(.plain)
        Button {
          sheet = .pending
        } label: {
          AppIcon(title: "Requests", systemImage: "clock")
            .iconBadge(statusBadges.security)
        }.buttonStyle(.plain)
        Button {
          sheet = .permissions
        } label: {
          AppIcon(title: "Permissions", systemImage: "lock")
        }.buttonStyle(.plain)
        if hub.require(permissions: "launcher/app/create") {
          NavigationLink {
            StoreView().environment(hub.manager).environment(hub)
          } label: {
            AppIcon(title: "Get Apps", systemImage: "arrow.down.circle.fill")
          }.buttonStyle(.plain).transition(.home)
        }
        ForEach(hub.manager.apps) { app in
          AppView(app: app)
        }
        Files()
        ShareServicesView().gridSize(.x22)
        if let apps = statusBadges.apps, !apps.isEmpty {
          ForEach(apps) { app in
            NavigationLink(value: app) {
              AppIcon(title: app.name, textIcon: String(app.name.first ?? "A"))
                .iconBadge(app.isOnline ? nil : "Offline", color: .red)
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
      .navigationDestination(for: AppHeader.self) { app in
        ServiceView(header: app).environment(hub)
      }
      .navigationDestination(item: $sheet) { sheet in
        switch sheet {
        case .connections:
          UserConnections()
            .safeAreaPadding(.top).frame(minHeight: 400)
            .environment(hub)
        case .pending:
          PendingListView()
            .safeAreaPadding(.top).frame(minHeight: 400)
            .environment(hub)
        case .permissions:
          PermissionGroups()
            .safeAreaPadding(.top).frame(minHeight: 400)
            .environment(hub)
        }
      }
    }
    struct ServicesView: View {
      @HubState(\.status) var status
      var body: some View {
        VStack(alignment: .leading, spacing: 8) {
          Text("Services").font(.callout.weight(.semibold))
          Spacer()
          ForEach(status.services.sorted(by: { $0.requests > $1.requests }).prefix(3), id: \.name) { service in
            VStack(alignment: .leading) {
              Text(service.name).foregroundStyle(.primary)
              HStack(spacing: 4) {
                if service.requests > 0 {
                  Label("\(service.requests)", systemImage: "checkmark")
                }
                if service.balancerType != .counter {
                  Image(systemName: service.balancerType.icon).secondary()
                }
                if let running = service.running, running > 0 {
                  Label("\(running)", systemImage: "bolt.fill")
                }
                if let pending = service.pending, pending > 0 {
                  Label("\(pending)", systemImage: "bolt.badge.clock.fill")
                }
              }.labelStyle(LabelStyle())
            }.secondary()
          }
        }.padding(8)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .blockBackground()
      }
      struct LabelStyle: SwiftUI.LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
          HStack(spacing: 4) {
            configuration.icon
            configuration.title
          }
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
      @HubState(\.status) var status
      var body: some View {
        if status.hasStorage {
          NavigationLink {
            StorageView().environment(hub)
          } label: {
            Label("Files", systemImage: "folder.fill").blockBackground()
          }.buttonStyle(.plain).transition(.home)
        } else if hub.require(permissions: "launcher/app/create") {
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
          Text("Share Services").font(.callout.weight(.semibold))
          Spacer()
          LazyVGrid(columns: [.init(.adaptive(minimum: 48))]) {
            ForEach(Service.allCases, id: \.self) { service in
              if let publisher = service.servicePublisher(hub: hub) {
                ServiceToggle(publisher: publisher, service: service)
              }
            }
          }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(8).blockBackground()
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
    @Environment(Hub.self) var hub
    @HubState(\.statusBadges) var statusBadges
    @Binding var merging: Hub?
    var canBeMerged: Bool {
      guard let merging else { return false }
      return !merging.isMerged(to: hub) && !hub.isMerged(to: merging)
    }
    var body: some View {
      let canMerge = hub.require(permissions: "hub/merge/add")
      VStack(alignment: .leading) {
        HStack(spacing: 4) {
          Text(hub.settings.name)
          Spacer()
          if #available(macOS 15.0, iOS 18.0, *) {
            Image(systemName: "wifi")
              .symbolEffect(.variableColor.iterative.dimInactiveLayers.reversing, options: .repeat(.continuous), isActive: !hub.isConnected)
          }
        }.font(.callout.weight(.semibold))
        Spacer()
        if hub.isConnected {
          VStack(alignment: .leading) {
            Text("\(statusBadges.services) services")
            if let security = statusBadges.security, security > 0 {
              Text("\(security) service requests").foregroundStyle(.green)
            }
          }.fontWeight(.medium).secondary().transition(.blurReplace)
        } else {
          Text("Connecting...").secondary().transition(.blurReplace)
        }
        if let merging, merging.id != hub.id && canMerge {
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
      }.animation(.smooth, value: hub.isConnected).padding(8).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).blockBackground().contextMenu {
        if canMerge && merging == nil {
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
    @Binding var address: String
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
          Text(url?.absoluteString ?? "Join Hub").font(.callout.weight(.semibold))
          Spacer()
          if let url, let providedName {
            Button {
              hubs.insert(with: Hub.Settings(name: providedName, address: url))
              self.name = ""
              self.address = ""
            } label: {
              Text("Connect").font(.callout.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
            }.buttonStyle(.plain)
          }
        }
        Spacer()
        TextField("Address", text: $address).focused(focus, equals: .joinHubAddress)
          .textFieldStyle(.plain)
          .padding(.horizontal, 8).padding(.vertical, 4)
          .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
        if !address.isEmpty {
          TextField(url?.name ?? "Name", text: $name).focused(focus, equals: .joinHubAddress)
            .textFieldStyle(.plain)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
            .transition(.home)
        }
      }.padding(8).animation(.home, value: address.isEmpty).blockBackground()
    }
  }
  struct ServiceContent: View {
    let item: AppServicesView.Service
    let isSharing: Bool?
    var body: some View {
      NavigationLink {
        AppServicesView.ServicePage(service: item)
      } label: {
        AppIcon(title: item.title, systemImage: item.image)
      }.buttonStyle(.plain)
    }
  }
  struct SupportView: View {
    var body: some View {
      HomeGrid {
        Button("Discord") { }.lineLimit(1)
        Button("Patreon") { }.lineLimit(1)
        Button("Boosty") { }.lineLimit(1)
        Button("GitHub") { }.lineLimit(1)
        Button("Buy Me\na Coffee") { }.lineLimit(2)
        Button("Ko-Fi") { }.lineLimit(1)
        Button("USDT") { }.lineLimit(1)
        Button("BTC") { }.lineLimit(1)
      }.buttonStyle(LinkButtonStyle())
    }
  }
  struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
      configuration.label.multilineTextAlignment(.center)
        .font(.callout).fontWeight(.semibold)
        .fontDesign(.rounded)
        .minimumScaleFactor(0.6)
        .padding(8)
        .blockBackground()
    }
  }
  struct AppIcon<Icon: View>: View {
    let title: Text
    var badge: Text?
    var badgeColor: Color = .blue
    @ViewBuilder let icon: Icon
    var body: some View {
      ZStack {
        LinearGradient(colors: [.red, .orange, .green, .blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
          .mask { icon.blur(radius: 8) }
        icon.opacity(0.8)
      }
      .contentTransition(.symbolEffect).font(.system(size: 32, weight: .semibold, design: .rounded))
      .blockBackground().overlay(alignment: .top) {
        if let badge {
          badge.font(.caption.bold()).padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor, in: .capsule)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, -4)
            .offset(y: -4)
        }
      }.overlay {
          GeometryReader { view in
            title.font(.system(size: 10)).offset(y: view.size.height + 4)
              .multilineTextAlignment(.center)
              .frame(maxWidth: .infinity)
          }
        }
    }
    func iconBadge(_ value: Int?, color: Color = .blue) -> Self {
      var a = self
      if let value {
        a.badge = Text("\(value)")
        a.badgeColor = color
      }
      return a
    }
    func iconBadge(_ value: LocalizedStringKey?, color: Color = .blue) -> Self {
      var a = self
      if let value {
        a.badge = Text(value)
        a.badgeColor = color
      }
      return a
    }
  }
}
extension HomeView.AppIcon where Icon == Image {
  init(title: LocalizedStringKey, systemImage: String) {
    self.title = Text(title)
    self.icon = Image(systemName: systemImage)
  }
}
extension HomeView.AppIcon where Icon == Text {
  init(title: String, textIcon: String) {
    self.title = Text(title)
    self.icon = Text(textIcon)
  }
}
extension View {
  func sectionTitle(padding: Bool = true) -> some View {
    modifier(SectionTitleModifier(padding: padding))
  }
  func blockBackground(_ radius: CGFloat = 16) -> some View {
    self.modifier(BlockStyle(cornerRadius: radius))
  }
  func blurBackground(_ radius: CGFloat = 16) -> some View {
    background {
      RoundedRectangle(cornerRadius: radius)
        .fill(.regularMaterial)
        .strokeBorder(LinearGradient(colors: [.clear, .white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
      
      .shadow(radius: 12)
    }
  }
}
struct SectionTitleModifier: ViewModifier {
  @Environment(\.homeGridSpacing) var spacing
  let padding: Bool
  func body(content: Content) -> some View {
    content.font(.body).fontWeight(.medium)
      .padding(.leading, spacing + 8)
      .padding(.top, padding ? 32 : 0)
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

struct BlockStyle: ViewModifier {
  let cornerRadius: CGFloat
  func body(content: Content) -> some View {
    RoundedRectangle(cornerRadius: cornerRadius)
      .fill(.regularMaterial)
      .strokeBorder(LinearGradient(colors: [.clear, .white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
      .overlay {
        content
      }
      .compositingGroup()
      .shadow(radius: 12)
      .modifier {
        #if os(macOS)
        $0
        #else
        $0.contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: cornerRadius))
        #endif
      }
      .transition(.home)
  }
}

#Preview {
  HomeView()
}
