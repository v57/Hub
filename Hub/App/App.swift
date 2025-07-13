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
  }
  @State var sideView: SideView = .storage
  @State var statusBadges = StatusBadges()
  let hubs = Hubs.main
  var body: some View {
    NavigationSplitView {
#if os(macOS)
      List(selection: $sideView) { listContent }
#else
      List { listContent }
      #endif
    } detail: {
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
            ServiceView(header: header).environment(hubs.selectedHub)
          }
        case .storage:
          if let hub = hubs.selectedHub {
            StorageView().environment(hub)
          }
        }
      }
    }
  }
  @ViewBuilder
  var listContent: some View {
    Text("Connections")
      .id(SideView.cluster)
    if let hub = hubs.selectedHub {
      Section(hub.settings.name) {
        Text("Services").badge(statusBadges.services)
          .id(SideView.services)
        Text("Launcher")
          .id(SideView.launcher)
        Text("Security").badge(statusBadges.security ?? 0)
          .badgeProminence(.increased)
          .id(SideView.security)
        Text("Storage")
          .id(SideView.storage)
      }.hubStream("hub/status/badges", initial: StatusBadges(), to: $statusBadges)
        .environment(hub)
      
      if let apps = statusBadges.apps, !apps.isEmpty {
        Section("Apps") {
          ForEach(apps) { app in
            Text(app.name).id(SideView.app(app))
              .foregroundStyle(app.isOnline ? .primary : .tertiary)
          }
        }
      }
    }
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
