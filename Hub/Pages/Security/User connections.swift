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
  let users: [User]
  var body: some View {
    List(users) { user in
      VStack(alignment: .leading) {
        HStack {
          ForEach(Array(user.permissions).sorted(), id: \.self) { permission in
            Text(permission).foregroundStyle(.blue).secondary()
          }
          if let key = user.key {
            Text(key)
          } else if user.permissions.contains("auth") {
            Text("Authorization Service")
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
      }
    }
  }
  struct User: Decodable, Identifiable {
    var uuid = UUID()
    var id: String { key ?? uuid.uuidString }
    var key: String?
    var services: Int
    var apps: Int
    var permissions: Set<String>
    enum CodingKeys: CodingKey {
      case id, services, apps, permissions
    }
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      key = try container.decodeIfPresent(.id)
      services = container.decodeIfPresent(.services, 0)
      apps = container.decodeIfPresent(.apps, 0)
      permissions = container.decodeIfPresent(.permissions, [])
      if let key {
        permissions.remove(key)
      }
    }
  }
  struct Loader: View {
    @State var users: [User] = []
    var body: some View {
      UserConnections(users: users).hubStream("hub/connections", to: $users)
    }
  }
}
#Preview {
  UserConnections.Loader().environment(Hub.test)
}
