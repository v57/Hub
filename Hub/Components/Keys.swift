//
//  Hmac.swift
//  Hub
//
//  Created by Dmitry Kozlov on 23/2/25.
//

import Foundation
import CryptoKit
import Security

struct KeyChain {
  static let main = KeyChain()
  var tag: String { "me.v57.Hub.main" }
  var key: String = ""
  private let fileURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("keyfile.txt")
  
  init() {
    if let key = fromKeychain() {
      self.key = key
    } else if let key = fromFile() {
      self.key = key
    } else {
      let key = generateKey()
      if storeInKeyChain(key: key) {
        self.key = key
      } else {
        storeInFile(key: key)
        self.key = key
      }
    }
  }
  
  // Gets key from keychain at self.tag
  // Returns nil if key not found or keychain is not available
  private func fromKeychain() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: tag,
      kSecReturnData as String: kCFBooleanTrue!,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]
    
    var dataTypeRef: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
    
    guard status == errSecSuccess, let data = dataTypeRef as? Data else {
      return nil
    }
    
    return String(data: data, encoding: .utf8)
  }
  
  // Reads key from file
  // Returns nil if file not found or can't convert to string
  private func fromFile() -> String? {
    do {
      let data = try Data(contentsOf: fileURL)
      return String(data: data, encoding: .utf8)
    } catch {
      return nil
    }
  }
  
  // Generates random 32 bytes securely
  // Returns in base64 format
  private func generateKey() -> String {
    var keyData = Data(count: 32)
    let result = keyData.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
    return result == errSecSuccess ? keyData.base64EncodedString() : ""
  }
  
  // Returns true if successful
  private func storeInKeyChain(key: String) -> Bool {
    let data = key.data(using: .utf8)!
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: tag,
      kSecValueData as String: data
    ]
    
    // Delete existing key if it exists
    SecItemDelete(query as CFDictionary)
    
    let status = SecItemAdd(query as CFDictionary, nil)
    return status == errSecSuccess
  }
  
  // Writes key to file
  // This should not return errors
  private func storeInFile(key: String) {
    try! key.write(to: fileURL, atomically: true, encoding: .utf8)
  }
}
