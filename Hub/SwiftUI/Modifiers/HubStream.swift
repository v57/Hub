//
//  HubStream.swift
//  Hub
//
//  Created by Dmitry Kozlov on 21/6/25.
//

import SwiftUI

extension View {
  func hubStream<T: Decodable>(_ path: String, initial: T? = nil, action: @MainActor @escaping (T) -> Void) -> some View {
    modifier(HubStreamModifier(path: path, initial: initial, action: action))
  }
  func hubStream<T: Decodable>(_ path: String, to: Binding<T>, animation: Animation? = nil) -> some View {
    hubStream(path, initial: nil, to: to, animation: animation)
  }
  func hubStream<T: Decodable>(_ path: String, to: Binding<T?>, animation: Animation? = nil) -> some View {
    hubStream(path, initial: nil, to: to, animation: animation)
  }
  func hubStream<T: Decodable>(_ path: String, initial: T?, to: Binding<T>, animation: Animation? = nil) -> some View {
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
extension Hub {
  var taskId: TaskId {
    TaskId(id: id, isConnected: isConnected)
  }
  @MainActor
  struct TaskId: Hashable {
    var id: Hub.ID
    var isConnected: Bool
  }
}
