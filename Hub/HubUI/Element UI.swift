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
      Element.text(.init(id: "text", value: "Hello World")),
      Element.textField(.init(id: "textField", value: "", placeholder: "Example text field")),
      Element.button(.init(id: "button", title: "Button", action: .init(path: "", context: [:]))),
    ]
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
    var body: some View {
      SwiftUI.Text(value.value)
    }
  }
  struct TextFieldView: View {
    let value: TextField
    @State var text: String = ""
    var body: some View {
      SwiftUI.TextField(value.placeholder, text: $text)
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

#Preview {
  let interface = InterfaceManager()
  ForEach(interface.elements) { element in
    element
  }
}
