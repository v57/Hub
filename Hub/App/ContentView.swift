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
  var body: some View {
    NavigationSplitView {
#if os(macOS)
      List(selection: $sideView) {
        Section {
          Text("Hub").badge(statusBadges.services)
            .id(SideView.services)
          Text("Connections")
            .id(SideView.cluster)
          Text("Launcher")
            .id(SideView.launcher)
          Text("Security").badge(statusBadges.security)
            .badgeProminence(.increased)
            .id(SideView.security)
        }
      }
#else
      List(SideView.allCases, id: \.rawValue) { item in
        Section {
          switch item {
          case .services:
            Text("Hub").badge(statusBadges.services)
          case .launcher:
            Text("Launcher")
          case .cluster:
            Text("Cluster")
          case .security:
            Text("Security").badge(statusBadges.security)
              .badgeProminence(.increased)
          }
        }
      }
      #endif
    } detail: {
      switch sideView {
      case .services:
        Services()
      case .cluster:
        Cluster()
      case .launcher:
        LauncherView()
      case .security:
        SecurityView()
      }
    }.task {
      do {
        for try await status: StatusBadges in hub.client.values("hub/status/badges") {
          self.statusBadges = status
        }
      } catch {
        print(error)
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
