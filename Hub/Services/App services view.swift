//
//  App services view.swift
//  Hub
//
//  Created by Linux on 17.10.25.
//

import SwiftUI

struct AppServicesView: View {
  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVGrid(columns: [.init(.adaptive(minimum: 160, maximum: 320), alignment: .top)]) {
          ForEach(Service.allCases, id: \.self) { service in
            HStack {
              VStack {
                Image(systemName: service.image)
                  .resizable().scaledToFill()
                  .frame(width: 32, height: 32)
                Text(service.title)
                Text(service.description).secondary()
                Toggle("Enable", isOn: .constant(true))
              }.multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity).padding()
              .background(RoundedRectangle(cornerRadius: 16).fill(.blue.opacity(0.1)))
          }
        }.padding(.horizontal)
      }.frame(maxWidth: .infinity)
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
