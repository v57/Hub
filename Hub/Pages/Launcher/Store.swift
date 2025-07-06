//
//  Store.swift
//  Hub
//
//  Created by Dmitry Kozlov on 6/7/25.
//

import SwiftUI

struct StoreItem: Identifiable, Codable {
  var id = UUID()
  var icon: Icon
  var name: String
  var shortDescription: String
  var type: ServiceType
}
enum ServiceType: String, Codable, CaseIterable {
  case app, api, server
  var name: LocalizedStringKey {
    switch self {
    case .app: "App"
    case .api: "Api"
    case .server: "Server"
    }
  }
}

struct StoreView: View {
  var allItems: [StoreItem] = [
    StoreItem(icon: Icon(symbol: .init(name: "app.badge.fill")), name: "Apple Push Notifications", shortDescription: "Service for sending push notifications to Apple devices", type: .api),
    StoreItem(icon: Icon(symbol: .init(name: "apple.logo")), name: "Login with Apple", shortDescription: "Adds apple authorization to your app", type: .api),
    StoreItem(icon: Icon(text: .init(name: "G")), name: "Login with Google", shortDescription: "Adds google authorization to your app", type: .api),
    StoreItem(icon: Icon(symbol: .init(name: "apple.intelligence")), name: "Ollama", shortDescription: "Api for running ollama models", type: .api),
    StoreItem(icon: Icon(symbol: .init(name: "leaf.fill")), name: "MongoDB", shortDescription: "MongoDB NoSql database", type: .server),
    StoreItem(icon: Icon(symbol: .init(name: "server.rack")), name: "Redis", shortDescription: "Memory key value storage", type: .server),
    StoreItem(icon: Icon(symbol: .init(name: "server.rack")), name: "Postgres SQL", shortDescription: "SQL Database", type: .server),
    StoreItem(icon: Icon(symbol: .init(name: "network")), name: "NginX config", shortDescription: "Setup your NginX", type: .app),
  ]
  @State var filter: ServiceType?
  var items: [StoreItem] {
    if let filter {
      allItems.filter { $0.type == filter }
    } else {
      allItems
    }
  }
  var body: some View {
    HStack {
      Text("Get more").font(.title).fontWeight(.bold)
      Spacer()
      Picker("Filter", selection: $filter) {
        Text("All").tag(Optional<ServiceType>.none)
        ForEach(ServiceType.allCases, id: \.rawValue) { type in
          Text(type.name).tag(type)
        }
      }.pickerStyle(.palette).labelsHidden()
        .frame(maxWidth: 200)
    }
    ForEach(items) { item in
      HStack {
        IconView(icon: item.icon).frame(width: 44, height: 44)
        VStack(alignment: .leading) {
          Text(item.name)
          Text(item.shortDescription).secondary()
        }
        Spacer()
        Button("Get") {
          
        }.buttonStyle(DownloadButtonStyle())
      }
    }
  }
  struct DownloadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
      configuration.label.foregroundStyle(.white)
        .fontWeight(.medium)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .frame(minWidth: 60)
        .background(.blue, in: .capsule)
    }
  }
  struct TabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
      configuration.label.foregroundStyle(.white)
        .fontWeight(.medium)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .frame(minWidth: 60)
        .background(.blue, in: .capsule)
    }
  }
}

#Preview {
  List {
    StoreView()
  }
}
