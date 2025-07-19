//
//  UI Types.swift
//  Hub
//
//  Created by Dmitry Kozlov on 6/7/25.
//

import Foundation

enum ElementType: String, Codable {
  case text, textField, button, list, picker, cell, files
}

protocol ElementProtocol {
  var type: ElementType { get }
  var id: String { get }
}

enum Element: Identifiable, Decodable {
  var id: String {
    switch self {
    case .text(let a): a.id
    case .textField(let a): a.id
    case .button(let a): a.id
    case .list(let a): a.id
    case .picker(let a): a.id
    case .cell(let a): a.id
    case .files(let a): a.id
    }
  }
  case text(Text)
  case textField(TextField)
  case button(Button)
  case list(List)
  case picker(Picker)
  case cell(Cell)
  case files(Files)
  enum CodingKeys: CodingKey {
    case type
  }
  
  init(from decoder: any Decoder) throws {
    do {
      let value: String = try decoder.decode()
      self = .text(Text(value: value))
    } catch {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let type: ElementType = try container.decode(.type)
      switch type {
      case .text:
        self = try .text(Text(from: decoder))
      case .textField:
        self = try .textField(TextField(from: decoder))
      case .button:
        self = try .button(Button(from: decoder))
      case .list:
        self = try .list(List(from: decoder))
      case .picker:
        self = try .picker(Picker(from: decoder))
      case .cell:
        self = try .cell(Cell(from: decoder))
      case .files:
        self = try .files(Files(from: decoder))
      }
    }
  }
  struct Text: ElementProtocol, Identifiable, Decodable {
    var type: ElementType { .text }
    var id: String = UUID().uuidString
    var value: String
    var secondary: Bool
    enum CodingKeys: CodingKey {
      case value
      case secondary
    }
    init(value: String) {
      self.value = value
      self.secondary = false
    }
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.value = try container.decode(.value)
      self.secondary = container.decodeIfPresent(.secondary, false)
    }
  }
  struct TextField: ElementProtocol, Identifiable, Decodable {
    var type: ElementType { .textField }
    var id: String = UUID().uuidString
    var value: String
    var placeholder: String
    var action: Action?
    enum CodingKeys: CodingKey {
      case value, placeholder, action
    }
    
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.value = try container.decode(.value)
      self.placeholder = container.decodeIfPresent(.placeholder, "")
      self.action = try container.decode(.action)
    }
  }
  struct Button: ElementProtocol, Identifiable, Decodable {
    var type: ElementType { .button }
    var id: String = UUID().uuidString
    var title: String
    var action: Action
    enum CodingKeys: CodingKey {
      case title
      case action
    }
    
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      title = try container.decode(.title)
      action = try container.decode(.action)
    }
  }
  final class List: ElementProtocol, Identifiable, Decodable {
    var type: ElementType { .list }
    var id: String = UUID().uuidString
    var data: String
    var element: Element
    enum CodingKeys: CodingKey {
      case data
      case elements
    }
    
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      data = try container.decode(.data)
      element = try container.decode(.elements)
    }
  }
  struct Picker: ElementProtocol, Identifiable, Decodable {
    var type: ElementType { .list }
    var id: String = UUID().uuidString
    var options: [String]
    var selected: String
    enum CodingKeys: CodingKey {
      case options, selected
    }
    
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      options = try container.decode(.options)
      selected = try container.decode(.selected)
    }
  }
  final class Cell: ElementProtocol, Identifiable, Decodable {
    var type: ElementType { .cell }
    var id: String = UUID().uuidString
    var title: Element?
    var subtitle: Element?
    enum CodingKeys: CodingKey {
      case title, subtitle
    }
    
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.title = try container.decodeIfPresent(.title)
      self.subtitle = try container.decodeIfPresent(.subtitle)
    }
  }
  final class Files: ElementProtocol, Identifiable, Decodable {
    var type: ElementType { .files }
    var id: String = UUID().uuidString
    var title: Element?
    var value: String
    var action: Action
    enum CodingKeys: CodingKey {
      case title, value, action
    }
    
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.title = try container.decodeIfPresent(.title)
      self.value = try container.decode(.value)
      self.action = try container.decode(.action)
    }
  }
  struct Action: Decodable {
    var path: String
    var body: ActionBody
    var output: ActionBody?
    enum CodingKeys: CodingKey {
      case path
      case body
      case output
    }
    
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.path = try container.decode(.path)
      self.body = try container.decode(.body)
      self.output = try container.decodeIfPresent(.output)
    }
    func perform(hub: Hub, app: ServiceApp, nested: NestedList?) async throws {
      let body = body.resolve(app: app, nested: nested)
      let result: ActionBody = try await hub.client.send(path, body)
      result.update(app: app, nested: nested, output: output)
    }
  }
  enum ActionBody: Codable {
    case void
    case single(String)
    case multiple([String: String])
    enum CodingKeys: CodingKey {
      case single
      case multiple
    }
    
    init(from decoder: any Decoder) throws {
      do {
        do {
          self = try .single(decoder.decode())
        } catch {
          self = try .multiple(decoder.decode())
        }
      } catch {
        self = .void
      }
    }
    
    func encode(to encoder: any Encoder) throws {
      var container = encoder.singleValueContainer()
      switch self {
      case .single(let string):
        try container.encode(string)
      case .multiple(let dictionary):
        try container.encode(dictionary)
      case .void: break
      }
    }
    func resolve(app: ServiceApp, nested: NestedList?) -> ActionBody? {
      switch self {
      case .single(let string):
        guard let string = nested?.string?[string] ?? app.string[string] else { return nil }
        return .single(string)
      case .multiple(let dictionary):
        let data = dictionary.compactMapValues { (string: String) -> String? in
          guard let string = nested?.string?[string] ?? app.string[string] else { return nil }
          return string
        }
        return .multiple(data)
      case .void:
        return ActionBody.void
      }
    }
    func map(_ output: ActionBody?) -> [String: String] {
      let map = output?.resolved() ?? [:]
      var result = resolved()
      for (key, value) in result {
        if let mapped = map[key] {
          result[key] = nil
          result[mapped] = value
        }
      }
      return result
    }
    func resolved() -> [String: String] {
      switch self {
      case .void: [:]
      case .single(let string): [string: string]
      case .multiple(let dictionary): dictionary
      }
    }
    func update(app: ServiceApp, nested: NestedList?, output: ActionBody?) {
      let data = map(output)
      if let nested, nested.string != nil {
        nested.string?.insert(contentsOf: data)
      } else {
        app.string.insert(contentsOf: data)
      }
    }
  }
}

extension Dictionary {
  mutating func insert(contentsOf dictionary: Dictionary) {
    dictionary.forEach { key, value in
      self[key] = value
    }
  }
}
