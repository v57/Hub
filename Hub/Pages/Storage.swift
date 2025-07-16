//
//  Storage.swift
//  Hub
//
//  Created by Linux on 13.07.25.
//

import SwiftUI
import UniformTypeIdentifiers

struct StorageView: View {
  @State var hasService: Bool = false
  @Environment(Hub.self) var hub
  @State var list = FileList(count: 0, files: [], directories: [])
  @State var selected: Set<String> = []
  var directories: [String] {
    uploadManager.directories(list.directories)
  }
  var files: [FileInfo] {
    uploadManager.files(list.files)
  }
  @State var uploadManager = UploadManager.main
  var body: some View {
    Table(of: FileInfo.self, selection: $selected) {
      TableColumn("Name") { file in
        FileView(file: file)
      }
      TableColumn("Size") { file in
        Text(formatBytes(file.size))
          .foregroundStyle(.secondary)
      }.width(60)
      TableColumn("Last Modified") { file in
        if let date = file.lastModified {
          Text(date, format: .dateTime).foregroundStyle(.secondary)
        } else {
          Text("")
        }
      }.width(110)
    } rows: {
      ForEach(directories, id: \.self) { file in
        TableRow(FileInfo(name: file, size: 0, lastModified: nil)).contextMenu {
          Button("Delete", role: .destructive) {
            Task {
              await remove(files: [file])
            }
          }
        }
      }
      ForEach(files) { file in
        TableRow(file).contextMenu {
          Button("Delete", role: .destructive) {
            Task {
              await remove(files: [file.name])
            }
          }
        }.draggable(FileInfoTransfer(hub: hub, file: file))
      }
    }.toolbar {
      if selected.count > 0 {
        Button("Delete Selected", systemImage: "trash", role: .destructive) {
          Task {
            await remove(files: Array(selected))
          }
        }.keyboardShortcut(.delete)
      }
    }.dropDestination { (files: [URL], point: CGPoint) -> Bool in
      Task { try await add(files: files) }
      return true
    }.navigationTitle("Storage").hubStream("hub/status") { (status: Status) in
      hasService = status.contains(service: "s3")
    }.hubStream("s3/list", to: $list)
      .environment(uploadManager).contentTransition(.symbolEffect(.replace))
      .progressDraw()
    
  }
  func add(files: [URL]) async throws {
    try await uploadManager.upload(files: files, hub: hub)
  }
  func remove(files: [String]) async {
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
    guard bytes > 0 else { return "" }
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(bytes))
  }
  struct FileView: View {
    let file: FileInfo
    @Environment(UploadManager.self) var uploadManager
    var isDirectory: Bool { file.name.last == "/" }
    var body: some View {
      let progress = uploadManager.progress(path: file.name)
      let isCompleted: Bool = progress == 1
      HStack(spacing: 0) {
        Image(systemName: isCompleted ? "checkmark" : icon, variableValue: progress)
          .symbolVariant(progress != nil ? .circle : .fill)
          .foregroundStyle(.blue)
          .frame(minWidth: 25)
        Text(name)
      }
    }
    var icon: String {
      isDirectory ? "folder" : fileIcon
    }
    var fileIcon: String {
      switch file.name.components(separatedBy: ".").last {
      case "png", "jpg", "jpeg", "heic", "avif": "photo"
      case "mp4", "mov", "mkv", "avi": "video"
      case "wav", "ogg", "acc", "m4a", "mp3": "speaker.wave.2"
      default: "document"
      }
    }
    var name: String {
      isDirectory ? String(file.name.dropLast(1)) : file.name
    }
  }
}

