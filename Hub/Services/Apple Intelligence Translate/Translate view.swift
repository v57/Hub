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
  @State var installed: Set<String>?
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
              Label(language.languageName, systemImage: icon(status: installed?.contains(language)))
                .symbolVariant(.circle.fill)
                .tag(language)
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
              Label(language.languageName, systemImage: icon(status: installed?.contains(language)))
                .symbolVariant(.circle.fill).tag(language)
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
    }.task {
      installed = await Set(LanguageAvailability().installed().map { $0.minimalIdentifier })
    }.frame(maxWidth: .infinity).modifier(TranslationModifier()).environment(translation)
  }
  func icon(status: Bool?) -> String {
    switch status {
    case false:
      "arrow.down"
    default:
      ""
    }
  }
}

@available(macOS 15.0, iOS 18.0, *, *)
extension LanguageAvailability {
  struct Pairs {
    var available = Set<LanguagePair>()
    var unavailable = Set<LanguagePair>()
  }
  struct LanguagePair: Hashable {
    let source: Locale.Language
    let target: Locale.Language
  }
  func pairs() async -> Pairs {
    var pairs = Pairs()
    let languages = await supportedLanguages
    let sendable = LanguageAvailability()
    for i in 0..<languages.count - 1 {
      let source = languages[i]
      for j in (i+1)..<languages.count {
        let target = languages[j]
        let status = await sendable.status(from: source, to: target)
        switch status {
        case .installed:
          pairs.available.insert(LanguagePair(source: source, target: target))
        case .unsupported: break
        case .supported:
          pairs.unavailable.insert(LanguagePair(source: source, target: target))
        @unknown default: break
        }
      }
    }
    return pairs
  }
  func installed() async -> Set<Locale.Language> {
    let languages = await supportedLanguages
    let sendable = LanguageAvailability()
    var operations = 0
    var installed = Set<Locale.Language>()
    for i in 0..<languages.count - 1 {
      let source = languages[i]
      for j in (i+1)..<languages.count {
        let target = languages[j]
        let status = await sendable.status(from: source, to: target)
        operations += 1
        switch status {
        case .installed:
          installed.insert(source)
          installed.insert(target)
        default: break
        }
      }
    }
    return installed
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
