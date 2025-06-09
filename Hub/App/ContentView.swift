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
      if let hub = hubs.selectedHub {
        switch sideView {
        case .services:
          Services().environment(hub)
        case .cluster:
          Cluster().environment(hub)
        case .launcher:
          LauncherView().environment(hub)
        case .security:
          SecurityView().environment(hub)
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
        Text("Hub").badge(statusBadges.services)
          .id(SideView.services)
        Text("Launcher")
          .id(SideView.launcher)
        Text("Security").badge(statusBadges.security)
          .badgeProminence(.increased)
          .id(SideView.security)
      }.task(id: hub.id) {
        do {
          self.statusBadges = StatusBadges()
          for try await status: StatusBadges in hub.client.values("hub/status/badges") {
            self.statusBadges = status
          }
        } catch {
          print(error)
        }
      }
    }
  }
  struct StatusBadges: Decodable {
    var services: Int = 0
    var security: Int = 0
  }
}

#Preview {
  ContentView()
}
