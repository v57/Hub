//
//  Keyboard.swift
//  Hub
//
//  Created by Linux on 24.02.26.
//

import SwiftUI

extension View {
  func keyboard(style: KeyboardStyle) -> some View {
    modifier(style)
  }
}
enum KeyboardStyle: ViewModifier {
  case url
  func body(content: Content) -> some View {
    switch self {
    case .url:
#if os(macOS)
      content
        .textContentType(.URL)
        .disableAutocorrection(true)
#else
      content
        .textContentType(.URL)
        .disableAutocorrection(true)
        .keyboardType(.URL)
        .autocapitalization(.none)
#endif
    }
  }
}
