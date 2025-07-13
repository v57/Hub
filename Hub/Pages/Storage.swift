//
//  Storage.swift
//  Hub
//
//  Created by Linux on 13.07.25.
//

import SwiftUI

struct StorageView: View {
  @State var hasService: Bool = false
  @Environment(Hub.self) var hub
  var body: some View {
    List {
      if hasService {
        
      } else {
        Text("No storage")
      }
    }.dropDestination { (files: [URL], point: CGPoint) -> Bool in
      Task { try await add(files: files) }
      return true
    }.navigationTitle("Storage").hubStream("hub/status") { (status: Status) in
      hasService = status.contains(service: "s3")
    }
  }
  func add(files: [URL]) async throws {
    do {
      for file in files {
        let fileName = file.lastPathComponent
        let url: URL = try await hub.client.send("s3/write", fileName)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        _ = try await URLSession.shared.upload(for: request, fromFile: file)
      }
    } catch {
      print(error)
    }
  }
}
