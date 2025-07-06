//
//  IconView.swift
//  Hub
//
//  Created by Dmitry Kozlov on 6/7/25.
//

import SwiftUI

struct Icon: Codable, Hashable {
  var symbol: SFSymbolIcon?
  var text: TextIcon?
  struct SFSymbolIcon: Codable, Hashable {
    var name: String
    var colors: IconColors?
    func body(cornerRadius: CGFloat, dark: Bool) -> some View {
      GeometryReader { view in
        if let color = colors?.background(dark: dark)?.color {
          RoundedRectangle(cornerRadius: cornerRadius).fill(RadialGradient(colors: [color.opacity(0.6), color], center: .topTrailing, startRadius: 0, endRadius: view.size.height))
        } else {
          RoundedRectangle(cornerRadius: cornerRadius).fill(Color.gray.opacity(0.2))
        }
        Image(systemName: name)
          .font(.system(size: view.size.height * 0.5, weight: .medium))
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }
  struct TextIcon: Codable, Hashable {
    var name: String
    var colors: IconColors?
    func body(cornerRadius: CGFloat, dark: Bool) -> some View {
      GeometryReader { view in
        if let color = colors?.background(dark: dark)?.color {
          RoundedRectangle(cornerRadius: cornerRadius).fill(RadialGradient(colors: [color.opacity(0.6), color], center: .topTrailing, startRadius: 0, endRadius: view.size.height))
        } else {
          RoundedRectangle(cornerRadius: cornerRadius).fill(Color.gray.opacity(0.2))
        }
        Text(name)
          .font(.system(size: view.size.height * 0.5, weight: .bold, design: .rounded))
          .foregroundStyle(colors?.foreground(dark: dark)?.color ?? .primary)
          .minimumScaleFactor(0.01)
          .padding(.horizontal, 4)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }
  func body(cornerRadius: CGFloat, dark: Bool) -> some View {
    ZStack {
      if let symbol {
        symbol.body(cornerRadius: cornerRadius, dark: dark)
      } else if let text {
        text.body(cornerRadius: cornerRadius, dark: dark)
      }
    }.aspectRatio(1, contentMode: .fit)
  }
}
struct IconColors: Codable, Hashable {
  var foreground: String?
  var foregroundDark: String?
  var background: String?
  var backgroundDark: String?
  fileprivate func foreground(dark: Bool) -> String? {
    dark ? foregroundDark ?? foreground : foreground
  }
  fileprivate func background(dark: Bool) -> String? {
    dark ? backgroundDark ?? background : background
  }
}
struct IconView: View {
  let icon: Icon
  var cornerRadius: CGFloat = 0
  @Environment(\.colorScheme) var colorScheme
  var body: some View {
    icon.body(cornerRadius: cornerRadius, dark: colorScheme == .dark)
  }
}


extension String {
  var color: Color? {
    Color(hex: self)
  }
}

extension Color {
  init?(hex: String) {
    guard let int = Int(hex, radix: 16) else { return nil }
    let red = (int >> 0xf) & 0xff
    let green = (int >> 0x8) & 0xff
    let blue = int & 0xff
    self.init(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
  }
}

#Preview {
  HStack {
    IconView(icon: Icon(symbol: .init(name: "apple.intelligence")))
    IconView(icon: Icon(text: .init(name: "R", colors: IconColors(foreground: "ffffff", background: "ff0000"))))
    IconView(icon: Icon(text: .init(name: "G", colors: IconColors(foreground: "00ff00", background: "000000"))))
    IconView(icon: Icon(text: .init(name: "B", colors: IconColors(foreground: "0000dd", foregroundDark: "aaaaff"))))
    IconView(icon: Icon(text: .init(name: "W", colors: IconColors(foreground: "ffffff"))))
  }.frame(height: 44).padding()
}
