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
  @State var path: String = ""
  var directories: [String] {
    uploadManager.directories(at: path, list.directories)
  }
  var files: [FileInfo] {
    uploadManager.files(at: path, list.files)
  }
  @State var uploadManager = UploadManager.main
  var body: some View {
    Table(of: FileInfo.self, selection: $selected) {
      TableColumn("Name") { file in
        FileView(file: file).tint(selected.contains(file.name) ? .white : .blue)
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
      TableRow(FileInfo(name: path.isEmpty ? "$\(hub.settings.name)" : "/\(path)", size: 0, lastModified: nil))
      ForEach(directories, id: \.self) { file in
        TableRow(FileInfo(name: file, size: 0, lastModified: nil))
          .draggable(DirectoryTransfer(hub: hub, name: file))
      }
      ForEach(files) { file in
        TableRow(file).draggable(FileInfoTransfer(hub: hub, file: file))
      }
    }.contextMenu(forSelectionType: String.self) { files in
      Button("Delete", role: .destructive) {
        Task { await remove(files: Array(files)) }
      }.keyboardShortcut(.delete)
    } primaryAction: { files in
      if files.count == 1, let file = files.first, file.hasSuffix("/") {
        guard !file.isEmpty else { return }
        if file.hasPrefix("/") {
          path = path.parentDirectory
        } else {
          path += file
        }
      }
    }.toolbar {
      if !path.isEmpty {
        Button("Back", systemImage: "chevron.left") {
          path = path.parentDirectory
        }
      }
      if selected.count > 0 {
        Button("Delete Selected", systemImage: "trash", role: .destructive) {
          Task {
            await remove(files: Array(selected))
          }
        }.keyboardShortcut(.delete)
      }
    }.dropDestination { (files: [URL], point: CGPoint) -> Bool in
      add(files: files)
      return true
    }.navigationTitle("Storage").hubStream("hub/status") { (status: Status) in
      hasService = status.contains(service: "s3")
    }.hubStream("s3/list", path, to: $list)
      .environment(uploadManager).contentTransition(.symbolEffect(.replace))
      .progressDraw()
  }
  func add(files: [URL]) {
    uploadManager.upload(files: files, hub: hub)
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
    var body: some View {
      if file.name.first == "/" {
        HStack(spacing: 0) {
          Image(systemName: "chevron.left")
            .frame(minWidth: 25)
          Text(name.dropFirst())
        }.foregroundStyle(.tint).fontWeight(.medium)
      } else if file.name.first == "$" {
        HStack(spacing: 0) {
          Image(systemName: "display")
            .frame(minWidth: 25)
          Text(name.dropFirst())
        }.foregroundStyle(.tint).fontWeight(.medium)
      } else {
        HStack(spacing: 0) {
          IconView(file: file)
            .foregroundStyle(.tint)
            .frame(minWidth: 25)
          Text(name).contentTransition(.numericText()).animation(.smooth, value: name)
        }
      }
    }
    struct IconView: View {
      let file: FileInfo
      @Environment(UploadManager.self) private var uploadManager
      var body: some View {
        let progress = uploadManager.progress(path: file.name)
        let isCompleted: Bool = progress == 1
        Image(systemName: isCompleted ? "checkmark" : icon, variableValue: progress)
          .symbolVariant(progress != nil ? .circle : .fill)
      }
      var icon: String {
        file.isDirectory ? "folder" : fileIcon
      }
      var fileIcon: String {
        switch file.name.components(separatedBy: ".").last {
        case "png", "jpg", "jpeg", "heic", "avif": "photo"
        case "mp4", "mov", "mkv", "avi": "video"
        case "wav", "ogg", "acc", "m4a", "mp3": "speaker.wave.2"
        default: "document"
        }
      }
    }
    var name: String {
      file.isDirectory ? String(file.name.dropLast(1)) : file.name
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
      case .task(let task): return task.progress.progress
      case .directory(let dictionary):
        if let p = path.next(), !p.isEmpty {
          return dictionary[p]?.progress(path: &path)
        } else {
          var progress = FileProgress()
          var edited = false
          self.progress(progress: &progress, edited: &edited)
          guard edited else { return nil }
          return progress.progress
        }
      }
    }
    func progress(progress: inout FileProgress, edited: inout Bool) {
      switch self {
      case .task(let task):
        progress.sent += task.progress.sent
        progress.total += task.progress.total
        edited = true
      case .directory(let dictionary):
        dictionary.values.forEach { $0.progress(progress: &progress, edited: &edited) }
      }
    }
    func resolve(path: inout IndexingIterator<[String]>) -> TaskType? {
      guard let next = path.next(), !next.isEmpty else { return self }
      switch self {
      case .task:
        return nil
      case .directory(let dictionary):
        return dictionary[next]?.resolve(path: &path)
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
  func directories(at path: String, _ current: [String]) -> [String] {
    let set = Set(current)
    var current = current
    let components = path.components(separatedBy: "/")
    var iterator = components.makeIterator()
    tasks.resolve(path: &iterator)?.directories.sorted().forEach { key in
      if !set.contains(key) {
        current.append(key)
      }
    }
    return current
  }
  func files(at path: String, _ current: [FileInfo]) -> [FileInfo] {
    let set = Set(current.map { $0.name })
    var current = current
    let components = path.components(separatedBy: "/")
    var iterator = components.makeIterator()
    tasks.resolve(path: &iterator)?.files.sorted().forEach { key in
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
  func upload(files: [URL], hub: Hub) {
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
            task.progress.total = url.fileSize
            set(path: file.target, task: task)
            upload(hub: hub, file: file, task: task)
          }
        } else {
          let uploadingFile = UploadingFile(target: file.lastPathComponent, content: file)
          let task = UploadTask()
          task.progress.total = file.fileSize
          set(path: uploadingFile.target, task: task)
          upload(hub: hub, file: uploadingFile, task: task)
        }
      }
    } catch {
      print(error)
    }
  }
  func download(hub: Hub, file: FileInfo) async throws -> URL {
    let link: URL = try await hub.client.send("s3/read", file.name)
    let task = UploadTask()
    task.progress.total = Int64(file.size)
    set(path: file.name, task: task)
    defer {
      Task {
        try await Task.sleep(for: .seconds(1))
        remove(path: file.name)
      }
    }
    let url = URL.temporaryDirectory.appending(component: UUID().uuidString, directoryHint: .notDirectory)
    try await session.download(from: link, to: url, delegate: delegate, task: task)
    return url
  }
  func downloadDirectory(hub: Hub, name: String) async throws -> URL {
    let manager = FileManager.default
    let files: [FileInfo] = try await hub.client.send("s3/read/directory", name)
    let root = URL.temporaryDirectory.appending(component: UUID().uuidString, directoryHint: .isDirectory)
    let tasks = files.map { (file: FileInfo) -> UploadTask in
      let task = UploadTask()
      task.progress.total = Int64(file.size)
      set(path: file.name, task: task)
      return task
    }
    defer {
      Task {
        try await Task.sleep(for: .seconds(1))
        files.forEach { file in remove(path: file.name) }
      }
    }
    for (file, task) in zip(files, tasks) {
      let link: URL = try await hub.client.send("s3/read", file.name)
      let path = file.name.components(separatedBy: "/").dropFirst().joined(separator: "/")
      let target = root.appending(path: path, directoryHint: .notDirectory)
      try? manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
      try await session.download(from: link, to: target, delegate: delegate, task: task)
    }
    return root
  }
  struct PendingTask: Hashable {
    let hub: Hub, file: UploadingFile, session: URLSession, delegate: Delegate, task: UploadTask
    func start() async throws {
      let url: URL = try await hub.client.send("s3/write", file.target)
      _ = try await session.upload(file: file.content, to: url, delegate: delegate, task: task)
      try await hub.client.send("s3/updated")
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
    let task = PendingTask(hub: hub, file: file, session: session, delegate: delegate, task: task)
    pending.append(task)
    if running.isEmpty {
      nextPending()
    }
  }
  private func nextPending() {
    guard !pending.isEmpty else { return }
    guard uploadingSize < 10_000_000 else { return }
    let task = pending.removeFirst()
    let total = task.task.progress.total
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
  var session: URLSession
  var delegate: Delegate
  init() {
    let delegate = Delegate()
    self.delegate = delegate
    session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: .main)
  }
  @MainActor
  final class Delegate: NSObject, @preconcurrency URLSessionDownloadDelegate {
    struct Task: Sendable {
      let upload: UploadTask
      var target: URL?
      let continuation: CheckedContinuation<Void, Error>
    }
    var tasks = [URLSessionTask: Task]()
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
      guard let task = tasks[downloadTask] else { return }
      guard let target = task.target else { return }
      try! FileManager.default.moveItem(at: location, to: target)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
      if let error {
        tasks[task]?.continuation.resume(throwing: error)
        tasks[task] = nil
      } else {
        tasks[task]?.continuation.resume()
        tasks[task] = nil
      }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
      guard let task = tasks[task]?.upload else { return }
      guard totalBytesExpectedToSend > 0 else { return }
      let progress = FileProgress(sent: totalBytesSent, total: totalBytesExpectedToSend)
      task.set(progress: progress)
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
      guard let task = tasks[downloadTask]?.upload else { return }
      let progress = FileProgress(sent: totalBytesWritten, total: totalBytesExpectedToWrite)
      task.set(progress: progress)
    }
  }
}
extension URLSession {
  @MainActor
  func download(from: URL, to: URL, delegate: UploadManager.Delegate, task: UploadTask) async throws {
    try await withCheckedThrowingContinuation { continuation in
      let downloadTask = downloadTask(with: URLRequest(url: from))
      delegate.tasks[downloadTask] = .init(upload: task, target: to, continuation: continuation)
      downloadTask.resume()
    }
  }
  @MainActor
  func upload(file: URL, to: URL, delegate: UploadManager.Delegate, task: UploadTask) async throws {
    try await withCheckedThrowingContinuation { continuation in
      var request = URLRequest(url: to)
      request.httpMethod = "PUT"
      let uploadTask = uploadTask(with: request, fromFile: file)
      delegate.tasks[uploadTask] = .init(upload: task, continuation: continuation)
      uploadTask.resume()
    }
  }
}
extension URL {
  var fileSize: Int64 {
    (try? FileManager.default.attributesOfItem(atPath: path(percentEncoded: false))[FileAttributeKey.size] as? Int64) ?? 0
  }
}
extension String {
  var parentDirectory: String {
    guard !isEmpty else { return self }
    let c = components(separatedBy: "/")
    let d = c.prefix(c.last == "" ? c.count - 2 : c.count - 1).joined(separator: "/")
    return d.isEmpty ? d : d + "/"
  }
}

