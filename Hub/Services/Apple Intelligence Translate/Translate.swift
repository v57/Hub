//
//  Translate.swift
//  Hub
//
//  Created by Linux on 29.10.25.
//

import Translation
import SwiftUI

@available(macOS 15.0, iOS 18.0, *)
@Observable
@MainActor
class Translation {
  static let main = Translation()
  var configuration: TranslationSession.Configuration?
  var tasks = [TranslationTask]()
  @ObservationIgnored
  var session: TranslationSession?
  @ObservationIgnored
  var task: Task<Void, Error>? {
    didSet {
      oldValue?.cancel()
    }
  }
  var isRunning = false
  @ObservationIgnored
  @Published
  var pairs: LanguageAvailability.Pairs?
  
  private init() {
    Task { await updateLanguages() }
  }
  func translate(text: String, source: String, target: String) async throws -> String {
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let source = source.language
    let target = target.language
    guard !text.isEmpty else { return "" }
    if let session, session.sourceLanguage == source && session.targetLanguage == target {
      return try await Task {
        try await session.translate(text).targetText
      }.value
    }
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let task = TranslationTask(text: text, source: source, target: target) { result in
          continuation.resume(with: result)
        }
        tasks.append(task)
        if !isRunning {
          resume()
        }
      }
    } onCancel: {
      Task { @MainActor in
        if let index = tasks.firstIndex(where: { $0.text == text && $0.source == source && $0.target == target }) {
          tasks[index].completion(.failure(CancellationError()))
          tasks.remove(at: index) // unsafe
        }
      }
    }
  }
  @MainActor
  func run(session: TranslationSession) async throws {
    self.session = session
    isRunning = true
    while let index = tasks.firstIndex(where: { $0.source == session.sourceLanguage && $0.target == session.targetLanguage }) {
      let task = tasks[index]
      tasks.remove(at: index)
      await Task {
        do {
          let result = try await session.translate(task.text).targetText
          task.completion(.success(result))
        } catch {
          task.completion(.failure(error))
        }
      }.value
    }
    isRunning = false
    resume()
  }
  
  func resume() {
    if let task = tasks.first {
      if configuration?.source != task.source || configuration?.target != task.target {
        configuration = .init(source: task.source, target: task.target)
      }
    } else {
      isRunning = false
    }
  }
  func updateLanguages() async {
    pairs = await LanguageAvailability().pairs()
  }
  struct TranslationTask {
    let id = UUID()
    let text: String
    let source: Locale.Language
    let target: Locale.Language
    let completion: (Result<String, Error>) -> Void
  }
}

@available(macOS 15.0, iOS 18.0, *)
struct TranslationModifier: ViewModifier {
  @Environment(Translation.self) var translation
  func body(content: Content) -> some View {
    content.translationTask(translation.configuration) { session in
      Task {
        try await translation.run(session: session)
      }
    }
  }
}
