//
//  UI Types.swift
//  Hub
//
//  Created by Dmitry Kozlov on 6/7/25.
//

import Foundation

enum ElementType: String {
  case text, textField, button, list
}

protocol ElementProtocol {
  var type: ElementType { get }
}

enum Element {
  case text(Text)
  case textField(TextField)
  case button(Button)
  case list(List)
  struct Text: ElementProtocol {
    var type: ElementType { .text }
    var value: String
  }
  struct TextField: ElementProtocol {
    var type: ElementType { .textField }
    var value: String
    var placeholder: String
  }
  struct Button: ElementProtocol {
    var type: ElementType { .button }
    var title: String
    var action: Action
  }
  struct List: ElementProtocol {
    var type: ElementType { .list }
    var elements: [Element]
  }
  struct Action {
    var path: String
    var context: [String: String]
  }
}

