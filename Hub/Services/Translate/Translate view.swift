//
//  Translate.swift
//  Hub
//
//  Created by Linux on 05.10.25.
//

import SwiftUI
import Translation

@available(macOS 15.0, *)
struct TranslateView: View {
  @State var text: String = "Hello"
  @State var translation = ""
  @State var source: String = "en"
  @State var target: String = "de"
  @State var availability = LanguageAvailability()
  @State var languages = [String]()
  @State var configuration: TranslationSession.Configuration?
  var body: some View {
    VStack {
      HStack {
        Picker("Source", selection: $source) {
          ForEach(languages, id: \.self) { language in
            Text(language.languageName).tag(language)
          }
        }
        Picker("Target", selection: $target) {
          ForEach(languages, id: \.self) { language in
            Text(language.languageName).tag(language)
          }
        }
      }
      TextField("Text to translate", text: $text)
      Text(translation).translationTask(configuration) { session in
        Task {
          let result = try await session.translate(text)
          self.translation = result.targetText
        }
      }.id(text)
    }.task {
      languages = await availability.supportedLanguages.map(\.minimalIdentifier).sorted(by: { $0.languageName < $1.languageName })
    }.task(id: source + target) {
      configuration = TranslationSession.Configuration(source: .init(identifier: source), target: .init(identifier: target))
    }
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
