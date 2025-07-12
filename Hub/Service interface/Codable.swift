//
//  Codable.swift
//  Hub
//
//  Created by Linux on 12.07.25.
//

import Foundation

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
