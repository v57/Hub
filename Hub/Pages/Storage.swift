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
  @State var list = FileList(count: 0, files: [])
  var content: [FileInfo] { list.files }
  @State var selected: Set<String> = []
  var body: some View {
    Table(of: FileInfo.self, selection: $selected) {
      TableColumn("Name", value: \.name)
      TableColumn("Size") { file in
        Text(formatBytes(file.size))
          .foregroundStyle(.secondary)
      }
      TableColumn("Last Modified") { file in
        Text(file.lastModified, format: .dateTime)
          .foregroundStyle(.secondary)
      }
    } rows: {
      ForEach(list.files) { file in
        TableRow(file).contextMenu {
          Button("Delete", role: .destructive) {
            Task {
              try await remove(files: [file.name])
            }
          }
        }
      }
    }.toolbar {
      if selected.count > 0 {
        Button("Delete Selected", systemImage: "trash", role: .destructive) {
          Task {
            try await remove(files: Array(selected))
          }
        }.keyboardShortcut(.delete)
      }
    }.dropDestination { (files: [URL], point: CGPoint) -> Bool in
      Task { try await add(files: files) }
      return true
    }.navigationTitle("Storage").hubStream("hub/status") { (status: Status) in
      hasService = status.contains(service: "s3")
    }.hubStream("s3/list", to: $list)
  }
  func add(files: [URL]) async throws {
    do {
      for file in files {
        if file.hasDirectoryPath {
          var content = [URL]()
          try file.contents(array: &content)
          let prefix = file.absoluteString.count - file.lastPathComponent.count - 1
          let uploading = content.map { url in
            let name = url.absoluteString
            return UploadingFile(target: String(name.suffix(name.count - prefix)), content: url)
          }
          for file in uploading {
            try await upload(file: file)
          }
        } else {
          try await upload(file: UploadingFile(target: file.lastPathComponent, content: file))
        }
      }
    } catch {
      print(error)
    }
  }
  func upload(file: UploadingFile) async throws {
    print("Uploading", file.target)
    let url: URL = try await hub.client.send("s3/write", file.target)
    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
    _ = try await URLSession.shared.upload(for: request, fromFile: file.content)
    try await hub.client.send("s3/updated")
  }
  func remove(files: [String]) async throws {
    do {
      for file in files {
        try await hub.client.send("s3/delete", file)
        try await hub.client.send("s3/updated")
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

struct UploadingFile {
  let target: String
  let content: URL
}
extension URL {
  func contents(array: inout [URL]) throws {
    if hasDirectoryPath {
      let content = try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil)
      for url in content {
        try url.contents(array: &array)
      }
    } else {
      array.append(self)
    }
  }
}

struct FileList: Decodable {
  let count: Int
  let files: [FileInfo]
}
struct FileInfo: Identifiable, Hashable, Decodable {
  var id: String { name }
  let name: String
  let size: Int
  let lastModified: Date
}

#Preview {
  StorageView().environment(Hub.test)
}
