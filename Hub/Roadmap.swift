//
//  Roadmap.swift
//  Hub
//
//  Created by Dmitry Kozlov on 21/2/25.
//

import SwiftUI

struct RoadmapView: View {
  @State var sections: [ItemSection] = [
    ItemSection(name: "Launcher", items: [
      Item(name: "Launch app", done: true),
      Item(name: "Clone from github", done: true),
      Item(name: "Download launcher", done: true),
      Item(name: "Start from mac", done: true),
      Item(name: "Stop launcher", done: true),
      Item(name: "Restart on crash", done: true),
      Item(name: "Launched list", done: true),
      Item(name: "Cpu/Memory usage", done: true),
      Item(name: "Start/stop app", done: true),
      Item(name: "Add app", done: true),
      Item(name: "Remove app", done: true),
      Item(name: "Set relaunch options", done: false),
      Item(name: "Fix bugs", done: false),
    ]),
    ItemSection(name: "Hub", items: [
      Item(name: "Hub lite library", done: true),
      Item(name: "Service library", done: true),
      Item(name: "Client library", done: true),
      Item(name: "Apns service", done: true),
      Item(name: "Login with Google service", done: true),
      Item(name: "Login with Apple service", done: true),
      Item(name: "Apple StoreKit service", done: true),
      Item(name: "Swift library", done: true),
      Item(name: "Hub stats", done: true),
      Item(name: "HubUI app", done: true),
      Item(name: "HubUI hub page", done: true),
    ]),
  ]
  var body: some View {
    List {
      ForEach(sections, id: \.name) { section in
        Section(section.name) {
          ForEach(section.items.filter { !$0.done }, id: \.name) { item in
            ItemView(item: item)
          }
          ForEach(section.items.filter { $0.done }, id: \.name) { item in
            ItemView(item: item)
          }
        }
      }
    }
  }
  struct ItemView: View {
    let item: Item
    var body: some View {
      HStack {
        Image(systemName: "checkmark.circle.fill").opacity(item.done ? 1 : 0)
        Text(item.name)
      }
    }
  }
  struct Item {
    var name: String
    var done: Bool
  }
  struct ItemSection {
    var name: String
    var items: [Item]
  }
}

#Preview {
  RoadmapView()
}
