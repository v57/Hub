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
  init(symbol: SFSymbolIcon? = nil, text: TextIcon? = nil) {
    self.symbol = symbol
    self.text = text
  }
  init(from decoder: any Decoder) throws {
    do {
      let container = try decoder.singleValueContainer()
      let text = try container.decode(String.self)
      self.text = .init(name: text)
    } catch {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      symbol = container.decodeIfPresent(.symbol)
      text = container.decodeIfPresent(.text)
    }
  }
  struct SFSymbolIcon: Codable, Hashable {
    var name: String
    var colors: IconColors?
    init(from decoder: any Decoder) throws {
      do {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        self.name = text
      } catch {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(.name)
        colors = container.decodeIfPresent(.colors)
      }
    }
    init(name: String, colors: IconColors? = nil) {
      self.name = name
      self.colors = colors
    }
    
    fileprivate func body(dark: Bool) -> some View {
      GeometryReader { view in
        if let color = colors?.background(dark: dark)?.color {
          Color.white
          RadialGradient(colors: [color.opacity(0.6), color], center: .topTrailing, startRadius: 0, endRadius: view.size.height)
        } else {
          Color.gray.opacity(0.2)
        }
        Image(systemName: name)
          .font(.system(size: view.size.height * 0.4, weight: .medium))
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }
  struct TextIcon: Codable, Hashable {
    var name: String
    var colors: IconColors?
    init(from decoder: any Decoder) throws {
      do {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        self.name = text
      } catch {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(.name)
        colors = container.decodeIfPresent(.colors)
      }
    }
    init(name: String, colors: IconColors? = nil) {
      self.name = name
      self.colors = colors
    }
    
    fileprivate func body(dark: Bool) -> some View {
      GeometryReader { view in
        if let color = colors?.background(dark: dark)?.color {
          Color.white
          RadialGradient(colors: [color, color.opacity(0.6)], center: .bottomLeading, startRadius: 0, endRadius: view.size.height * 2)
        } else {
          Color.gray.opacity(0.2)
        }
        Text(name)
          .font(.system(size: view.size.height * 0.4, weight: .bold, design: .rounded))
          .foregroundStyle(colors?.foreground(dark: dark)?.color ?? .primary)
          .minimumScaleFactor(0.01)
          .padding(.horizontal, 4)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }
  func body(dark: Bool) -> some View {
    ZStack {
      if let symbol {
        symbol.body(dark: dark)
      } else if let text {
        text.body(dark: dark)
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
  var cornerRadius: CGFloat = 12
  @Environment(\.colorScheme) var colorScheme
  var body: some View {
    icon.body(dark: colorScheme == .dark)
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
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
