//
//  User connections.swift
//  Hub
//
//  Created by Linux on 23.01.26.
//

import SwiftUI
import HubClient

struct UserConnections: View {
  @Environment(Hub.self) var hub
  @Binding var users: [User]
  let groups: GroupList
  var body: some View {
    List(users) { user in
      VStack(alignment: .leading) {
        HStack {
          if let key = user.key {
            Text(key)
          } else {
            Text("Unauthorized")
          }
        }
        HStack {
          if user.services > 0 {
            Text("\(user.services) services")
          }
          if user.apps > 0 {
            Text("\(user.apps) apps")
          }
        }.secondary()
      }.contextMenu {
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
    var uuid = UUID()
    var id: String { key ?? uuid.uuidString }
    var key: String?
    var services: Int
    var apps: Int
    enum CodingKeys: CodingKey {
      case id, services, apps, permissions
    }
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      key = try container.decodeIfPresent(.id)
      services = container.decodeIfPresent(.services, 0)
      apps = container.decodeIfPresent(.apps, 0)
    }
  }
  struct Loader: View {
    @State var users: [User] = []
    @State private var groups = GroupList()
    var body: some View {
      UserConnections(users: $users, groups: groups)
        .hubStream("hub/connections", to: $users)
        .hubStream("hub/groups/list", to: $groups)
    }
  }
}
#Preview {
  UserConnections.Loader().environment(Hub.test)
}
