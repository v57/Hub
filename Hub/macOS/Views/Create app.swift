//
//  Create app.swift
//  Hub
//
//  Created by Dmitry Kozlov on 22/2/25.
//

import SwiftUI

struct CreateApp: View {
  enum AppType {
    case bun, shell
  }
  @Environment(\.dismiss) var dismiss
  @State var install: String = ""
  @State var uninstall: String = ""
  @State var launch: String = ""
  @State var type: AppType = .shell
  @State var repo: String = ""
  @State var restarts: Bool = true
  @State var name: String = ""
  var defaultName: String? {
    switch type {
    case .bun:
      let components = repo.components(separatedBy: "/")
      if components.count > 1, !components[1].isEmpty {
        return components[1]
      }
    case .shell:
      if !launch.isEmpty {
        return launch.components(separatedBy: " ").first
      }
    }
    return nil
  }
  var isReady: Bool { defaultName != nil }
  var body: some View {
    VStack(alignment: .leading) {
      Picker("Type", selection: $type) {
        Text("Shell").tag(AppType.shell)
        Text("Bun").tag(AppType.bun)
      }.pickerStyle(.palette)
      TextField(defaultName ?? "App Name", text: $name)
        .fontDesign(.monospaced)
      switch type {
      case .bun:
        TextField("GitHub Repo", text: $repo)
      case .shell:
        VStack {
          TextField("Install script", text: $install, axis: .vertical)
            .lineLimit(3...100)
          TextField("Uninstall script", text: $uninstall, axis: .vertical)
            .lineLimit(3...100)
          TextField("Launch command", text: $launch)
        }.fontDesign(.monospaced)
      }
      Toggle("Restart on crash", isOn: $restarts)
    }.frame(maxHeight: .infinity, alignment: .top)
      .toolbar {
        HStack {
          Button("Cancel", role: .cancel) {
            dismiss()
          }
          if isReady {
            Button("Create") {
              guard let create else { return }
              Task {
                try await hub.client.send("launcher/app/create", create)
              }
              dismiss()
            }.buttonStyle(.borderedProminent).transition(.blurReplace)
          }
        }.animation(.smooth, value: isReady)
      }
  }
  var create: Create? {
    guard let defaultName else { return nil }
    return Create(name: name.replacingEmpty(with: defaultName), active: true, restarts: restarts, setup: setup)
  }
  var setup: Setup {
    switch type {
    case .bun: .bun(.init(repo: repo, commit: nil, command: nil))
    case .shell: .sh(.init(directory: nil, install: install.commands(), uninstall: uninstall.commands(), run: launch))
    }
  }
  struct Create: Encodable {
    let name: String
    let active: Bool
    let restarts: Bool
    let setup: Setup
    
    private enum CodingKeys: CodingKey {
      case name
      case active
      case restarts
    }
    
    func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(name, forKey: .name)
      try container.encode(active, forKey: .active)
      try container.encode(restarts, forKey: .restarts)
      try setup.encode(to: encoder)
    }
  }
  enum Setup: Encodable {
    case bun(Bun)
    struct Bun: Encodable {
      let repo: String
      let commit: String?
      let command: String?
    }
    case sh(Sh)
    struct Sh: Encodable {
      let directory: String?
      let install: [String]?
      let uninstall: [String]?
      let run: String
    }
    
    private enum CodingKeys: CodingKey {
      case type
    }
    
    func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      switch self {
      case .bun(let bun):
        try container.encode("bun", forKey: .type)
        try bun.encode(to: encoder)
      case .sh(let sh):
        try container.encode("sh", forKey: .type)
        try sh.encode(to: encoder)
      }
    }
  }
}
extension String {
  func replacingEmpty(with value: String) -> String {
    isEmpty ? value : self
  }
  func commands() -> [String]? {
    isEmpty ? nil : components(separatedBy: "\n")
  }
}

#Preview {
  CreateApp().padding()
    .frame(maxWidth: 300)
}
