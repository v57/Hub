//
//  Permission groups.swift
//  Hub
//
//  Created by Linux on 16.11.25.
//

import SwiftUI

struct PermissionGroups: View {
  @Environment(Hub.self) var hub
  @State var adding = false
  @State var name: String = ""
  @State var permissions: PermissionList?
  @State var selected = Set<String>()
  var body: some View {
    List {
      if let permissions {
        ForEach(permissions.sections) { section in
          Section {
            ForEach(section.permissions, id: \.self) { (name: String) in
              Toggle(name, isOn: $selected.toggle("\(section.name)/\(name)"))
            }
          } header: {
            Toggle(section.name, isOn: $selected.toggle(section.permissions.map { "\(section.name)/\($0)" }))
          }
        }
      }
    }.safeAreaInset(edge: .bottom) {
      HStack {
        if adding {
          TextField("Name", text: $name.animation()).frame(maxWidth: 150)
            .transition(.blurReplace)
        }
        AsyncButton(createTitle) {
          if adding && !name.isEmpty {
            try await hub.client.send("hub/groups/add", AddGroup(name: name, permissions: Array(selected)))
          }
          name = ""
          withAnimation {
            adding.toggle()
          }
        }.buttonStyle(.borderedProminent).contentTransition(.numericText())
      }.padding().hubStream("hub/groups/permissions", to: $permissions)
    }
  }
  var createTitle: LocalizedStringKey {
    adding ? name.isEmpty ? "Cancel" : "Create" : "Create group"
  }
  struct AddGroup: Encodable {
    let name: String
    let permissions: [String]
  }
}

typealias RawPermissionList = [String: [String: [String]]]
struct PermissionList: Decodable {
  var sections: [Section]
  init(from decoder: any Decoder) throws {
    sections = try decoder.singleValueContainer()
      .decode([String: [String: [String]]].self)
      .map { name, permissions in
        Section(name: name, permissions: permissions.map { $0.key }.sorted())
      }.sorted(by: { $0.name < $1.name })
  }
  struct Section: Identifiable {
    var id: String { name }
    var name: String
    var permissions: [String]
  }
}

extension Binding where Value: SetAlgebra & Sendable {
  func toggle(_ key: Value.Element) -> Binding<Bool> {
    Binding<Bool> {
      wrappedValue.contains(key)
    } set: { newValue in
      if newValue {
        wrappedValue.insert(key)
      } else {
        wrappedValue.remove(key)
      }
    }
  }
  func toggle(_ keys: [Value.Element]) -> Binding<Bool> {
    Binding<Bool> {
      !keys.contains { !wrappedValue.contains($0) }
    } set: { newValue in
      if newValue {
        for key in keys {
          wrappedValue.insert(key)
        }
      } else {
        for key in keys {
          wrappedValue.remove(key)
        }
      }
    }
  }
}

#Preview {
  PermissionGroups().environment(Hub.test)
}
