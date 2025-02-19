//
//  Shell.swift
//  Hub
//
//  Created by Dmitry Kozlov on 19/2/25.
//

#if os(macOS)
import Foundation

struct ShellError: Error {
  let code: Int32
}
func sh(_ command: String, from: URL = .homeDirectory) async throws {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/bin/zsh")
  process.arguments = ["-c", command.replacingOccurrences(of: "\n", with: ";")]
  process.currentDirectoryURL = from
  try await withCheckedThrowingContinuation { continuation in
    process.terminationHandler = { process in
      if process.terminationStatus == 0 {
        continuation.resume()
      } else {
        print(process.terminationStatus)
        continuation.resume(throwing: ShellError(code: process.terminationStatus))
      }
    }
    do {
      try process.run()
    } catch {
      print(error)
      continuation.resume(throwing: error)
    }
  }
}
#endif
