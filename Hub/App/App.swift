//
//  ContentView.swift
//  Hub
//
//  Created by Dmitry Kozlov on 16/2/25.
//

import SwiftUI

struct ContentView: View {
  enum SideView: Hashable {
    case services
    case launcher
    case cluster
    case security
    case storage
    case app(AppHeader)
    case local
  }
  @State var sideView: SideView? = .storage
  @State var statusBadges = StatusBadges()
  let hubs = Hubs.main
  var body: some View {
    NavigationSplitView {
      List { listContent }.navigationDestination(for: SideView.self) { value in
        destination(sideView: value)
      }
    } detail: {
      
    }
  }
  func destination(sideView: SideView) -> some View {
    NavigationStack {
      switch sideView {
      case .services:
        if let hub = hubs.selectedHub {
          Services().environment(hub)
        }
      case .cluster:
        ConnectionsView()
      case .launcher:
        if let hub = hubs.selectedHub {
          LauncherView().environment(hub)
        }
      case .security:
        if let hub = hubs.selectedHub {
          SecurityView().environment(hub)
        }
      case .app(let header):
        if let hub = hubs.selectedHub {
          ServiceView(header: header).environment(hub)
        }
      case .storage:
        if let hub = hubs.selectedHub {
          StorageView().environment(hub)
        }
      case .local:
        AppServicesView().environment(hubs.selectedHub)
      }
    }
  }
  @ViewBuilder
  var listContent: some View {
    NavigationLink("Connections", value: SideView.cluster)
    if let hub = hubs.selectedHub {
      Section(hub.settings.name) {
#if os(tvOS)
        NavigationLink("Services", value: SideView.services)
#else
        NavigationLink("Services", value: SideView.services)
          .badge(statusBadges.services)
#endif
        NavigationLink("Launcher", value: SideView.launcher)
#if os(tvOS)
        NavigationLink("Security", value: SideView.security)
#else
        NavigationLink("Security", value: SideView.security)
          .badge(statusBadges.security ?? 0)
          .badgeProminence(.increased)
#endif
        NavigationLink("Storage", value: SideView.storage)
      }.hubStream("hub/status/badges", initial: StatusBadges(), to: $statusBadges)
        .environment(hub)
      
      if let apps = statusBadges.apps, !apps.isEmpty {
        Section("Apps") {
          ForEach(apps) { app in
            NavigationLink(app.name, value: SideView.app(app))
              .foregroundStyle(app.isOnline ? .primary : .tertiary)
          }
        }
      }
    }
    NavigationLink("My Apps", value: SideView.local)
  }
  struct StatusBadges: Decodable {
    var services: Int = 0
    var security: Int?
    var apps: [AppHeader]?
  }
}
struct AppHeader: Identifiable, Hashable, Decodable {
  var id: String { path }
  var name: String
  var path: String
  var services: Int?
  var isOnline: Bool { (services ?? 1) != 0 }
}

#Preview {
  ContentView()
}
