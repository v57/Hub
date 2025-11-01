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
            if let hub = Hubs.main.selectedHub, let publisher = item.servicePublisher(hub: hub) {
              HubButton(hub: hub, publisher: publisher, service: item)
            } else {
              ServiceContent(item: item, isSharing: nil)
            }
            Spacer()
            Button("Open") {
              open = item
            }.buttonStyle(DownloadButtonStyle())
          }
        }
      }.safeAreaInset(edge: .bottom) {
        NavigationLink("Farm") {
          FarmView()
        }.glassProminentButton().padding()
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
  struct HubButton: View {
    let hub: Hub
    let publisher: Published<Bool>.Publisher
    let service: Service
    @State var isEnabled: Bool = false
    var body: some View {
      Button {
        withAnimation {
          isEnabled.toggle()
        }
        service.setService(enabled: isEnabled, hub: hub)
      } label: {
        ServiceContent(item: service, isSharing: isEnabled)
      }.onReceive(publisher) { isEnabled = $0 }
        .buttonStyle(.plain)
    }
  }
  struct ServiceContent: View {
    let item: Service
    let isSharing: Bool?
    var body: some View {
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.gray.opacity(0.2))
        .overlay {
          Image(systemName: item.image)
            .font(.system(size: 17.6)).fontWeight(.medium)
        }.frame(width: 44, height: 44).overlay(alignment: .topTrailing) {
          if let isSharing {
            Image(systemName: "square.and.arrow.up.circle.fill")
              .foregroundStyle(isSharing ? .white : .primary, isSharing ? .blue : Color(.tertiarySystemFill))
              .font(.title).labelStyle(.iconOnly)
              .offset(x: 6, y: -4)
          }
        }
      VStack(alignment: .leading) {
        HStack {
          Text(item.title).lineLimit(2)
        }
        Text(item.description).secondary().lineLimit(3)
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
    @MainActor
    func servicePublisher(hub: Hub) -> Published<Bool>.Publisher? {
      switch self {
      case .imageEncoder: hub.appServices.image.$isEnabled
      case .videoEncoder: hub.appServices.video.$isEnabled
      case .translate: hub.appServices.$translationEnabled
      case .chat: hub.appServices.chat?.$isEnabled
      case .sensitiveContent: hub.appServices.sensitiveContent.$isEnabled
      }
    }
    @MainActor
    func setService(enabled: Bool, hub: Hub) {
      switch self {
      case .imageEncoder: hub.appServices.image.isEnabled = enabled
      case .videoEncoder: hub.appServices.video.isEnabled = enabled
      case .translate: hub.appServices.translationEnabled = enabled
      case .chat: hub.appServices.chat?.isEnabled = enabled
      case .sensitiveContent: hub.appServices.sensitiveContent.isEnabled = enabled
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
