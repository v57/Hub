//
//  App services view.swift
//  Hub
//
//  Created by Linux on 17.10.25.
//

import SwiftUI

struct AppServicesView: View {
  @State var open: Service?
  var body: some View {
    NavigationStack {
      List {
        ForEach(Service.allCases, id: \.self) { item in
          HStack {
            IconView(icon: Icon(symbol: Icon.SFSymbolIcon(name: item.image))).frame(width: 44, height: 44)
            VStack(alignment: .leading) {
              Text(item.title)
              Text(item.description).secondary()
            }
            Spacer()
            Button("Open") {
              open = item
            }.buttonStyle(DownloadButtonStyle())
          }
        }
      }.navigationDestination(item: $open) { service in
        switch service {
        case .chat:
          if #available(macOS 26.0, iOS 26.0, *) {
            ChatView()
          } else {
            ContentUnavailableView("Service not available", systemImage: "translate", description: Text("Translation feature was introduced in \(Text("iOS 26").bold()) and \(Text("macOS 26").bold()) for devices with \(Text("Apple Intelligence").bold()) so it's not possible to run it on other devices or lower versions"))
          }
        case .imageEncoder:
          ImageEncoderView()
        case .videoEncoder:
          Text("Video encoder")
        case .translate:
          if #available(macOS 15.0, iOS 18.0, *) {
            TranslateView()
          } else {
            ContentUnavailableView("Service not available", systemImage: "translate", description: Text("Translation feature was introduced in \(Text("iOS 18").bold()) and \(Text("macOS 15").bold()) so it's not possible to run it on other devices or lower versions"))
          }
        case .sensitiveContent:
          SensitiveContentView()
        }
      }
    }
  }
  enum Service: CaseIterable {
    case imageEncoder, videoEncoder, translate, chat, sensitiveContent
    var title: LocalizedStringKey {
      switch self {
      case .imageEncoder: return "Image encoder"
      case .videoEncoder: return "Video encoder"
      case .sensitiveContent: return "Detect sensitive content"
      case .translate: return "Apple Intelligence Translate"
      case .chat: return "Apple Intelligence Chat"
      }
    }
    var image: String {
      switch self {
      case .imageEncoder: return "photo"
      case .videoEncoder: return "video"
      case .sensitiveContent: return "photo.badge.magnifyingglass"
      case .translate: return "translate"
      case .chat: return "apple.intelligence"
      }
    }
    var description: String {
      switch self {
      case .imageEncoder: return "Compress images by converting them to .heic format"
      case .videoEncoder: return "Compress images by converting them to .hevc format"
      case .sensitiveContent: return "Detect if image or video contains sensitive content"
      case .translate: return "Translate text using on device translation"
      case .chat: return "Chat with apple intelligence on device model"
      }
    }
  }
  enum Availability {
    case available, iOS(Int), macOS(Int), unsupportedDevice
  }
}

#Preview {
  AppServicesView()
}