struct FileProgress: Hashable {
  var sent: Int64 = 0
  var total: Int64 = 0
  var progress: Double {
    guard total > 0 else { return 0 }
    return Double(sent) / Double(total)
  }
}

@Observable
final class UploadTask: CustomStringConvertible, Sendable, Hashable {
  var progress = FileProgress()
  @ObservationIgnored
  private var pendingProgress: FileProgress?
  @ObservationIgnored
  private var pendingTask: Task<Void, Error>?
  var description: String { "\(progress.sent)/\(progress.total)" }
  func hash(into hasher: inout Hasher) {
    ObjectIdentifier(self).hash(into: &hasher)
  }
  static func == (l: UploadTask, r: UploadTask) -> Bool {
    l === r
  }
  func set(progress: FileProgress) {
    if pendingTask == nil {
      self.progress = progress
      pendingTask = Task {
        while true {
          try await Task.sleep(for: .milliseconds(200))
          if let pendingProgress {
            self.progress = pendingProgress
            self.pendingProgress = nil
          } else {
            break
          }
        }
        pendingTask = nil
      }
    } else {
      self.pendingProgress = progress
    }
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
  var isDirectory: Bool {
    name.last == "/"
  }
  var ext: String {
    isDirectory ? "" : String(name.split { $0 == "." }.last!)
  }
  let size: Int
  let lastModified: Date?
}

struct FileInfoTransfer: Transferable {
  let hub: Hub
  let file: FileInfo
  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation<Self>(exportedContentType: .data) { file in
      try await SentTransferredFile(file.download(), allowAccessingOriginalFile: false)
    }.suggestedFileName { $0.file.name }
  }
  func download() async throws -> URL {
    do {
      return try await UploadManager.main.download(hub: hub, file: file)
    } catch {
      print(error)
      throw error
    }
  }
}
struct DirectoryTransfer: Transferable {
  let hub: Hub
  let name: String
  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation<Self>(exportedContentType: .folder) { file in
      try await SentTransferredFile(file.download(), allowAccessingOriginalFile: false)
    }.suggestedFileName { String($0.name.dropLast(1)) }
  }
  func download() async throws -> URL {
    do {
      return try await UploadManager.main.downloadDirectory(hub: hub, name: name)
    } catch {
      print(error)
      throw error
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
