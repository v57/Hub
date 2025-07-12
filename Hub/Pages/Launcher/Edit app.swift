//
//  Edit app.swift
//  Hub
//
//  Created by Linux on 12.07.25.
//

import SwiftUI

struct EditApp: View {
  let app: Hub.Launcher.AppInfo
  @State var envs: [Env] = [
    Env(),
  ]
  @State var secrets: [Env] = [
    Env(),
  ]
  var body: some View {
    List {
      Section("Environment values") {
        ForEach($envs) { $env in
          EnvView(env: $env)
        }
      }
      Section("Secret keys") {
        ForEach($secrets) { $secret in
          SecretView(env: $secret)
        }
      }
    }.task(id: envs) {
      if !envs.contains(where: { $0.isEmpty }) {
        envs.append(.init())
      }
    }.task(id: secrets) {
      if !secrets.contains(where: { $0.isEmpty }) {
        secrets.append(.init())
      }
    }
  }
  struct EnvView: View {
    @Binding var env: Env
    var body: some View {
      let _ = Self._printChanges()
      HStack {
        TextField("Key", text: $env.key)
          .frame(width: 80)
        TextField("Value", text: $env.value)
      }
    }
  }
  struct SecretView: View {
    @Binding var env: Env
    var body: some View {
      HStack {
        SecureField("Key", text: $env.key)
          .frame(width: 80)
        SecureField("Value", text: $env.value)
      }
    }
  }
  struct Env: Identifiable, Hashable {
    let id = UUID()
    var key: String = ""
    var value: String = ""
    var placeholder: String?
    var isEmpty: Bool { key.isEmpty && value.isEmpty }
  }
}

struct TestEditApp: View {
  @State var apps: Hub.Launcher.Apps?
  var body: some View {
    ZStack {
      if let app = apps?.apps.first {
        EditApp(app: app)
      } else {
        Text("Loading")
      }
    }.hubStream("launcher/info", to: $apps)
      .environment(Hub.test)
  }
}

#Preview {
  TestEditApp().frame(width: 300, height: 300)
}

