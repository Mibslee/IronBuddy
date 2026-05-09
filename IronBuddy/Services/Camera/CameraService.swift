//
//  CameraService.swift
//  IronBuddy
//

import AVFoundation
import Foundation
import UIKit

/// 前置/后置、`BGRA` 输出，供 MediaPipe 与预览层使用。
final class CameraService: NSObject {
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "ironbuddy.camera.session")
    fileprivate let sampleQueue = DispatchQueue(label: "ironbuddy.camera.samples")

    private(set) var devicePosition: AVCaptureDevice.Position = .back
    /// 是否启用最大广角（使用最小可用变焦倍率）。
    var preferUltraWide = false

    private let onFrameLock = NSLock()
    private var _onFrame: ((CMSampleBuffer, AVCaptureConnection) -> Void)?
    var onFrame: ((CMSampleBuffer, AVCaptureConnection) -> Void)? {
        get { onFrameLock.lock(); defer { onFrameLock.unlock() }; return _onFrame }
        set { onFrameLock.lock(); defer { onFrameLock.unlock() }; _onFrame = newValue }
    }

    var useFrontCamera: Bool {
        get { devicePosition == .front }
        set { applyCameraPosition(newValue ? .front : .back) }
    }

    func applyCameraPosition(_ position: AVCaptureDevice.Position) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.devicePosition = position
            self.rebuildSession()
        }
    }

    func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.rebuildSession()
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    /// 设置变焦倍率。支持最小值低于 1.0（超广角设备）。
    func setZoomFactor(_ factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentDevice() else { return }
            let minZoom = device.minAvailableVideoZoomFactor
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0)
            let clamped = min(max(factor, minZoom), maxZoom)
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
            } catch {}
        }
    }

    /// 平滑渐变变焦。
    func rampZoom(to factor: CGFloat, rate: Float = 2.0) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentDevice() else { return }
            let minZoom = device.minAvailableVideoZoomFactor
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0)
            let clamped = min(max(factor, minZoom), maxZoom)
            do {
                try device.lockForConfiguration()
                device.ramp(toVideoZoomFactor: clamped, withRate: rate)
                device.unlockForConfiguration()
            } catch {}
        }
    }

    /// 启用最大广角（最小变焦倍率）。
    func applyUltraWide() {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentDevice() else { return }
            let minZoom = device.minAvailableVideoZoomFactor
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = minZoom
                device.unlockForConfiguration()
            } catch {}
        }
    }

    private func currentDevice() -> AVCaptureDevice? {
        guard let input = session.inputs.first as? AVCaptureDeviceInput else { return nil }
        return input.device
    }

    private func rebuildSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        for input in session.inputs { session.removeInput(input) }
        for output in session.outputs { session.removeOutput(output) }

        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: devicePosition),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }
        session.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: sampleQueue)

        guard session.canAddOutput(videoOutput) else { return }
        session.addOutput(videoOutput)

        if let conn = videoOutput.connection(with: .video) {
            if conn.isVideoRotationAngleSupported(90) {
                conn.videoRotationAngle = 90  // portrait
            }
            if conn.isVideoMirroringSupported, devicePosition == .front {
                conn.isVideoMirrored = true
            }
        }

        // 运动拍摄时启用最大广角，使近距离拍摄能拍到全身
        if preferUltraWide {
            let minZoom = device.minAvailableVideoZoomFactor
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = minZoom
                device.unlockForConfiguration()
            } catch {}
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        onFrame?(sampleBuffer, connection)
    }
}

extension AVCaptureConnection {
    /// 根据 `videoRotationAngle`（0/90/180/270）返回对应的 `UIImage.Orientation`。
    var uiImageOrientation: UIImage.Orientation {
        switch videoRotationAngle {
        case 90:  return .right   // portrait
        case 270: return .left    // portraitUpsideDown
        case 0:   return .up      // landscapeRight
        case 180: return .down    // landscapeLeft
        default:  return .right
        }
    }
}
