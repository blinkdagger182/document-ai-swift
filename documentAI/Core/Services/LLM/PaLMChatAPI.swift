//
//  PaLMChatAPI.swift
//  documentAI
//
//  Google PaLM API client (placeholder for future implementation)
//

import Foundation

class PaLMChatAPI: LLMClient {
    
    var provider: LLMProvider { .palm }
    
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func sendMessageStream(text: String) async throws -> AsyncThrowingStream<String, Error> {
        throw "PaLM API not implemented yet"
    }
    
    func sendMessage(_ text: String) async throws -> String {
        throw "PaLM API not implemented yet"
    }
    
    func deleteHistoryList() {
        // No-op for now
    }
}
