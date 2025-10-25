//
//  Video encoder view.swift
//  Hub
//
//  Created by Linux on 25.10.25.
//

import SwiftUI
import AVFoundation

struct VideoEncoderView: View {
  struct Operation: Identifiable {
    var id: URL { file }
    var file: URL
    var name: String { file.lastPathComponent }
    var targetName: String {
      file.deletingPathExtension().lastPathComponent
    }
    var size: Int
    var result: URL?
    var error: Bool = false
    var resultSize: Int { Int(result?.fileSize ?? 0) }
  }
  @State var selected: Set<Operation.ID> = []
  @State var operations: [Operation] = []
  @State private var sortOrder = [KeyPathComparator(\Operation.name, comparator: .localized)]
  @State private var isRunning = false
  @State private var quality: CGFloat = 0.6
  @State private var metadata: Bool = false
  var body: some View {
    Table(of: Operation.self, selection: $selected, sortOrder: $sortOrder) {
      TableColumn("Name", value: \Operation.name) { (file: Operation) in
        NameView(file: file).tint(selected.contains(file.id) ? .white : .blue)
      }
      TableColumn("Size", value: \Operation.size) { (file: Operation) in
        Text(file.size.bytesString).foregroundStyle(.secondary)
      }.width(60)
      TableColumn("Result", value: \Operation.resultSize) { (file: Operation) in
        Text(file.resultSize.bytesString).foregroundStyle(.secondary)
      }.width(60)
    } rows: {
      ForEach(operations) { file in
        TableRow(file).draggable(VideoTransfer(file: file))
      }
    }.dropFiles { (files: [URL], point: CGPoint) -> Bool in
      var content = [URL]()
      for file in files {
        file.contents(array: &content)
      }
      for file in content {
        if file.lastPathComponent.fileType == .video {
          operations.append(Operation(file: file, size: Int(file.fileSize), result: nil))
        }
      }
      if !isRunning {
        Task { try await run() }
      }
      return true
    }.safeAreaInset(edge: .top) {
      HStack {
        Toggle("Keep metadata", isOn: $metadata)
        HStack {
          Text("Quality \(Int(quality * 100))%")
          Slider(value: $quality, in: 0.1...0.9, step: 0.1)
            .frame(maxWidth: 100)
        }
      }.frame(maxWidth: .infinity, alignment: .trailing).padding(.horizontal).secondary()
    }
  }
  struct VideoTransfer: Transferable {
    let file: Operation
    static var transferRepresentation: some TransferRepresentation {
      FileRepresentation(exportedContentType: .quickTimeMovie) { item in
        SentTransferredFile(item.file.result!, allowAccessingOriginalFile: true)
      }.suggestedFileName { $0.file.targetName }
    }
  }
  struct NameView: View {
    let file: Operation
    var icon: String {
      if file.error {
        "exclamationmark.octagon.fill"
      } else if file.result != nil {
        "checkmark.circle.fill"
      } else {
        "clock.fill"
      }
    }
    var color: Color {
      if file.error {
        .red
      } else if file.result != nil {
        .green
      } else {
        .gray
      }
    }
    var body: some View {
      HStack {
        Image(systemName: icon).foregroundStyle(color)
          .contentTransition(.symbolEffect(.replace))
        Text(file.name)
      }
    }
  }
  func run() async throws {
    isRunning = true
    var completed = 0
    for i in 0..<operations.count {
      let operation = operations[i]
      guard operation.result == nil else { return }
      try Task.checkCancellation()
      do {
        let asset = AVAsset(url: operation.file)
        let target = URL.temporaryDirectory.appending(component: UUID().uuidString, directoryHint: .notDirectory).appendingPathExtension(for: .quickTimeMovie)
        try await VideoEncoder().encode(from: asset, to: target, settings: .hevc(quality: 0.5, size: nil, frameReordering: false)) { _, _ in }
        operations[i].result = target
        completed += 1
      } catch {
        operations[i].error = true
      }
    }
    isRunning = false
    if completed > 0 {
      try await run()
    }
  }
}

#Preview {
  VideoEncoderView()
}