@Observable
@MainActor
class UploadManager {
  static let main = UploadManager()
  enum TaskType: CustomStringConvertible {
    case task(UploadTask)
    case directory([String: TaskType])
    var description: String {
      switch self {
      case .task(let task): task.description
      case .directory(let dictionary): dictionary.description
      }
    }
    init(path: inout IndexingIterator<[String]>, task: UploadTask) {
      if let next = path.next() {
        self = .directory([next: TaskType(path: &path, task: task)])
      } else {
        self = .task(task)
      }
    }
    mutating func set(path: inout IndexingIterator<[String]>, task: UploadTask) {
      if let next = path.next() {
        switch self {
        case .task: break
        case .directory(var dictionary):
          if var value = dictionary[next] {
            value.set(path: &path, task: task)
            dictionary[next] = value
          } else {
            dictionary[next] = TaskType(path: &path, task: task)
          }
          self = .directory(dictionary)
        }
      } else {
        self = .task(task)
      }
    }
    mutating func remove(path: inout IndexingIterator<[String]>) -> Bool {
      switch self {
      case .task: return true
      case .directory(var dictionary):
        guard let next = path.next() else { return false }
        guard var value = dictionary[next] else { return false }
        if value.remove(path: &path) {
          dictionary[next] = nil
          if dictionary.count == 0 {
            return true
          } else {
            self = .directory(dictionary)
            return false
          }
        } else {
          dictionary[next] = value
          self = .directory(dictionary)
        }
        return false
      }
    }
    func progress(path: inout IndexingIterator<[String]>) -> Double? {
      switch self {
      case .task(let task): return task.progress
      case .directory(let dictionary):
        if let p = path.next(), !p.isEmpty {
          return dictionary[p]?.progress(path: &path)
        } else {
          var sent: Int64 = 0
          var total: Int64 = 0
          var edited = false
          progress(sent: &sent, total: &total, edited: &edited)
          guard edited else { return nil }
          return total > 0 ? Double(sent) / Double(total) : 0
        }
      }
    }
    func progress(sent: inout Int64, total: inout Int64, edited: inout Bool) {
      switch self {
      case .task(let task):
        sent += task.sent
        total += task.total
        edited = true
      case .directory(let dictionary):
        dictionary.values.forEach { $0.progress(sent: &sent, total: &total, edited: &edited) }
      }
    }
    var directories: [String] {
      switch self {
      case .task: return []
      case .directory(let dictionary):
        return dictionary.compactMap { (key: String, t: TaskType) -> String? in
          switch t {
          case .directory: return key + "/"
          case .task: return nil
          }
        }
      }
    }
    var files: [String] {
      switch self {
      case .task: return []
      case .directory(let dictionary):
        return dictionary.compactMap { (key: String, t: TaskType) -> String? in
          switch t {
          case .task: return key
          case .directory: return nil
          }
        }
      }
    }
  }
  func directories(_ current: [String]) -> [String] {
    let set = Set(current)
    var current = current
    tasks.directories.sorted().forEach { key in
      if !set.contains(key) {
        current.append(key)
      }
    }
    return current
  }
  func files(_ current: [FileInfo]) -> [FileInfo] {
    let set = Set(current.map { $0.name })
    var current = current
    tasks.files.sorted().forEach { key in
      if !set.contains(key) {
        current.append(FileInfo(name: key, size: 0, lastModified: nil))
      }
    }
    return current
  }
  func set(path: String, task: UploadTask) {
    let components = path.components(separatedBy: "/")
    var iterator = components.makeIterator()
    tasks.set(path: &iterator, task: task)
  }
  func remove(path: String) {
    let components = path.components(separatedBy: "/")
    var iterator = components.makeIterator()
    if tasks.remove(path: &iterator) {
      tasks = .directory([:])
    }
  }
  private var tasks = TaskType.directory([:])
  func progress(path: String) -> Double? {
    let components = path.components(separatedBy: "/")
    var iterator = components.makeIterator()
    return tasks.progress(path: &iterator)
  }
  func upload(files: [URL], hub: Hub) async throws {
    do {
      for file in files {
        if file.hasDirectoryPath {
          var content = [URL]()
          try file.contents(array: &content)
          let prefix = file.path(percentEncoded: false).count - file.lastPathComponent.count - 1
          for url in content {
            let name = url.path(percentEncoded: false)
            let file = UploadingFile(target: String(name.suffix(name.count - prefix)), content: url)
            let task = UploadTask()
            task.total = url.fileSize
            set(path: file.target, task: task)
            upload(hub: hub, file: file, task: task)
          }
        } else {
          let uploadingFile = UploadingFile(target: file.lastPathComponent, content: file)
          let task = UploadTask()
          task.total = file.fileSize
          set(path: uploadingFile.target, task: task)
          upload(hub: hub, file: uploadingFile, task: task)
        }
      }
    } catch {
      print(error)
    }
  }
  struct PendingTask: Hashable {
    let hub: Hub, file: UploadingFile, task: UploadTask
    func start() async throws {
      print("Uploading", file.target)
      let url: URL = try await hub.client.send("s3/write", file.target)
      var request = URLRequest(url: url)
      request.httpMethod = "PUT"
      _ = try await URLSession.shared.upload(for: request, fromFile: file.content, delegate: task)
      try await hub.client.send("s3/updated")
      print("Uploaded", file.target)
    }
    func hash(into hasher: inout Hasher) {
      task.hash(into: &hasher)
    }
    static func ==(l: Self, r: Self) -> Bool {
      l.task === r.task
    }
  }
  var uploadingSize: Int64 = 0
  var running = Set<PendingTask>()
  var pending = [PendingTask]()
  var completed = Set<String>()
  func upload(hub: Hub, file: UploadingFile, task: UploadTask) {
    let task = PendingTask(hub: hub, file: file, task: task)
    pending.append(task)
    if running.isEmpty {
      nextPending()
    }
  }
  private func nextPending() {
    guard !pending.isEmpty else { return }
    guard uploadingSize < 10_000_000 else { return }
    let task = pending.removeFirst()
    let total = task.task.total
    uploadingSize += total
    running.insert(task)
    Task {
      do {
        try await task.start()
      } catch { }
      uploadingSize -= total
      running.remove(task)
      nextPending()
      completed.insert(task.file.target)
      if running.isEmpty {
        try await Task.sleep(for: .seconds(1))
        completed.forEach { path in
          remove(path: path)
        }
        completed = []
      }
    }
    nextPending()
  }
}
extension URL {
  var fileSize: Int64 {
    (try? FileManager.default.attributesOfItem(atPath: path(percentEncoded: false))[FileAttributeKey.size] as? Int64) ?? 0
  }
}
@Observable
class UploadTask: NSObject, URLSessionTaskDelegate {
  var sent: Int64 = 0
  var total: Int64 = 0
  var progress: Double {
    guard total > 0 else { return 0 }
    return Double(sent) / Double(total)
  }
  override var description: String { "\(sent)/\(total)" }
  func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
    guard totalBytesExpectedToSend > 0 else { return }
    sent = totalBytesSent
    total = totalBytesExpectedToSend
  }
}

struct UploadingFile: Hashable {
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
  var files: [FileInfo]
  var directories: [String]
}
struct FileInfo: Identifiable, Hashable, Decodable {
  var id: String { name }
  let name: String
  let size: Int
  let lastModified: Date?
  var utType: UTType? {
    UTType(filenameExtension: name)
  }
}

struct FileInfoTransfer: Transferable {
  let hub: Hub
  let file: FileInfo
  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .png) { file in
      do {
        let link: URL = try await file.hub.client.send("s3/read", file.file.name)
        let (url, _) = try await URLSession.shared.download(from: link)
        let target = URL.temporaryDirectory.appending(component: file.file.name.components(separatedBy: "/").last!, directoryHint: .notDirectory)
        try? FileManager.default.moveItem(at: url, to: target)
        print(target)
        return SentTransferredFile(target, allowAccessingOriginalFile: false)
      } catch {
        print(error)
        throw error
      }
    }
  }
}

#Preview {
  StorageView().environment(Hub.test).frame(width: 400)
}

extension View {
  @ViewBuilder
  func progressDraw() -> some View {
    if #available(macOS 26.0, *) {
      self.symbolVariableValueMode(.draw)
    } else {
      self
    }
  }
}
