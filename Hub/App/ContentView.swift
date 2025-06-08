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
  @State var sideView: SideView = .security
  var body: some View {
    NavigationSplitView {
#if os(macOS)
      List(selection: $sideView) {
        Section {
          Text("Hub").badge(hub.status?.services.count ?? 0)
            .id(SideView.services)
          Text("Connections")
            .id(SideView.cluster)
          Text("Launcher")
            .id(SideView.launcher)
          Text("Security")
            .id(SideView.security)
        }
      }
#else
      List(SideView.allCases, id: \.rawValue) { item in
        Section {
          switch item {
          case .services:
            Text("Hub").badge(hub.status?.services.count ?? 0)
          case .launcher:
            Text("Launcher")
          case .cluster:
            Text("Cluster")
          case .security:
            Text("Security")
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
    }
  }
}

#Preview {
  ContentView()
}
