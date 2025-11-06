//
//  Install S3.swift
//  Hub
//
//  Created by Linux on 05.11.25.
//

import SwiftUI

struct InstallS3: View {
  @Environment(Hub.self) var hub
  enum Guide {
    case wasabi, manual
  }
  @State var installer = Installer()
  @State var guide: Guide = .manual
  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        switch guide {
        case .wasabi:
          Wasabi()
        case .manual:
          Manual()
        }
      }.frame(maxWidth: .infinity, alignment: .leading).toolbar {
        Picker("Storage Options", selection: $guide) {
          Text("Wasabi").tag(Guide.wasabi)
          Text("Manual").tag(Guide.manual)
        }.pickerStyle(.segmented)
      }.safeAreaPadding(.horizontal)
    }.task {
      installer.set(hub: hub)
    }.navigationTitle("Connect Storage").environment(installer)
  }
  struct Wasabi: View {
    @Environment(Installer.self) var installer
    @State var bucketName: String = ""
    @State var region: Region?
    @State var accessKey: String = ""
    @State var secretKey: String = ""
    var isReady: Bool {
      !bucketName.isEmpty && region != nil && !accessKey.isEmpty && !secretKey.isEmpty
    }
    struct Section<Content: View>: View {
      let number: Int
      let title: LocalizedStringKey
      @ViewBuilder let content: Content
      var body: some View {
        HStack(alignment: .firstTextBaseline) {
          Text("\(number).").font(.title3).fontWeight(.bold)
          VStack(alignment: .leading) {
            Text(title).font(.title3).fontWeight(.bold)
              .padding(.bottom, 2)
            content
          }
        }.padding(.top)
      }
    }
    var body: some View {
      Section(number: 0, title: "Wasabi Pricing") {
        HStack {
          Text("30 day trial")
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemFill).opacity(0.4), in: .capsule)
          Text("$7 / TB / month")
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemFill).opacity(0.4), in: .capsule)
        }.fontWeight(.medium)
      }
      Section(number: 1, title: "Create account") {
        Text("""
1. Go to [Wasabi](https://wasabi.com) Website and create account
2. Login
""")
      }
      Section(number: 2, title: "Create bucket") {
        Text("""
1. Go to [Buckets](https://console.wasabisys.com/file_manager)
2. Click **Create bucket**
3. Name your bucket (you can put anything)
4. Select server
5. Fill data in the fields below
""")
        TextField("Bucket Name", text: $bucketName)
          .frame(maxWidth: 400)
        Picker("Server region", selection: $region) {
          ForEach(Region.allCases, id: \.self) { region in
            Text("\(region.flag) \(region.name)").tag(region)
          }
        }
      }
      Section(number: 3, title: "Create access key for your service") {
        Text("""
1. Go to [Access Keys](https://console.wasabisys.com/access_keys)
2. Click **Create Access Key**
3. Click **Create**
4. Enter **Access Key** and **Secret Key** in the fields below 
""")
        TextField("Access Key", text: $accessKey).frame(maxWidth: 400)
        TextField("Secret Key", text: $secretKey).frame(maxWidth: 400)
        CreationButtons(settings: settings)
      }
    }
    var settings: Hub.Launcher.AppSettings? {
      guard isReady else { return nil }
      guard let region else { return nil }
      return .s3(access: accessKey, secret: secretKey, region: region.region, endpoint: region.endpoint, bucket: bucketName)
    }
    enum Region: CaseIterable {
      case tokyo, osaka, singapore, sydney, toronto, amsterdam, frankfurt, milan, unitedKingdom, paris, unitedKingdom2, texas, nVirginia, nVirginia2, oregon, sanJose
      var name: String {
        switch self {
        case .tokyo: "Tokyo ap-northeast-1"
        case .osaka: "Osaka ap-northeast-2"
        case .singapore: "Singapore ap-southeast-1"
        case .sydney: "Sydney ap-southeast-2"
        case .toronto: "Toronto ca-central-1"
        case .amsterdam: "Amsterdam eu-central-1"
        case .frankfurt: "Frankfurt eu-central-2"
        case .milan: "Milan eu-south-1"
        case .unitedKingdom: "United Kingdom eu-west-1"
        case .paris: "Paris eu-west-2"
        case .unitedKingdom2: "United Kingdom eu-west-3"
        case .texas: "Texas us-central-1"
        case .nVirginia: "N. Virginia us-east-1"
        case .nVirginia2: "N. Virginia us-east-2"
        case .oregon: "Oregon us-west-1"
        case .sanJose: "San Jose us-west-2"
        }
      }
      var region: String {
        switch self {
        case .tokyo:"ap-northeast-1"
        case .osaka:"ap-northeast-2"
        case .singapore:"ap-southeast-1"
        case .sydney:"ap-southeast-2"
        case .toronto:"ca-central-1"
        case .amsterdam:"eu-central-1"
        case .frankfurt:"eu-central-2"
        case .milan:"eu-south-1"
        case .unitedKingdom:"eu-west-1"
        case .paris:"eu-west-2"
        case .unitedKingdom2:"eu-west-3"
        case .texas:"us-central-1"
        case .nVirginia:"us-east-1"
        case .nVirginia2:"us-east-2"
        case .oregon:"us-west-1"
        case .sanJose:"us-west-2"
        }
      }
      var flag: String {
        switch self {
        case .tokyo:"🇯🇵"
        case .osaka:"🇯🇵"
        case .singapore:"🇸🇬"
        case .sydney:"🇦🇺"
        case .toronto:"🇨🇦"
        case .amsterdam:"🇳🇱"
        case .frankfurt:"🇩🇪"
        case .milan:"🇪🇸"
        case .unitedKingdom:"🇬🇧"
        case .paris:"🇫🇷"
        case .unitedKingdom2:"🇬🇧"
        case .texas:"🇺🇸"
        case .nVirginia:"🇺🇸"
        case .nVirginia2:"🇺🇸"
        case .oregon:"🇺🇸"
        case .sanJose:"🇺🇸"
        }
      }
      var endpoint: String {
        if self == .nVirginia {
          return "https://s3.wasabisys.com"
        } else {
          return "https://s3.\(region).wasabisys.com"
        }
      }
    }
  }
  struct Manual: View {
    @Environment(Installer.self) var installer
    @State var bucketName: String = ""
    @State var region: String = ""
    @State var endpoint: String = ""
    @State var accessKey: String = ""
    @State var secretKey: String = ""
    var body: some View {
      TextField("Endpoint", text: $endpoint)
      TextField("Region", text: $region)
      TextField("Bucket name", text: $bucketName)
      TextField("Access Key", text: $accessKey)
      TextField("Secret Key", text: $secretKey)
      CreationButtons(settings: settings)
    }
    var isReady: Bool {
      !bucketName.isEmpty && !region.isEmpty && !endpoint.isEmpty && !accessKey.isEmpty && !secretKey.isEmpty
    }
    var settings: Hub.Launcher.AppSettings? {
      return isReady ? .s3(access: accessKey, secret: secretKey, region: region, endpoint: endpoint, bucket: bucketName) : nil
    }
  }
  struct CreationButtons: View {
    @Environment(Installer.self) private var installer
    let settings: Hub.Launcher.AppSettings?
    @State var testSucccessful: Bool?
    var body: some View {
      HStack {
        if installer.permission != nil {
          AsyncButton("Allow Access") {
            try await installer.allow()
          }
        } else if installer.storageInstalled {
          AsyncButton("Test") {
            testSucccessful = nil
            testSucccessful = try await installer.test()
          }
        }
        AsyncButton(installer.storageInstalled ? "Update" : "Create") {
          if let settings {
            try await installer.set(settings: settings)
          }
        }
        if let testSucccessful {
          Image(systemName: testSucccessful ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundStyle(testSucccessful ? .green : .red)
        }
      }.buttonStyle(.borderedProminent).disabled(settings == nil)
    }
  }
  @Observable class Installer {
    var hub: Hub?
    var listenTasks = [Task<Void, Error>]() {
      didSet { oldValue.forEach { $0.cancel() } }
    }
    var storageInstalled = false
    var serviceAvailable = false
    var permission: SecurityView.PendingAuthorization?
    static var s3: String { "S3 Storage" }
    @MainActor
    func set(hub: Hub) {
      guard self.hub !== hub else { return }
      self.hub = hub
      listenTasks = [
        Task {
          for try await apps: Hub.Launcher.Apps in hub.client.values("launcher/info") {
            storageInstalled = apps.apps.contains(where: { $0.name == Installer.s3 })
          }
        },
        Task {
          for try await status: Status in hub.client.values("hub/status") {
            serviceAvailable = status.services.contains(where: { $0.name.starts(with: Installer.s3) })
          }
        },
        Task {
          for try await permissions: [SecurityView.PendingAuthorization] in hub.client.values("hub/permissions/pending") {
            permission = permissions.last(where: { $0.pending.contains(where: { $0.starts(with: "s3/") }) })
          }
        },
      ]
    }
    func set(settings: Hub.Launcher.AppSettings) async throws {
      try await hub?.launcher.setupS3(id: Installer.s3, update: storageInstalled, settings: settings)
    }
    func allow() async throws {
      guard let permission, let hub else { return }
      try await hub.client.send("hub/permissions/add", SecurityView.Allow(services: permission.pending, permission: permission.id))
      self.permission = nil
    }
    func test() async throws -> Bool {
      guard let hub else { return false }
      do {
        try await hub.client.send("s3/list")
        return true
      } catch {
        return false
      }
    }
  }
}

extension Hub.Launcher.AppSettings {
  static func s3(access: String, secret: String, region: String, endpoint: String, bucket: String) -> Self {
    Hub.Launcher.AppSettings(env: [
      "S3_ACCESS_KEY_ID": access,
      "S3_REGION": region,
      "S3_ENDPOINT": endpoint,
      "S3_BUCKET": bucket
    ], secrets: [
      "S3_SECRET_ACCESS_KEY": secret
    ])
  }
}
extension Hub.Launcher {
  @MainActor
  func setupS3(id: String, update: Bool, settings: Hub.Launcher.AppSettings) async throws {
    if update {
      try await app(id: id).updateSettings(settings)
    } else {
      try await create(.init(name: id, active: true, restarts: true, setup: .bun(.init(repo: "v57/hub-s3", commit: nil, command: nil)), settings: settings))
    }
  }
}

#Preview {
  InstallS3().environment(Hub.test)
}

