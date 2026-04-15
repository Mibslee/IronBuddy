//
//  VoiceCommandService.swift
//  IronBuddy
//
//  离线语音指令识别：支持"开始"、"停止"、"下一组"等中文指令。
//

import AVFoundation
import Observation
import Speech

enum VoiceCommand: String {
    case start = "开始"
    case stop = "停止"
    case nextSet = "下一组"
    case skip = "跳过"
}

@Observable
@MainActor
final class VoiceCommandService {
    var isListening = false
    var lastCommand: VoiceCommand?
    var onCommand: ((VoiceCommand) -> Void)?

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    }

    func requestPermission() async -> Bool {
        let speechStatus = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                c.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }

        let micStatus = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                c.resume(returning: granted)
            }
        }
        return micStatus
    }

    func startListening() {
        guard let recognizer, recognizer.isAvailable else { return }
        stopListening()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.parseCommand(from: text)
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.restartListening()
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
        } catch {
            stopListening()
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }

    private func restartListening() {
        stopListening()
        startListening()
    }

    private var lastParsedSuffix = ""

    private func parseCommand(from text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed != lastParsedSuffix else { return }

        let commands: [String: VoiceCommand] = [
            "开始": .start,
            "停止": .stop,
            "结束": .stop,
            "下一组": .nextSet,
            "跳过": .skip,
        ]

        for (keyword, cmd) in commands {
            if trimmed.hasSuffix(keyword), !lastParsedSuffix.hasSuffix(keyword) {
                lastCommand = cmd
                onCommand?(cmd)
                break
            }
        }
        lastParsedSuffix = trimmed
    }
}
