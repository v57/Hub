//
//  File.swift
//  Hub
//
//  Created by Linux on 05.10.25.
//

#if canImport(SensitiveContentAnalysis)
import SwiftUI
import SensitiveContentAnalysis

extension SCSensitivityAnalyzer {
  static let shared = SCSensitivityAnalyzer()
  static var isAvailable: Bool {
    shared.analysisPolicy != .disabled
  }
}
extension URL {
  func isSensitive() async -> Bool {
    do {
      switch lastPathComponent.fileType {
      case .image:
        return try await SCSensitivityAnalyzer.shared.analyzeImage(at: self).isSensitive
      case .video:
        return try await SCSensitivityAnalyzer.shared.videoAnalysis(forFileAt: self).hasSensitiveContent().isSensitive
      case .audio, .document:
        return false
      }
    } catch {
      return false
    }
  }
}

struct SensitiveContentView: View {
  @State var isSensitive: Bool?
  var body: some View {
    Color.blue.opacity(0.2).overlay {
      if let isSensitive {
        Text(isSensitive ? "Sensitive" : "Not sensitive")
      } else {
        Text("Drop file")
      }
    }.dropFiles { (urls: [URL], point: CGPoint) -> Bool in
      Task {
        isSensitive = await urls.first?.isSensitive()
      }
      return true
    }
  }
}

#Preview {
  SensitiveContentView()
}
#endif
