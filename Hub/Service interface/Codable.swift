//
//  Codable.swift
//  Hub
//
//  Created by Linux on 12.07.25.
//

import Foundation

enum AnyCodable: Codable {
  case dictionary([String: AnyCodable])
  case array([AnyCodable])
  case string(String)
  case int(Int)
  case double(Double)
  case date(Date)
  var dictionary: [String: AnyCodable]? {
    get {
      switch self {
      case .dictionary(let dictionary): dictionary
      default: nil
      }
    } set {
      if let newValue {
        self = .dictionary(newValue)
      }
    }
  }
  var array: [AnyCodable]? {
    get {
      switch self {
      case .array(let array): array
      case .string(let string): [.string(string)]
      case .int(let int): [.int(int)]
      case .double(let double): [.double(double)]
      case .date(let date): [.date(date)]
      default: nil
      }
    } set {
      if let newValue {
        self = .array(newValue)
      }
    }
  }
  var string: String? {
    get {
      switch self {
      case .dictionary, .array: nil
      case .string(let string): string
      case .int(let int): String(int)
      case .double(let double): String(double)
      case .date(let date): date.formatted()
      }
    } set {
      if let newValue {
        self = .string(newValue)
      }
    }
  }
  var int: Int? {
    get {
      switch self {
      case .dictionary, .array, .date: nil
      case .string(let string): Int(string)
      case .int(let int): int
      case .double(let double): Int(double)
      }
    } set {
      if let newValue {
        self = .int(newValue)
      }
    }
  }
  var double: Double? {
    get {
      switch self {
      case .dictionary, .array, .date: nil
      case .string(let string): Double(string)
      case .int(let int): Double(int)
      case .double(let double): double
      }
    } set {
      if let newValue {
        self = .double(newValue)
      }
    }
  }
  var date: Date? {
    get {
      switch self {
      case .date(let date): date
      default: nil
      }
    } set {
      if let newValue {
        self = .date(newValue)
      }
    }
  }
}

struct Lossy<T: Decodable>: Decodable {
  let value: T?
  init(from decoder: any Decoder) throws {
    value = try? decoder.decode()
  }
}
struct LossyArray<Element: Decodable>: Decodable {
  let value: [Element]
  init(from decoder: any Decoder) throws {
    value = (try? decoder.decodeLossy()) ?? []
  }
}

extension Decoder {
  @inlinable
  func decode<T: Decodable>() throws -> T {
    try singleValueContainer().decode(T.self)
  }
  func decodeLossy<Element: Decodable>() throws -> [Element] {
    try singleValueContainer().decode([Lossy<Element>].self).compactMap { $0.value }
  }
}

extension KeyedDecodingContainer {
  @inlinable
  func decode<T: Decodable>(_ key: K) throws -> T {
    try decode(T.self, forKey: key)
  }
  @inlinable
  func decodeIfPresent<T: Decodable>(_ key: K) throws -> T? {
    try decodeIfPresent(T.self, forKey: key)
  }
  @inlinable
  func decodeIfPresent<T: Decodable>(_ key: K, _ defalutValue: @autoclosure () -> (T)) -> T {
    (try? decodeIfPresent(T.self, forKey: key)) ?? defalutValue()
  }
  func decodeLossy<Element: Decodable>(_ key: K) throws -> [Element] {
    try decode([Lossy<Element>].self, forKey: key).compactMap { $0.value }
  }
}
