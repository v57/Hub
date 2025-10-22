//
//  Foundation models.swift
//  Hub
//
//  Created by Linux on 08.10.25.
//

import SwiftUI
import FoundationModels

@available(macOS 26.0, iOS 26.0, *)
struct ChatView: View {
  @State var session = LanguageModelSession()
  @State var messages: [Message] = []
  @State var text: String = ""
  var body: some View {
    List(messages) { message in
      Text(message.text).contentTransition(.numericText())
    }.safeAreaInset(edge: .bottom) {
      HStack {
        TextField("Type your message...", text: $text)
        Button("Send") {
          Task { try await send(text: text) }
        }.disabled(session.isResponding)
      }.padding()
    }
  }
  @Observable
  class Message: Identifiable {
    var text: AttributedString
    init(text: String) {
      self.text = text.markdown
    }
  }
  func send(text: String) async throws {
    self.text = ""
    messages.append(Message(text: text))
    Task {
      let message = Message(text: "responding...")
      messages.append(message)
      for try await response in session.streamResponse(to: text) {
        withAnimation {
          message.text = response.content.markdown
        }
      }
    }
  }
}
extension String {
  var markdown: AttributedString {
    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnly, failurePolicy: .returnPartiallyParsedIfPossible)
    return (try? AttributedString(markdown: self, options: options)) ?? AttributedString(self)
  }
}

@available(macOS 26.0, iOS 26.0, *)
#Preview {
  ChatView()
}







enum ALM {
  struct Message: Codable {
    let role: String
    let content: String
  }
  struct ChatRequest: Codable {
    let messages: [Message]
  }
}
