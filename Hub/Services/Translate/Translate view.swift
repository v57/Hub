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
  @ObservationIgnored
  @Published var text: String = ""
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
    ScrollView {
      VStack {
        Text(translator.result).textSelection().contentTransition(.numericText()).translationTask(configuration) { session in
          currentTask?.cancel()
          currentTask = Task {
            for await text in translator.$text.values {
              guard !text.isEmpty else { continue }
              let result = try await session.translate(text).targetText
              withAnimation {
                translator.result = result
              }
            }
          }
        }
      }.task {
        languages = await availability.supportedLanguages.map(\.minimalIdentifier).sorted(by: { $0.languageName < $1.languageName })
      }.task(id: translator.source + translator.target) {
        configuration = TranslationSession.Configuration(source: translator.source.language, target: translator.target.language)
      }.frame(maxWidth: .infinity, alignment: .leading).padding()
    }.safeAreaInset(edge: .bottom) {
      VStack(alignment: .leading) {
        HStack {
          Picker("Source", selection: $translator.source) {
            ForEach(languages, id: \.self) { language in
              Text(language.languageName).tag(language)
            }
          }
          Button("Switch", systemImage: "arrow.left.arrow.right") {
            let source = translator.source
            withAnimation {
              translator.source = translator.target
              translator.target = source
              translator.text = translator.result
            }
          }.labelStyle(.iconOnly)
          Picker("Target", selection: $translator.target) {
            ForEach(languages, id: \.self) { language in
              Text(language.languageName).tag(language)
            }
          }
        }
        TextField("Text to translate", text: $translator.text, axis: .vertical)
          .textFieldStyle(.roundedBorder)
      }.padding()
    }.frame(maxWidth: .infinity)
  }
}
extension String {
  var languageName: String {
    Locale.current.localizedString(forIdentifier: self)!
  }
  var language: Locale.Language {
    Locale.Language(identifier: self)
  }
}

@available(macOS 15.0, iOS 18.0, *)
#Preview {
  NavigationStack {
    TranslateView()
  }
}
