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
class InterfaceManager: EnvironmentKey {
  static var defaultValue: InterfaceManager { InterfaceManager() }
  var elements: [Element] = []
  var string = [String: PVar<String>]()
  init() {
    elements = [
      Element.text(.init(value: "Title")),
      Element.text(.init(value: "$text")),
      Element.textField(.init(value: "$text", placeholder: "Example text field")),
      Element.button(.init(title: "Button", action: .init(path: "", context: [:]))),
    ]
    string["$text"] = PVar("Hello World")
  }
}
extension EnvironmentValues {
  var interface: InterfaceManager {
    get { self[InterfaceManager.self] }
    set { self[InterfaceManager.self] = newValue }
  }
}

extension Element: View {
  @ViewBuilder
  var body: some View {
    switch self {
    case .text(let a): TextView(value: a)
    case .textField(let a): TextFieldView(value: a)
    case .button(let a): ButtonView(value: a)
    }
  }
  struct TextView: View {
    let value: Text
    @State var text: String = ""
    var body: some View {
      SwiftUI.Text(value.value.starts(with: "$") ? text : value.value)
        .sync(id: value.value, value: $text)
    }
  }
  struct TextFieldView: View {
    let value: TextField
    @State var text: String = ""
    var body: some View {
      SwiftUI.TextField(value.placeholder, text: $text)
        .sync(id: value.value, value: $text, editable: true)
    }
  }
  struct ButtonView: View {
    let value: Button
    var body: some View {
      SwiftUI.Button(value.title) {
        
      }
    }
  }
}

extension View {
  func sync(id: String, value: Binding<String>, editable: Bool = false) -> some View {
    modifier(StringSync(id: id, value: value, editable: editable))
  }
}

struct StringSync: ViewModifier {
  @Environment(\.interface) var interface
  let id: String
  @Binding var value: String
  let editable: Bool
  func body(content: Content) -> some View {
    if id.starts(with: "$"), let publisher = interface.string[id] {
      if editable {
        content.onReceive(publisher) {
          value = $0
        }.onChange(of: value) {
          publisher.send(value)
        }
      } else {
        content.onReceive(publisher) {
          value = $0
        }
      }
    } else {
      content
    }
  }
}

#Preview {
  @Previewable @State var interface = InterfaceManager()
  VStack {
    ForEach(interface.elements) { element in
      element
    }
  }.environment(\.interface, interface).padding().frame(width: 400, height: 400)
}
