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
  func error() -> some View {
    font(.caption2).fontWeight(.medium).foregroundStyle(.red)
  }
  func badgeStyle() -> some View {
    font(.caption2).foregroundStyle(.white)
      .padding(.horizontal, 6).padding(.vertical, 2)
      .background(.red, in: .capsule)
  }
  @ViewBuilder
  func glassProminentButton() -> some View {
    #if os(visionOS)
    buttonStyle(.borderedProminent)
    #else
    if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *) {
      buttonStyle(.glassProminent)
    } else {
      buttonStyle(.borderedProminent)
    }
    #endif
  }
  func modifier<Content: View>(@ViewBuilder _ modifiy: (Self) -> Content) -> Content {
    modifiy(self)
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
      .padding(.horizontal, 12)
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
