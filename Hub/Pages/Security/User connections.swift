//
//  User connections.swift
//  Hub
//
//  Created by Linux on 23.01.26.
//

import SwiftUI
import HubClient

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
    var apps: Int
    enum CodingKeys: CodingKey {
      case id, key, services, apps, permissions
    }
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      id = try container.decode(.id)
      key = container.decodeIfPresent(.key)
      services = container.decodeIfPresent(.services, 0)
      apps = container.decodeIfPresent(.apps, 0)
    }
  }
  struct UserView: View {
    let user: User
    let isMe: Bool
    var body: some View {
      VStack(alignment: .leading) {
        if isMe {
          Text("You")
        } else if let key = user.key {
          Text(key.prefix(8)).secondary()
        } else {
          Text("Unauthorized")
        }
        Text(user.id).secondary()
        HStack {
          if user.services > 0 {
            Text("\(user.services) services")
          }
          if user.apps > 0 {
            Text("\(user.apps) apps")
          }
        }.secondary()
      }.lineLimit(1)
    }
  }
}
#Preview {
  UserConnections().environment(Hub.test)
}
