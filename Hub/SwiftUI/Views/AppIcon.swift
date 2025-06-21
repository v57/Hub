//
//  AppIcon.swift
//  Hub
//
//  Created by Dmitry Kozlov on 18/2/25.
//

import SwiftUI

#if DEBUG
extension View {
  func modifier<Content: View>(@ViewBuilder _ modifiy: (Self) -> Content) -> Content {
    modifiy(self)
  }
}

struct AppIcon: View {
  enum Style {
    case light, dark, tint
  }
  var style: Style = .dark
  var fillColor: Color {
    style == .dark ? .black : .white
  }
  var body: some View {
    GeometryReader { view in
      let o = view.size.height / 1024
      GeometryReader { view in
        let scale = view.size.height / 256
        RoundedRectangle(cornerRadius: 0)
          .fill(.radialGradient(fillColor.gradient, center: .init(x: 0.7, y: -0.1), startRadius: 0, endRadius: 480 * scale))
        Circle().fill(AngularGradient(colors: [Color(hue: 0, saturation: 0, brightness: 0.2), .clear], center: .topLeading))
          .strokeBorder(AngularGradient(stops: [.init(color: .white, location: 0), .init(color: .clear, location: 0.2)], center: .topLeading), lineWidth: 1)
          .frame(width: 714 * scale, height: 714 * scale)
      }
      .cornerRadius(175 * o)
      .shadow(color: .black.opacity(0.30), radius: 5*o, y: 10*o)
      .padding(100 * o)
    }
  }
  struct Export: View {
    var body: some View {
      Button("Export") {
        export(size: 16, scale: 1)
        export(size: 16, scale: 2)
        export(size: 32, scale: 1)
        export(size: 32, scale: 2)
        export(size: 128, scale: 1)
        export(size: 128, scale: 2)
        export(size: 256, scale: 1)
        export(size: 256, scale: 2)
        export(size: 512, scale: 1)
        export(size: 512, scale: 2)
      }
    }
    func export(size: Int, scale: Int) {
      let renderer = ImageRenderer(content: AppIcon().frame(width: CGFloat(size), height: CGFloat(size)))
      renderer.scale = CGFloat(scale)
      if let image = renderer.cgImage {
        do {
          try image.heic(0.8).write(to: .downloadsDirectory.appendingPathComponent("AppIcon\(size)@\(scale)x.heic", conformingTo: .heic))
          print("Exported \(size)x\(size)@\(scale)x.heic")
        } catch {
          print(error)
        }
      }
    }
  }
}



extension CGImage {
  func heic(_ quality: CGFloat) -> Data {
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.heic" as CFString, 1, nil)!
    
    var properties = [CFString: Any]()
    properties[kCGImageDestinationLossyCompressionQuality] = quality
    // properties[kCGImagePropertyJFIFDictionary] = [kCGImagePropertyJFIFIsProgressive: true]
    
    CGImageDestinationAddImage(destination, self, properties as NSDictionary)
    CGImageDestinationFinalize(destination)
    
    return data as Data
  }
}

#Preview {
  VStack(spacing: 0) {
//    AppIcon(style: .light)
//      .frame(width: 256, height: 256)
    AppIcon()
      .frame(width: 512, height: 512)
    HStack(spacing: 0) {
      AppIcon()
        .frame(width: 256, height: 256)
      VStack(spacing: 0) {
        AppIcon()
          .frame(width: 128, height: 128)
        AppIcon()
          .frame(width: 64, height: 64)
      }
    }
    HStack {
      ForEach(0..<10) { _ in
        AppIcon()
          .frame(width: 50, height: 50)
      }
    }
//    AppIcon(style: .tint)
//      .frame(width: 256, height: 256)
  }
}
#endif
