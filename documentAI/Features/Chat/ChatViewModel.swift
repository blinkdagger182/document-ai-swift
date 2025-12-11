//
//  ChatViewModel.swift
//  documentAI
//
//  Chat view model for AI conversations
//

import Foundation
import SwiftUI
import AVKit

class ChatViewModel: ObservableObject {
    
    @Published var isInteracting = false
    @Published var messages: [MessageRow] = []
    @Published var inputMessage: String = ""
    var task: Task<Void, Never>?
    
    private var api: LLMClient
    
    var title: String {
        "DocumentAI Chat"
    }
    
    var navigationTitle: String {
        api.provider.navigationTitle
    }
    
    init(api: LLMClient) {
        self.api = api
    }
    
    func updateClient(_ client: LLMClient) {
        self.messages = []
        self.api = client
    }
    
    @MainActor
    func sendTapped() async {
        self.task = Task {
            let text = inputMessage
            inputMessage = ""
            await sendAttributed(text: text)
        }
    }
    
    @MainActor
    func clearMessages() {
        api.deleteHistoryList()
        withAnimation { [weak self] in
            self?.messages = []
        }
    }
    
    @MainActor
    func retry(message: MessageRow) async {
        self.task = Task {
            guard let index = messages.firstIndex(where: { $0.id == message.id }) else {
                return
            }
            self.messages.remove(at: index)
            await sendAttributed(text: message.sendText)
        }
    }
    
    func cancelStreamingResponse() {
        self.task?.cancel()
        self.task = nil
    }
    
    @MainActor
    private func sendAttributed(text: String) async {
        isInteracting = true
        var streamText = ""
        
        var messageRow = MessageRow(
            isInteracting: true,
            sendImage: "person.circle.fill",
            send: .rawText(text),
            responseImage: "sparkles",
            response: .rawText(streamText),
            responseError: nil)
    
        do {
            let parsingTask = ResponseParsingTask()
            let attributedSend = await parsingTask.parse(text: text)
            try Task.checkCancellation()
            messageRow.send = .attributed(attributedSend)
            
            self.messages.append(messageRow)
            
            let parserThresholdTextCount = 64
            var currentTextCount = 0
            var currentOutput: AttributedOutput?
            
            let stream = try await api.sendMessageStream(text: text)
            for try await text in stream {
                streamText += text
                currentTextCount += text.count
                
                if currentTextCount >= parserThresholdTextCount || text.contains("```") {
                    currentOutput = await parsingTask.parse(text: streamText)
                    try Task.checkCancellation()
                    currentTextCount = 0
                }

                if let currentOutput = currentOutput, !currentOutput.results.isEmpty {
                    let suffixText = streamText.trimmingPrefix(currentOutput.string)
                    var results = currentOutput.results
                    let lastResult = results[results.count - 1]
                    var lastAttrString = lastResult.attributedString
                    if lastResult.isCodeBlock {
                        lastAttrString.append(AttributedString(String(suffixText), attributes: .init([.font: UIFont.systemFont(ofSize: 12).apply(newTraits: .traitMonoSpace), .foregroundColor: UIColor.white])))
                    } else {
                        lastAttrString.append(AttributedString(String(suffixText)))
                    }
                    results[results.count - 1] = ParserResult(attributedString: lastAttrString, isCodeBlock: lastResult.isCodeBlock, codeBlockLanguage: lastResult.codeBlockLanguage)
                    messageRow.response = .attributed(.init(string: streamText, results: results))
                } else {
                    messageRow.response = .attributed(.init(string: streamText, results: [
                        ParserResult(attributedString: AttributedString(stringLiteral: streamText), isCodeBlock: false, codeBlockLanguage: nil)
                    ]))
                }

                self.messages[self.messages.count - 1] = messageRow
                if let currentString = currentOutput?.string, currentString != streamText {
                    let output = await parsingTask.parse(text: streamText)
                    try Task.checkCancellation()
                    messageRow.response = .attributed(output)
                }
            }
        } catch is CancellationError {
            messageRow.responseError = "The response was cancelled"
        } catch {
            messageRow.responseError = error.localizedDescription
        }
        
        if messageRow.response == nil {
            messageRow.response = .rawText(streamText)
        }
  
        messageRow.isInteracting = false
        self.messages[self.messages.count - 1] = messageRow
        isInteracting = false
    }
}

extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
}
