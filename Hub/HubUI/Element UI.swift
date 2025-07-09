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

typealias PVar<T> = CurrentValueSubject<T, Never>
@Observable
class InterfaceManager {
  var header: InterfaceHeader?
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
      for try await event: InterfaceEvent in hub.client.values(path) {
        if let header = event.header {
          self.header = header
        }
      }
    } catch {
      print(error)
    }
  }
}
struct InterfaceEvent: Decodable {
  let header: InterfaceHeader?
}
struct InterfaceHeader: Decodable {
  let title: String
  let body: [Element]
  enum CodingKeys: CodingKey {
    case title, body
  }
  
  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.title = try container.decode(String.self, forKey: .title)
    body = try container.decode(LossyArray<Element>.self, forKey: .body).value
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
    @Environment(InterfaceManager.self) var interface
    @Environment(NestedList.self) var nested: NestedList?
    var body: some View {
      if let text = value.value.staticText {
        if value.secondary {
          SwiftUI.Text(text).textSelection(.enabled).secondary()
        } else {
          SwiftUI.Text(text).textSelection(.enabled)
        }
      } else if let text = nested?.string?[value.value] ?? interface.string[value.value] {
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
    @Environment(InterfaceManager.self) var interface
    @Environment(NestedList.self) var nested: NestedList?
    var body: some View {
      let text = nested?.string?[value.value] ?? interface.string[value.value]
      SwiftUI.TextField(value.placeholder, text: $text)
        .task(id: text) {
          if let text {
            self.text = text
          }
        }
        .onChange(of: self.text) {
          if let nested {
            if nested.string?[value.value] != self.text {
              nested.string?[value.value] = self.text
            }
          } else if interface.string[value.value] != self.text {
            interface.string[value.value] = self.text
          }
        }
    }
  }
  struct PickerView: View {
    let value: Picker
    @State var selected: String = ""
    @Environment(InterfaceManager.self) var interface
    @Environment(NestedList.self) var nested: NestedList?
    var body: some View {
      let selected = nested?.string?[value.selected] ?? interface.string[value.selected]
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
          } else if interface.string[value.selected] != self.selected {
            interface.string[value.selected] = self.selected
          }
        }
    }
  }
  struct ButtonView: View {
    let value: Button
    @Environment(Hub.self) var hub
    @Environment(InterfaceManager.self) var interface
    @Environment(NestedList.self) var nested: NestedList?
    var body: some View {
      AsyncButton(value.title) {
        let body = value.action.body.resolve(interface: interface, nested: nested)
        let result: ActionBody = try await hub.client.send(value.action.path, body)
        result.update(interface: interface, nested: nested, output: value.action.output)
      }
    }
  }
  struct ListView: View {
    let value: List
    @Environment(InterfaceManager.self) var interface
    var body: some View {
      if let list = interface.lists[value.data] {
        SwiftUI.List(list) { data in
          HStack {
            ForEach(value.elements) { element in
              element
            }
          }.environment(data)
        }
      }
    }
  }
  struct CellView: View {
    let value: Cell
    @Environment(InterfaceManager.self) var interface
    var body: some View {
      VStack(alignment: .leading) {
        value.title.secondary()
        value.body
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

struct ExampleUI: View {
  @Environment(Hub.self) var hub
  @State private var interface = InterfaceManager()
  let path = "hasher/ui"
  var body: some View {
    ZStack {
      if let header = interface.header {
        List {
          ForEach(header.body) { element in
            element
          }
        }.navigationTitle(header.title)
      }
    }
      .environment(interface).padding().frame(width: 400, height: 400)
      .task { await interface.sync(hub: hub, path: path) }
  }
}

#Preview {
  ExampleUI().environment(Hub.test)
}

import CryptoKit
#Preview {
  @Previewable @State var text: String = ""
  List {
    VStack(alignment: .leading) {
      TextField("Generate Hash", text: $text)
      Text("SHA256").secondary()
      Text(text.sha256)
      Text("SHA512").secondary()
      Text(text.sha512)
      Text("SHA512/256").secondary()
      Text(text.sha512_256)
    }
  }.padding().frame(width: 400, height: 400)
}
extension String {
  var sha256: String {
    var sha = SHA256()
    sha.update(data: data(using: .utf8)!)
    return Data(sha.finalize()).base64EncodedString()
  }
  var sha512: String {
    var sha = SHA512()
    sha.update(data: data(using: .utf8)!)
    return Data(sha.finalize()).base64EncodedString()
  }
  var sha512_256: String {
    var sha = SHA512()
    sha.update(data: data(using: .utf8)!)
    let data: Data = Data(sha.finalize())
    var sha256 = SHA256()
    sha256.update(data: data)
    return Data(sha256.finalize()).base64EncodedString()
  }
}
