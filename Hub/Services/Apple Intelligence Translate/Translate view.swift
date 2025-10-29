//
//  Translate.swift
//  Hub
//
//  Created by Linux on 05.10.25.
//

import SwiftUI
import Translation

@available(macOS 15.0, iOS 18.0, *)
struct TranslateView: View {
  @State var availability = LanguageAvailability()
  @State var languages = [String]()
  @State var source: String = "en"
  @State var target: String = "de"
  @State var translation = Translation()
  @State var text: String = ""
  @State var result: String = ""
  var body: some View {
    ScrollView {
      VStack {
        Text(result).textSelection().contentTransition(.numericText())
      }.task {
        languages = await availability.supportedLanguages.map(\.minimalIdentifier).sorted(by: { $0.languageName < $1.languageName })
      }.frame(maxWidth: .infinity, alignment: .leading).padding()
    }.safeAreaInset(edge: .bottom) {
      VStack(alignment: .leading) {
        HStack {
          Picker("Source", selection: $source) {
            ForEach(languages, id: \.self) { language in
              Text(language.languageName).tag(language)
            }
          }
          Button("Switch", systemImage: "arrow.left.arrow.right") {
            let source = source
            withAnimation {
              self.source = target
              target = source
              text = result
            }
          }.labelStyle(.iconOnly)
          Picker("Target", selection: $target) {
            ForEach(languages, id: \.self) { language in
              Text(language.languageName).tag(language)
            }
          }
        }
        TextField("Text to translate", text: $text, axis: .vertical)
          .textFieldStyle(.roundedBorder)
      }.padding().task(id: text) {
        do {
          let text = try await translation.translate(text: text, source: source, target: target)
          withAnimation { result = text }
        } catch { }
      }
    }.frame(maxWidth: .infinity).modifier(TranslationModifier()).environment(translation)
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
