//
//  Translate service.swift
//  Hub
//
//  Created by Linux on 30.10.25.
//

import HubClient
import Translation
import Combine

extension HubService.Group {
  @available(macOS 15.0, iOS 18.0, *)
  func translate(_ languages: LanguageAvailability.LanguagePair) -> Self {
    post("text/translate/\(languages.sourceId.lowercased())/\(languages.targetId.lowercased())") { text in
      try await Translation.main.translate(text: text, source: languages.sourceId, target: languages.targetId)
    }
  }
}
struct TranslationGroups {
  var groups: [String: HubService.Group] = [:]
  var groupsSubscription: AnyCancellable?
}
extension AppServices {
  @available(macOS 15.0, iOS 18.0, *)
  func translationGroups() {
    translation.groupsSubscription = Translation.main.$pairs.compactMap { $0 }.sink { [weak self] pairs in
      guard let self else { return }
      if translation.groups.isEmpty {
        for pair in pairs.available {
          translation.groups[pair.id] = self.hub.service.group(enabled: true).translate(pair)
        }
        for pair in pairs.unavailable {
          translation.groups[pair.id] = self.hub.service.group(enabled: false).translate(pair)
        }
      } else {
        for pair in pairs.available {
          translation.groups[pair.id]?.isEnabled = true
        }
        for pair in pairs.unavailable {
          translation.groups[pair.id]?.isEnabled = false
        }
      }
    }
  }
}
