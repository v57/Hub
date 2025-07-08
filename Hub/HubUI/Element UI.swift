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
  var elements: [Element] = []
  var string = [String: String]()
  var lists = [String: [NestedList]]()
  struct List: Identifiable {
    var id: String
    var string: [String: String]
  }
  init() {
    elements = [
      Element.text(.init(value: "$Title")),
      Element.text(.init(value: "text")),
      Element.textField(.init(value: "text", placeholder: "Example text field")),
      Element.button(.init(title: "Button", action: .init(path: "", context: [:]))),
      Element.list(.init(data: "list", elements: [
        Element.text(.init(value: "text")),
        Element.textField(.init(value: "text", placeholder: "Example text field")),
      ])),
    ]
    string["text"] = "Hello World"
    lists["list"] = [
      NestedList(string: ["text": "Element text"]),
      NestedList(string: ["text": "Another text"]),
    ]
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
    }
  }
  struct TextView: View {
    let value: Text
    @Environment(InterfaceManager.self) var interface
    @Environment(NestedList.self) var nested: NestedList?
    var body: some View {
      if let text = value.value.staticText {
        SwiftUI.Text(text)
      } else if let text = nested?.string?[value.value] ?? interface.string[value.value] {
        SwiftUI.Text(text)
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
  struct ButtonView: View {
    let value: Button
    var body: some View {
      SwiftUI.Button(value.title) {
        
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

//extension View {
//  func sync(id: String, value: Binding<String>, editable: Bool = false) -> some View {
//    modifier(StringSync(id: id, value: value, editable: editable))
//  }
//}
//
//struct StringSync: ViewModifier {
//  @Environment var interface: InterfaceManager
//  let id: String
//  @Binding var value: String
//  func body(content: Content) -> some View {
//    if !id.starts(with: "$"), let publisher = interface.string[id] {
//      if editable {
//        content.onReceive(publisher) {
//          value = $0
//        }.onChange(of: value) {
//          publisher.send(value)
//        }
//      } else {
//        content.onReceive(publisher) {
//          value = $0
//        }
//      }
//    } else {
//      content
//    }
//  }
//}

#Preview {
  @Previewable @State var interface = InterfaceManager()
  VStack {
    ForEach(interface.elements) { element in
      element
    }
  }.environment(interface).padding().frame(width: 400, height: 400)
}
