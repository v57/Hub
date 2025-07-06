//
//  IconView.swift
//  Hub
//
//  Created by Dmitry Kozlov on 6/7/25.
//

import SwiftUI

struct Icon: Codable {
  var symbol: SFSymbolIcon?
  var text: TextIcon?
  struct SFSymbolIcon: Codable {
    var name: String
    var foreground: String?
    var background: String?
    func body(cornerRadius: CGFloat) -> some View {
      GeometryReader { view in
        if let color = background?.color {
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
  struct TextIcon: Codable {
    var name: String
    var foreground: String?
    var background: String?
    private var foregroundGradient: AnyGradient {
      foreground?.color?.gradient ?? Color.primary.gradient
    }
    private var backgroundGradient: AnyGradient {
      background?.color?.gradient ?? Color.gray.opacity(0.2).gradient
    }
    func body(cornerRadius: CGFloat) -> some View {
      GeometryReader { view in
        if let color = background?.color {
          RoundedRectangle(cornerRadius: cornerRadius).fill(RadialGradient(colors: [color.opacity(0.6), color], center: .topTrailing, startRadius: 0, endRadius: view.size.height))
        } else {
          RoundedRectangle(cornerRadius: cornerRadius).fill(Color.gray.opacity(0.2))
        }
        Text(name)
          .font(.system(size: view.size.height * 0.5, weight: .bold, design: .rounded))
          .foregroundStyle(foregroundGradient)
          .minimumScaleFactor(0.01)
          .padding(.horizontal, 4)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }
  func body(cornerRadius: CGFloat) -> some View {
    ZStack {
      if let symbol {
        symbol.body(cornerRadius: cornerRadius)
      } else if let text {
        text.body(cornerRadius: cornerRadius)
      }
    }.aspectRatio(1, contentMode: .fit)
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
    Icon(symbol: .init(name: "apple.intelligence")).body(cornerRadius: 8)
    Icon(text: .init(name: "R", foreground: "ffffff", background: "ff0000")).body(cornerRadius: 8)
    Icon(text: .init(name: "G", foreground: "00ff00", background: "000000")).body(cornerRadius: 8)
    Icon(text: .init(name: "B", foreground: "0000ff")).body(cornerRadius: 8)
    Icon(text: .init(name: "W", foreground: "ffffff")).body(cornerRadius: 8)
  }.frame(height: 44).padding()
}
