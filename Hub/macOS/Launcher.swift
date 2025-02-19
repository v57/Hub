//
//  Launcher.swift
//  Hub
//
//  Created by Dmitry Kozlov on 19/2/25.
//

#if os(macOS)
import SwiftUI

struct LauncherView: View {
  var launcher: Launcher { .main }
  var status: Launcher.Status {
    launcher.status
  }
  var body: some View {
    let isConnected = hub.status?.services.contains(where: {
      $0.name == "launcher"
    }) ?? false
    List {
      HStack {
        VStack(alignment: .leading) {
          Text("Launcher")
          Text(status.statusText).font(.caption2)
            .foregroundStyle(.secondary)
        }
        Spacer()
        if let buttonTitle = status.buttonTitle {
          Button(buttonTitle) {
            Task {
              switch status {
              case .notInstalled, .installationFailed:
                await Launcher.main.install()
              case .installed, .offline:
                await Launcher.main.launch()
              case .running:
                await Launcher.main.stop()
              case .status: break
              }
            }
          }.buttonStyle(.borderedProminent)
        }
      }.contextMenu {
        Button("Update") {
          Task {
            
          }
        }
      }
    }.task(id: isConnected) {
      if isConnected {
        launcher.status = .running
      } else {
        if case .running = Launcher.main.status {
          launcher.status = .offline
        }
      }
    }
  }
}
extension Launcher.Status {
  var statusText: LocalizedStringKey {
    switch self {
    case .notInstalled: "Not installed"
    case .installationFailed: "Installation failed"
    case .installed: "Installed"
    case .status(let s): s
    case .offline: "Offline"
    case .running: "Running"
    }
  }
  var buttonTitle: LocalizedStringKey? {
    switch self {
    case .notInstalled: "Install"
    case .installed, .offline: "Launch"
    case .running: "Stop"
    default: nil
    }
  }
}

@Observable
class Launcher {
  static var main = Launcher()
  var isInstalled: Bool = false
  var status: Status
  enum Status {
    case installed, offline, running
    case notInstalled
    case status(LocalizedStringKey), installationFailed
  }
  static var url: URL {
    .homeDirectory.appendingPathComponent("hub-launcher", conformingTo: .directory)
  }
  var url: URL { Launcher.url }
  init() {
    if FileManager.default.fileExists(atPath: Launcher.url.path()) {
      status = .offline
    } else {
      status = .notInstalled
    }
  }
  func install() async {
    do {
      status = .status("Downloading")
      try await sh("git clone https://github.com/v57/hub-launcher")
      status = .status("Installing")
      try await sh("""
source .zshrc
cd hub-launcher
bun i
""")
      status = .installed
    } catch {
      status = .installationFailed
    }
  }
  func launch() async {
    do {
      status = .status("Launching")
      try await sh("""
source .zshrc
if screen -ls | grep v57launcher >/dev/null; then
  screen -X -S v57launcher quit
fi
cd hub-launcher
screen -dmS v57launcher bun .
""")
    } catch {
      status = .offline
    }
  }
  func stop() async {
    do {
      status = .status("Stopping")
      _ = try await hub.client.send("launcher/stop") as Int?
    } catch {
      status = .offline
    }
  }
  func update() async {
    try? await sh("git pull", from: url)
  }
}

#Preview {
  LauncherView()
}
#endif
