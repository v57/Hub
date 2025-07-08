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
  var id: String { get }
}

enum Element: Identifiable {
  var id: String {
    switch self {
    case .text(let a): a.id
    case .textField(let a): a.id
    case .button(let a): a.id
    case .list(let a): a.id
    }
  }
  case text(Text)
  case textField(TextField)
  case button(Button)
  case list(List)
  struct Text: ElementProtocol, Identifiable {
    var type: ElementType { .text }
    var id: String = UUID().uuidString
    var value: String
  }
  struct TextField: ElementProtocol, Identifiable {
    var type: ElementType { .textField }
    var id: String = UUID().uuidString
    var value: String
    var placeholder: String
  }
  struct Button: ElementProtocol, Identifiable {
    var type: ElementType { .button }
    var id: String = UUID().uuidString
    var title: String
    var action: Action
  }
  struct List: ElementProtocol, Identifiable {
    var type: ElementType { .list }
    var id: String = UUID().uuidString
    var data: String
    var elements: [Element]
  }
  struct Action {
    var path: String
    var context: [String: String]
  }
}

