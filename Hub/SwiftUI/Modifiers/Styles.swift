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
