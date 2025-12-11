//
//  AppConfig.swift
//  documentAI
//
//  Application configuration
//

import Foundation

enum AppConfig {
    // OpenAI API Key - Replace with your actual key or use environment variable
    static let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] 
        ?? "YOUR_OPENAI_API_KEY_HERE"
    
    // Backend API URL
    static let backendURL = "https://documentai-api-824241800977.us-central1.run.app"
    
    // Feature flags
    static let enableAIChat = true
    static let enableCommonForms = true
    static let showBoundingBoxes = true
}

enum FeatureFlags {
    static let enableAIChat = AppConfig.enableAIChat
    static let enableCommonForms = AppConfig.enableCommonForms
    static let showBoundingBoxes = AppConfig.showBoundingBoxes
}
