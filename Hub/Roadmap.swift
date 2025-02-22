//
//  Roadmap.swift
//  Hub
//
//  Created by Dmitry Kozlov on 21/2/25.
//

import SwiftUI

let roadmap = """
# Launcher
+ Launch app
+ Clone from github
+ Download launcher
+ Start from mac
+ Stop launcher
+ Restart on crash
+ Launched list
+ Cpu/Memory usage
+ Start/stop app
+ Add app
+ Remove app
+ Set relaunch options
+ Fix bugs

# Hub
+ Hub lite library
+ Service library
+ Client library
+ Apns service
+ Login with Google service
+ Login with Apple service
+ Apple StoreKit service
+ Swift library
+ Hub stats
+ HubUI app
+ HubUI hub page
"""

struct RoadmapView: View {
  static func sections() -> [ItemSection] {
    var sections = [ItemSection]()
    var section: ItemSection?
    roadmap.components(separatedBy: "\n").lazy.map {
      $0.trimmingCharacters(in: .whitespaces)
    }.filter { !$0.isEmpty }.forEach { line in
      if line.starts(with: "# ") {
        if let section {
          sections.append(section)
        }
        section = ItemSection(name: String(line.dropFirst(2)), items: [])
      } else if line.starts(with: "+ ") {
        section?.items.append(Item(name: String(line.dropFirst(2)), done: true))
      } else {
        section?.items.append(Item(name: line, done: false))
      }
    }
    if let section {
      sections.append(section)
    }
    return sections
  }
  @State var sections: [ItemSection] = RoadmapView.sections()
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
    let name: String
    let done: Bool
  }
  struct ItemSection {
    let name: String
    var items: [Item]
  }
}

#Preview {
  RoadmapView()
}
