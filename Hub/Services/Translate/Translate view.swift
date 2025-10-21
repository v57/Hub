//
//  Translate.swift
//  Hub
//
//  Created by Linux on 05.10.25.
//

import SwiftUI
import Translation

@Observable
class Translator {
  var text: String = ""
  var result: String = ""
  var source: String = "en"
  var target: String = "de"
}

@available(macOS 15.0, iOS 18.0, *)
struct TranslateView: View {
  @Bindable var translator = Translator()
  @State var configuration: TranslationSession.Configuration?
  @State var availability = LanguageAvailability()
  @State var languages = [String]()
  @State var session: TranslationSession?
  @State var currentTask: Task<Void, Error>?
  var taskId: String {
    guard let session else { return "" }
    return (session.sourceLanguage?.minimalIdentifier ?? "") + (session.targetLanguage?.minimalIdentifier ?? "")
  }
  var body: some View {
    VStack {
      HStack {
        Picker("Source", selection: $translator.source) {
          ForEach(languages, id: \.self) { language in
            Text(language.languageName).tag(language)
          }
        }
        Picker("Target", selection: $translator.target) {
          ForEach(languages, id: \.self) { language in
            Text(language.languageName).tag(language)
          }
        }
      }
      TextField("Text to translate", text: $translator.text)
      Text(translator.result).contentTransition(.numericText()).translationTask(configuration) { session in
        currentTask?.cancel()
        currentTask = Task {
          if #available(macOS 26.0, iOS 26.0, *) {
            for await text in Observations({ translator.text }) {
              guard !text.isEmpty else { continue }
              let result = try await session.translate(text).targetText
              withAnimation {
                translator.result = result
              }
            }
          }
        }
      }
    }.task {
      languages = await availability.supportedLanguages.map(\.minimalIdentifier).sorted(by: { $0.languageName < $1.languageName })
    }.task(id: translator.source + translator.target) {
      configuration = TranslationSession.Configuration(source: .init(identifier: translator.source), target: .init(identifier: translator.target))
    }.padding()
  }
}
extension String {
  var languageName: String {
    Locale.current.localizedString(forIdentifier: self)!
  }
}

//@available(macOS 15.0, *)
//#Preview {
//  TranslateView()
//}
