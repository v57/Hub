//
//  ContentView.swift
//  Hub
//
//  Created by Dmitry Kozlov on 16/2/25.
//

import SwiftUI

struct ContentView: View {
  enum SideView {
    case services
    case launcher
    case cluster
    case roadmap
  }
  @State var sideView: SideView = .roadmap
  var body: some View {
    NavigationSplitView {
      List(selection: $sideView) {
        Section {
          Text("Hub").badge(hub.status?.services.count ?? 0)
            .id(SideView.services)
#if os(macOS)
          Text("Launcher")
            .id(SideView.launcher)
#endif
        }
        Section {
          Text("Roadmap").id(SideView.roadmap)
        }
      }
    } detail: {
      switch sideView {
      case .services:
        Services()
      case .cluster:
        Cluster()
      case .launcher:
#if os(macOS)
        LauncherView()
#endif
      case .roadmap:
        RoadmapView()
      }
    }
  }
}

#Preview {
  ContentView()
}
