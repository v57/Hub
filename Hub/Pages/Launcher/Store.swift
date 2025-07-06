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
  var setup: Hub.Launcher.Setup?
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
    StoreItem(icon: Icon(symbol: .init(name: "app.badge.fill")),
              name: "Apple Push Notifications",
              shortDescription: "Service for sending push notifications to Apple devices", type: .api,
              setup: .bun(.init(repo: "v57/hub-apns", commit: nil, command: nil))),
    StoreItem(icon: Icon(symbol: .init(name: "apple.logo")),
              name: "Login with Apple",
              shortDescription: "Adds apple authorization to your app", type: .api,
              setup: .bun(.init(repo: "v57/hub-apple", commit: nil, command: nil))),
    StoreItem(icon: Icon(text: .init(name: "G")),
              name: "Login with Google",
              shortDescription: "Adds google authorization to your app", type: .api,
              setup: .bun(.init(repo: "v57/hub-google", commit: nil, command: nil))),
    StoreItem(icon: Icon(symbol: .init(name: "apple.intelligence")),
              name: "Ollama",
              shortDescription: "Api for running ollama models", type: .api,
              setup: .bun(.init(repo: "v57/hub-ollama", commit: nil, command: nil))),
    StoreItem(icon: Icon(symbol: .init(name: "leaf.fill")),
              name: "MongoDB",
              shortDescription: "MongoDB NoSql database", type: .server),
    StoreItem(icon: Icon(symbol: .init(name: "server.rack")),
              name: "Redis",
              shortDescription: "Memory key value storage", type: .server),
    StoreItem(icon: Icon(symbol: .init(name: "server.rack")),
              name: "Postgres SQL",
              shortDescription: "SQL Database", type: .server),
    StoreItem(icon: Icon(symbol: .init(name: "network")),
              name: "NginX config",
              shortDescription: "Setup your NginX", type: .app),
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
      Text("Store").font(.title).fontWeight(.bold)
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
      ItemView(item: item)
    }
  }
  struct ItemView: View {
    @Environment(LauncherView.Manager.self) var manager
    @Environment(Hub.self) var hub
    let item: StoreItem
    @State var isInstalling = false
    @State var isInstalled = false
    var body: some View {
      let isInstalled = manager.active.contains(item.name)
      HStack {
        IconView(icon: item.icon).frame(width: 44, height: 44)
        VStack(alignment: .leading) {
          Text(item.name)
          Text(item.shortDescription).secondary()
        }
        Spacer()
        if let buttonTitle {
          AsyncButton(buttonTitle) {
            try await action()
          }.buttonStyle(DownloadButtonStyle())
            .animation(.smooth, value: buttonTitle)
            .contentTransition(.numericText())
        }
      }.task(id: isInstalled) {
        self.isInstalled = isInstalled
      }
    }
    var buttonTitle: LocalizedStringKey? {
      if isInstalling {
        "Installing"
      } else if isInstalled {
        "Installed"
      } else if item.setup != nil {
        "Get"
      } else {
        nil
      }
    }
    func action() async throws {
      if isInstalling {
        
      } else if isInstalled {
        
      } else if let setup = item.setup {
        isInstalling = true
        defer { isInstalling = false }
        try await hub.launcher.create(.init(name: item.name, active: true, restarts: true, setup: setup))
        isInstalled = true
      }
    }
  }
}

#Preview {
  List {
    StoreView()
  }
}
