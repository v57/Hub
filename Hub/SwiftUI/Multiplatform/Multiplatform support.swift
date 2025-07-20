//
//  tvOS.swift
//  Hub
//
//  Created by Linux on 20.07.25.
//

import SwiftUI

#if !os(tvOS)
extension PickerStyle where Self == PalettePickerStyle {
  static var main: PalettePickerStyle { .palette }
}
#else
extension PickerStyle where Self == MenuPickerStyle {
  static var main: MenuPickerStyle { .menu }
}
#endif

extension View {
  func textSelection() -> some View {
#if os(iOS) || os(macOS)
    textSelection(.enabled)
#else
    self
#endif
  }
  func dropFiles<Transferable: SwiftUI.Transferable>(action: @escaping ([Transferable], CGPoint) -> Bool) -> some View {
#if os(iOS) || os(macOS)
    dropDestination(action: action)
#else
    self
#endif
  }
}
