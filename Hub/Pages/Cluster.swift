//
//  Cluster.swift
//  Hub
//
//  Created by Dmitry Kozlov on 16/2/25.
//

import SwiftUI
import HubClient

enum OnlineStatus: Comparable {
  case online, unauthorized, offline
  var view: some View {
    Circle().fill(background.opacity(1)).frame(width: 6)
  }
  var background: Color {
    switch self {
    case .online: .blue
    case .offline: .red
    case .unauthorized: .orange
    }
  }
}

struct Cluster: View {
  @State var create: Bool = false
  let hubs = Hubs.main
  var body: some View {
    NavigationStack {
      List {
        if !hubs.hasLocal {
          Button("Add local") {
            hubs.insert(info: HubInfo(name: "My Mac", address: HubClient.local))
          }
        }
        ForEach(hubs.infos) { (info: HubInfo) in
          VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
              Text(info.name)
            }
            Text(info.address.description).font(.caption2).foregroundStyle(.secondary)
          }
        }
      }.toolbar {
        Button("Copy Key", systemImage: "person.badge.key.fill") {
          
        }
        Button("Create", systemImage: "plus") {
          create = true
        }
      }.navigationTitle("Connections").navigationDestination(isPresented: $create) {
        Create()
      }
    }
  }
  struct Create: View {
    @State var address = ""
    var body: some View {
      TextField("Address", text: $address)
    }
  }
}
