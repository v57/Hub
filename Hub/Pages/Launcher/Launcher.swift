//
//  Launcher.swift
//  Hub
//
//  Created by Dmitry Kozlov on 1/6/25.
//

import SwiftUI

#if PRO
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
    URL.homeDirectory.appendingPathComponent("hub-launcher", conformingTo: .directory)
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
#endif
