//
//  Cluster.swift
//  Hub
//
//  Created by Dmitry Kozlov on 16/2/25.
//

import SwiftUI

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
  struct ClusterInfo: Identifiable, Comparable {
    let id = UUID()
    let name: String
    let address: String
    let status: OnlineStatus
    static func ==(l: Self, r: Self) -> Bool {
      l.status == r.status
    }
    static func <(l: Self, r: Self) -> Bool {
      l.status < r.status
    }
  }
  @State var create: Bool = false
  @State var clusters: [ClusterInfo] = [
    ClusterInfo(name: "Local", address: "127.0.0.1", status: .offline),
    ClusterInfo(name: "MacBook Pro", address: "m3pro.local", status: .online),
    ClusterInfo(name: "Main Server", address: "apple.com", status: .unauthorized),
    ClusterInfo(name: "Droplet", address: "digitalocean.com", status: .online),
  ].sorted()
  var body: some View {
    NavigationStack {
      List {
        ForEach(clusters) { cluster in
          VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
              Text(cluster.name)
              cluster.status.view
            }
            Text(cluster.address).font(.caption2).foregroundStyle(.secondary)
          }
        }
      }.toolbar {
        Button("Copy Key", systemImage: "person.badge.key.fill") {
          
        }
        Button("Create", systemImage: "plus") {
          create = true
        }
      }.navigationTitle("Cluster").navigationDestination(isPresented: $create) {
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
