//
//  HubApp.swift
//  Hub
//
//  Created by Dmitry Kozlov on 17/2/25.
//

import SwiftUI

@main
struct HubApp: App {
#if os(macOS)
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#endif
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}

#if os(macOS)
import Foundation
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
}
#endif
