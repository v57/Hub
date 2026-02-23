//
//  User connections.swift
//  Hub
//
//  Created by Linux on 23.01.26.
//

import SwiftUI
import HubService

struct UserConnections: View {
  @Environment(Hub.self) private var hub
  @HubState(\.users) private var users
  @HubState(\.groups) private var groups
  var body: some View {
    List(users) { user in
      UserView(user: user, isMe: user.key == hub.key).contextMenu {
        if let key = user.key {
          Menu("Group") {
            ForEach(groups.groups) { group in
              AsyncButton(group.name) {
                try await hub.add(key: key, group: group.name)
              }
            }
          }
        }
      }
    }
  }
  struct User: Hashable, Decodable, Identifiable {
    var id: String
    var key: String?
    var services: Int
    var name: String
    var icon: Icon
    var apps: Int
    enum CodingKeys: CodingKey {
      case id, key, services, apps, permissions, name, icon
    }
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      id = try container.decode(.id)
      key = container.decodeIfPresent(.key)
      services = container.decodeIfPresent(.services, 0)
      apps = container.decodeIfPresent(.apps, 0)
      name = container.decodeIfPresent(.name, "")
      icon = container.decodeIfPresent(.icon) ?? Icon(symbol: .init(name: "hexagon"))
    }
  }
  struct UserView: View {
    let user: User
    let isMe: Bool
    var body: some View {
      HStack {
        IconView(icon: user.icon).frame(width: 44, height: 44)
        VStack(alignment: .leading) {
          HStack(alignment: .firstTextBaseline, spacing: 4) {
            if !user.name.isEmpty {
              Text(user.name)
            }
            if let key = user.key {
              Text(isMe ? "\(key.suffix(8)) (You)" : key.suffix(8)).secondary()
                .textSelection()
            } else {
              Text("Unauthorized")
            }
          }
          if user.services > 0 || user.apps > 0 {
            HStack {
              if user.services > 0 {
                Text("\(user.services) services")
              }
              if user.apps > 0 {
                Text("\(user.apps) apps")
              }
            }.secondary()
          }
        }.lineLimit(1)
      }
    }
  }
}
#Preview {
  UserConnections().environment(Hub.test)
}
