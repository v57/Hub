//
//  Styles.swift
//  Hub
//
//  Created by Dmitry Kozlov on 12/6/25.
//

import SwiftUI

extension View {
  func secondary() -> some View {
    font(.caption2).foregroundStyle(.secondary)
  }
  func badgeStyle() -> some View {
    font(.caption2).foregroundStyle(.white)
      .padding(.horizontal, 6).padding(.vertical, 2)
      .background(.red, in: .capsule)
  }
}

struct ActionButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.foregroundStyle(.blue)
      .fontWeight(.medium)
      .padding(.horizontal, 12)
      .padding(.vertical, 4)
      .frame(minWidth: 60)
      .background(.blue.opacity(0.15), in: .capsule)
  }
}
struct DownloadButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.foregroundStyle(.blue)
      .fontWeight(.medium)
      .padding(.horizontal, 4)
      .padding(.vertical, 4)
      .frame(minWidth: 60)
      .background(.blue.opacity(0.15), in: .capsule)
  }
}
struct TabButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.foregroundStyle(.white)
      .fontWeight(.medium)
      .padding(.horizontal, 4)
      .padding(.vertical, 4)
      .frame(minWidth: 60)
      .background(.blue, in: .capsule)
  }
}
