//
//  UI Elements.swift
//  Hub
//
//  Created by Dmitry Kozlov on 6/7/25.
//

import SwiftUI
import Combine

struct InterfaceData {
  var string: [String: String]
}

@Observable
class ServiceApp {
  var app = AppInterface()
  var string = [String: String]()
  var lists = [String: [NestedList]]()
  struct List: Identifiable {
    var id: String
    var string: [String: String]
  }
  init() {
    
  }
  @MainActor
  func sync(hub: Hub, path: String) async {
    do {
      print("syncing", path)
      for try await event: AppInterface in hub.client.values(path) {
        if let header = event.header {
          self.app.header = header
        }
        if let body = event.body {
          self.app.body = body
        }
      }
    } catch {
      print(error)
    }
  }
}
struct AppInterface: Decodable {
  struct Header: Decodable {
    var name: String
  }
  var header: Header?
  var body: [Element]?
  enum CodingKeys: CodingKey {
    case header, body
  }
  
  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    header = try? container.decodeIfPresent(Header.self, forKey: .header)
    body = try? container.decodeIfPresent(LossyArray<Element>.self, forKey: .body)?.value
  }
  init() {
    
  }
}

extension Element: View {
  @ViewBuilder
  var body: some View {
    switch self {
    case .text(let a): TextView(value: a)
    case .textField(let a): TextFieldView(value: a)
    case .button(let a): ButtonView(value: a)
    case .list(let a): ListView(value: a)
    case .picker(let a): PickerView(value: a)
    case .cell(let a): CellView(value: a)
    }
  }
  struct TextView: View {
    let value: Text
    @Environment(ServiceApp.self) var app
    @Environment(NestedList.self) var nested: NestedList?
    var body: some View {
      if let text = value.value.staticText {
        if value.secondary {
          SwiftUI.Text(text).textSelection(.enabled).secondary()
        } else {
          SwiftUI.Text(text).textSelection(.enabled)
        }
      } else if let text = nested?.string?[value.value] ?? app.string[value.value] {
        if value.secondary {
          SwiftUI.Text(text).textSelection(.enabled).secondary()
        } else {
          SwiftUI.Text(text).textSelection(.enabled)
        }
      }
    }
  }
  struct TextFieldView: View {
    let value: TextField
    @State var text: String = ""
    @State var disableUpdates = true
    @Environment(Hub.self) var hub
    @Environment(ServiceApp.self) var app
    @Environment(NestedList.self) var nested: NestedList?
    var body: some View {
      let state = nested?.string?[value.value] ?? app.string[value.value]
      SwiftUI.TextField(value.placeholder, text: $text)
        .task(id: state) {
          if let state, state != text {
            disableUpdates = true
            text = state
          }
        }.task(id: text) {
          if !disableUpdates {
            if let nested {
              if nested.string?[value.value] != text {
                nested.string?[value.value] = text
              }
            } else if app.string[value.value] != text {
              app.string[value.value] = text
            }
            try? await value.action?.perform(hub: hub, app: app, nested: nested)
          } else {
            disableUpdates = false
          }
        }
    }
  }
  struct PickerView: View {
    let value: Picker
    @State var selected: String = ""
    @Environment(ServiceApp.self) var app
    @Environment(NestedList.self) var nested: NestedList?
    var body: some View {
      let selected = nested?.string?[value.selected] ?? app.string[value.selected]
      SwiftUI.Picker("", selection: $selected) {
        ForEach(value.options, id: \.self) { value in
          SwiftUI.Text(value).tag(value)
        }
      }.task(id: selected) {
          if let selected {
            self.selected = selected
          } else if let selected = value.options.first {
            self.selected = selected
          }
        }
        .onChange(of: self.selected) {
          if let nested {
            if nested.string?[value.selected] != self.selected {
              nested.string?[value.selected] = self.selected
            }
          } else if app.string[value.selected] != self.selected {
            app.string[value.selected] = self.selected
          }
        }
    }
  }
  struct ButtonView: View {
    let value: Button
    @Environment(Hub.self) var hub
    @Environment(ServiceApp.self) var app
    @Environment(NestedList.self) var nested: NestedList?
    var body: some View {
      AsyncButton(value.title) {
        try await value.action.perform(hub: hub, app: app, nested: nested)
      }
    }
  }
  struct ListView: View {
    let value: List
    @Environment(ServiceApp.self) var app
    var body: some View {
      if let list = app.lists[value.data] {
        SwiftUI.ForEach(list) { data in
          HStack {
            value.element
          }.environment(data)
        }
      }
    }
  }
  struct CellView: View {
    let value: Cell
    @Environment(ServiceApp.self) var app
    var body: some View {
      VStack(alignment: .leading) {
        value.title?.secondary()
        value.subtitle
      }
    }
  }
}
extension String {
  var staticText: String? {
    starts(with: "$") ? String(dropFirst()) : nil
  }
}

@Observable
class NestedList: Identifiable {
  var string: [String: String]?
  init(string: [String : String]? = nil) {
    self.string = string
  }
}

struct ServiceView: View {
  @Environment(Hub.self) var hub
  @State private var app = ServiceApp()
  let header: AppHeader
  var body: some View {
    List {
      if let body = app.app.body {
        ForEach(body) { element in
          element
        }
      }
    }.navigationTitle(app.app.header?.name ?? header.name)
      .environment(app)
      .task(id: header.path) { await app.sync(hub: hub, path: header.path) }
  }
}

#Preview {
  ServiceView(header: AppHeader(name: "Hasher", path: "hasher/ui")).environment(Hub.test)
}
