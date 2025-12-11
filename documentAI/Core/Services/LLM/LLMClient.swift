//
//  LLMClient.swift
//  documentAI
//
//  Protocol for LLM client implementations
//

import Foundation

protocol LLMClient {
    
    var provider: LLMProvider { get }
    
    func sendMessageStream(text: String) async throws -> AsyncThrowingStream<String, Error>
    func sendMessage(_ text: String) async throws -> String
    func deleteHistoryList()
    
}
