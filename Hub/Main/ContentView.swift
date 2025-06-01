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
  }
  @State var sideView: SideView = .launcher
  var body: some View {
    NavigationSplitView {
      #if os(macOS)
      List(selection: $sideView) {
        Section {
          Text("Hub").badge(hub.status?.services.count ?? 0)
            .id(SideView.services)
          Text("Launcher")
            .id(SideView.launcher)
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
      }
    }
  }
}

#Preview {
  ContentView()
}
