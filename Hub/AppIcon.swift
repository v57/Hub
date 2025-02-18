//
//  AppIcon.swift
//  Hub
//
//  Created by Dmitry Kozlov on 18/2/25.
//

import SwiftUI

extension View {
  func modifier<Content: View>(@ViewBuilder _ modifiy: (Self) -> Content) -> Content {
    modifiy(self)
  }
}

struct AppIcon: View {
  enum Style {
    case light, dark, tint
  }
  @State var angle: Double = 0
  @State var midOffset: Double = 5
  @State var offset: Double = 15
  @State var size: Double = 90
  var style: Style = .dark
  var fillColor: Color {
    style == .dark ? .black : .white
  }
  var body: some View {
    GeometryReader { view in
      let scale = view.size.height / 256
      ZStack {
        RoundedRectangle(cornerRadius: 0)
          .fill(.radialGradient(fillColor.gradient, center: .top, startRadius: 100 * scale, endRadius: 480 * scale))
        ZStack {
          RoundedRectangle(cornerRadius: 16 * scale).rotation(.degrees(45))
            .fill(.gray.gradient)
            .rotation3DEffect(.degrees(angle), axis: (1, 0, 0))
            .offset(y: offset * 2 * scale)
          RoundedRectangle(cornerRadius: 16 * scale).rotation(.degrees(45))
            .fill(.red.gradient)
            .strokeBorder(.regularMaterial, lineWidth: 8)
            .rotation3DEffect(.degrees(angle), axis: (1, 0, 0))
            .offset(y: midOffset * scale)
          RoundedRectangle(cornerRadius: 16 * scale).rotation(.degrees(45))
            .fill(.yellow.gradient)
            .strokeBorder(.regularMaterial, lineWidth: 8)
            .rotation3DEffect(.degrees(angle), axis: (1, 0, 0))
            .offset(y: 0)
          RoundedRectangle(cornerRadius: 16 * scale).rotation(.degrees(45))
            .fill(.blue.gradient)
            .strokeBorder(.regularMaterial, lineWidth: 8)
            .rotation3DEffect(.degrees(angle), axis: (1, 0, 0))
            .offset(y: -midOffset * scale)
          RoundedRectangle(cornerRadius: 16 * scale).rotation(.degrees(45))
            .fill(.regularMaterial)
            .rotation3DEffect(.degrees(angle), axis: (1, 0, 0))
            .offset(y: -offset * 2 * scale)
        }.frame(width: size * scale, height: size * 1.1 * scale)
          .shadow(color: .black.opacity(0.2), radius: 16 * scale)
          .colorScheme(.light)
          .modifier {
            if style == .tint {
              $0.luminanceToAlpha()
            } else {
              $0
            }
          }
      }
    }
  }
}

#Preview {
  VStack {
    AppIcon(style: .light)
      .frame(width: 256, height: 256)
    AppIcon(style: .dark)
      .frame(width: 256, height: 256)
    AppIcon(style: .tint)
      .frame(width: 256, height: 256)
  }
}
