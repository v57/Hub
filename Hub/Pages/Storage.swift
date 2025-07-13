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
  @State var files = FileList(name: "", keyCount: 0, contents: [
    
  ])
  var content: [FileList.FileInfo] { files.contents }
  @State var selected: Set<String> = []
  var body: some View {
    Table(files.contents, selection: $selected) {
      TableColumn("Name") { file in
        Text(file.key)
      }
      TableColumn("Size") { file in
        Text(formatBytes(file.size))
          .foregroundStyle(.secondary)
      }
      TableColumn("Last Modified") { file in
        Text(file.lastModified, format: .dateTime)
          .foregroundStyle(.secondary)
      }
    }.dropDestination { (files: [URL], point: CGPoint) -> Bool in
      Task { try await add(files: files) }
      return true
    }.navigationTitle("Storage").hubStream("hub/status") { (status: Status) in
      hasService = status.contains(service: "s3")
    }.task {
      do {
        files = try await hub.client.send("s3/list")
      } catch {}
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
  func formatBytes(_ bytes: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(bytes))
  }
}

struct FileList: Decodable {
  let name: String
  let keyCount: Int
  let contents: [FileInfo]
  struct FileInfo: Identifiable, Hashable, Decodable {
    var id: String { key }
    let key: String
    let size: Int
    let lastModified: Date
  }
}

#Preview {
  StorageView().environment(Hub.test)
}
