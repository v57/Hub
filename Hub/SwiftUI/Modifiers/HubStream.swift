//
//  HubStream.swift
//  Hub
//
//  Created by Dmitry Kozlov on 21/6/25.
//

import SwiftUI

extension View {
  // MARK: Without body
  func hubStream<T: Decodable>(_ path: String, initial: T? = nil, action: @MainActor @escaping (T) -> Void) -> some View {
    modifier(HubStreamModifier(path: path, initial: initial, action: action))
  }
  func hubStream<T: Decodable>(_ path: String, initial: T? = nil, to: Binding<T>, animation: Animation? = nil) -> some View {
    hubStream(path, initial: initial) { (value: T) in
      withAnimation(animation) {
        to.wrappedValue = value
      }
    }
  }
  func hubStream<T: Decodable>(_ path: String, initial: T?, to: Binding<T?>, animation: Animation? = nil) -> some View {
    hubStream(path, initial: initial) { (value: T) in
      withAnimation(animation) {
        to.wrappedValue = value
      }
    }
  }
  // MARK: With body
  func hubStream<T: Decodable, Body>(_ path: String, _ body: Body, initial: T? = nil, action: @MainActor @escaping (T) -> Void) -> some View
  where Body: Encodable & Sendable & Hashable {
    modifier(HubStreamBodyModifier(path: path, body: body, initial: initial, action: action))
  }
  func hubStream<T: Decodable, Body>(_ path: String, _ body: Body, initial: T? = nil, to: Binding<T>, animation: Animation? = nil) -> some View
  where Body: Encodable & Sendable & Hashable {
    hubStream(path, body, initial: initial) { (value: T) in
      withAnimation(animation) {
        to.wrappedValue = value
      }
    }
  }
  func hubStream<T: Decodable, Body>(_ path: String, _ body: Body, initial: T?, to: Binding<T?>, animation: Animation? = nil) -> some View
  where Body: Encodable & Sendable & Hashable {
    hubStream(path, body, initial: initial) { (value: T) in
      withAnimation(animation) {
        to.wrappedValue = value
      }
    }
  }
}

private struct HubStreamModifier<T: Decodable>: ViewModifier {
  let path: String
  let initial: T?
  let action: @MainActor (T) -> Void
  @Environment(Hub.self) private var hub
  func body(content: Content) -> some View {
    content.task(id: hub.taskId) {
      if let initial {
        action(initial)
      }
      guard hub.isConnected else { return }
      do {
        for try await value: T in hub.client.values(path) {
          action(value)
        }
      } catch is CancellationError {
        
      } catch {
        print("\(path):", error)
      }
    }
  }
}
private struct HubStreamBodyModifier<T: Decodable, Body: Encodable & Hashable & Sendable>: ViewModifier {
  let path: String
  let body: Body
  let initial: T?
  let action: @MainActor (T) -> Void
  @Environment(Hub.self) private var hub
  func body(content: Content) -> some View {
    content.task(id: hub.taskId(body: body)) {
      if let initial {
        action(initial)
      }
      guard hub.isConnected else { return }
      do {
        for try await value: T in hub.client.values(path, body) {
          action(value)
        }
      } catch is CancellationError {
        
      } catch {
        print("\(path):", error)
      }
    }
  }
}
extension Hub {
  var taskId: TaskId {
    TaskId(id: id, isConnected: isConnected)
  }
  func taskId<Body: Hashable>(body: Body) -> TaskBodyId<Body> {
    TaskBodyId(id: id, isConnected: isConnected, body: body)
  }
  @MainActor
  struct TaskId: Hashable {
    var id: Hub.ID
    var isConnected: Bool
  }
  @MainActor
  struct TaskBodyId<Body: Hashable>: Hashable {
    var id: Hub.ID
    var isConnected: Bool
    var body: Body
  }
}
