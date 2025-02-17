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
    case cluster
  }
  @State var sideView: SideView = .services
  var body: some View {
    NavigationSplitView {
      List(selection: $sideView) {
        Section("General") {
          Text("Hub").badge(hub.status?.services.count ?? 0).id(SideView.services)
        }
      }
    } detail: {
      switch sideView {
      case .services:
        Services()
      case .cluster:
        Cluster()
      }
    }.task {
      
    }
  }
}

#Preview {
  ContentView()
}
