//
//  IconView.swift
//  Hub
//
//  Created by Dmitry Kozlov on 6/7/25.
//

import SwiftUI

struct Icon: Codable, View {
  var symbol: SFSymbolIcon?
  var text: TextIcon?
  struct SFSymbolIcon: Codable, View {
    var name: String
    var foreground: String?
    var background: String?
    var body: some View {
      RoundedRectangle(cornerRadius: 8).fill(.gray.opacity(0.2)).overlay {
        GeometryReader { view in
          Image(systemName: name)
            .font(.system(size: view.size.height * 0.5, weight: .medium))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
  }
  struct TextIcon: Codable, View {
    var name: String
    var foreground: String?
    var background: String?
    var body: some View {
      RoundedRectangle(cornerRadius: 8).fill(.gray.opacity(0.2)).overlay {
        GeometryReader { view in
          Text(name)
            .font(.system(size: view.size.height * 0.5, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.01)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
  }
  var body: some View {
    ZStack {
      if let symbol {
        symbol
      } else if let text {
        text
      }
    }.aspectRatio(1, contentMode: .fit)
  }
}

#Preview {
  HStack {
    Icon(symbol: .init(name: "apple.intelligence"))
    Icon(text: .init(name: "G"))
  }.frame(height: 44).padding()
}
