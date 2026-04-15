//
//  LocalTTSService.swift
//  IronBuddy
//

import AVFoundation
import Foundation

@MainActor
final class LocalTTSService {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        let enabled = UserDefaults.standard.object(forKey: UserDefaultsKeys.ttsEnabled) as? Bool ?? true
        guard enabled else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        synthesizer.speak(utterance)
    }
}
