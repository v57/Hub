//
//  UI Types.swift
//  Hub
//
//  Created by Dmitry Kozlov on 6/7/25.
//

import Foundation

enum ElementType: String, Codable {
  case text, textField, button, list, picker
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
    }
  }
  case text(Text)
  case textField(TextField)
  case button(Button)
  case list(List)
  case picker(Picker)
  enum CodingKeys: CodingKey {
    case type
  }
  
  init(from decoder: any Decoder) throws {
    do {
      let value = try decoder.singleValueContainer().decode(String.self)
      self = .text(Text(value: value))
    } catch {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let type = try container.decode(ElementType.self, forKey: .type)
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
      }
    }
  }
  struct Text: ElementProtocol, Identifiable, Decodable {
    var type: ElementType { .text }
    var id: String = UUID().uuidString
    var value: String
  }
  struct TextField: ElementProtocol, Identifiable, Decodable {
    var type: ElementType { .textField }
    var id: String = UUID().uuidString
    var value: String
    var placeholder: String
    enum CodingKeys: CodingKey {
      case value
      case placeholder
    }
    
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.value = try container.decode(String.self, forKey: .value)
      self.placeholder = try container.decode(String.self, forKey: .placeholder)
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
      self.title = try container.decode(String.self, forKey: CodingKeys.title)
      self.action = try container.decode(Element.Action.self, forKey: CodingKeys.action)
    }
  }
  struct List: ElementProtocol, Identifiable, Decodable {
    var type: ElementType { .list }
    var id: String = UUID().uuidString
    var data: String
    var elements: [Element]
    enum CodingKeys: CodingKey {
      case data
      case elements
    }
    
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.data = try container.decode(String.self, forKey: .data)
      self.elements = try container.decode(LossyArray<Element>.self, forKey: .elements).value
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
      self.options = try container.decode([String].self, forKey: .options)
      self.selected = try container.decode(String.self, forKey: .selected)
    }
  }
  struct Action: Decodable {
    var path: String
    var body: ActionBody
    var output: ActionBody
    enum CodingKeys: CodingKey {
      case path
      case body
      case output
    }
    
    init(from decoder: any Decoder) throws {
      let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
      self.path = try container.decode(String.self, forKey: CodingKeys.path)
      self.body = try container.decode(ActionBody.self, forKey: CodingKeys.body)
      self.output = try container.decode(ActionBody.self, forKey: CodingKeys.output)
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
        let container = try decoder.singleValueContainer()
        do {
          self = try .single(container.decode(String.self))
        } catch {
          self = try .multiple(container.decode([String: String].self))
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
    func resolve(interface: InterfaceManager, nested: NestedList?) -> ActionBody? {
      switch self {
      case .single(let string):
        guard let string = nested?.string?[string] ?? interface.string[string] else { return nil }
        return .single(string)
      case .multiple(let dictionary):
        let data = dictionary.compactMapValues { (string: String) -> String? in
          guard let string = nested?.string?[string] ?? interface.string[string] else { return nil }
          return string
        }
        return .multiple(data)
      case .void:
        return ActionBody.void
      }
    }
    func map(_ output: ActionBody) -> [String: String] {
      switch (self, output) {
      case (.single(let value), .single(let key)):
        return [key: value]
      case (.multiple(let values), .multiple(let keys)):
        var data = [String: String]()
        values.forEach { key, value in
          data[keys[key] ?? key] = value
        }
        return data
      default:
        return [:]
      }
    }
    func update(interface: InterfaceManager, nested: NestedList?, output: ActionBody) {
      let data = map(output)
      if let nested, nested.string != nil {
        nested.string?.insert(contentsOf: data)
      } else {
        interface.string.insert(contentsOf: data)
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

struct Lossy<T: Decodable>: Decodable {
  let value: T?
  init(from decoder: any Decoder) throws {
    value = try? decoder.singleValueContainer()
      .decode(T.self)
  }
}
struct LossyArray<Element: Decodable>: Decodable {
  let value: [Element]
  init(from decoder: any Decoder) throws {
    do {
      let elements: [Lossy<Element>] = try decoder
        .singleValueContainer().decode([Lossy<Element>].self)
      value = elements.compactMap { $0.value }
    } catch {
      value = []
    }
  }
}
