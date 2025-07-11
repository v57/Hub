//
//  ContentView.swift
//  Hub
//
//  Created by Dmitry Kozlov on 16/2/25.
//

import SwiftUI

struct ContentView: View {
  enum SideView: Int, CaseIterable {
    case services
    case launcher
    case cluster
    case security
  }
  @State var sideView: SideView = .cluster
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
      }.hubStream("hub/status/badges", initial: StatusBadges(), to: $statusBadges)
        .environment(hub)
    }
  }
  struct StatusBadges: Decodable {
    var services: Int = 0
    var security: Int?
  }
}
struct AppHeader: Identifiable, Hashable, Decodable {
  var id: String { path }
  var name: String
  var path: String
}

#Preview {
  ContentView()
}
