//
//  ViewController.swift
//  VideoCaptureTest
//
//  Created by Peter Edmonston on 11/26/17.
//  Copyright © 2017 com.peteredmonston. All rights reserved.
//

import AVFoundation
import CoreImage
import Metal
import OpenGLES
import UIKit

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    @IBOutlet weak var previewView: UIImageView!
    
    // MARK: - Properties
    
    // MARK: Camera
    
    private var defaultDevice: AVCaptureDevice? {
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera],
                                                       mediaType: .video,
                                                       position: .back)
        return session.devices.first
    }
    
    private lazy var session: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        return session
    }()
    
    private var setupResult = SessionSetupResult.success
    
    // MARK: Core Image
    
    private lazy var wideColorFilter: CIFilter = CIFilter(name: "WideColor")!
    
    private lazy var ciContext: CIContext = {
        let wideColorSpace = CGColorSpace(name: CGColorSpace.extendedSRGB)!
        let floatPixelFormat = NSNumber(value: kCIFormatRGBAh)
        var options = [String: Any]()
        options[kCIContextWorkingColorSpace] = wideColorSpace
        options[kCIContextWorkingFormat] = floatPixelFormat
        return CIContext(options: options)
    }()
    
    // MARK: Queues
    
    private let sessionQueue = DispatchQueue(label: "com.peteredmonston.session_queue")
    private let bufferQueue = DispatchQueue(label: "com.peteredmonston.buffer_queue")
    private let renderQueue = DispatchQueue(label: "com.peteredmonston.render_queue")
    
    // MARK: - Methods
    
    // MARK: View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            try WideColorFilter.setup()
        } catch {
            print("Filter creation failed.")
        }
        requestAuthorizationIfNeeded()
        sessionQueue.async {
            self.setupSession()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        sessionQueue.async {
            guard self.setupResult == .success else {
                DispatchQueue.main.async {
                    self.showAlert(with: self.setupResult.errorMessage)
                }
                return
            }
            self.startSession()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard setupResult == .success else { return }
        sessionQueue.async {
            self.endSession()
        }
    }
    
    // MARK: Private
    
    private func setupSession() {
        guard setupResult == .success else {
            return
        }
        guard let device = defaultDevice else {
            fatalError("No device found")
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            
            session.configure { session in
                session.addInputIfPossible(input)
                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: self.bufferQueue)
                session.addOutputIfPossible(output)
                output.connections.first?.videoOrientation = .portrait
                session.addOutputIfPossible(AVCapturePhotoOutput())
            }
            
            let colorSpace = device.activeColorSpace
            DispatchQueue.main.async {
                switch colorSpace {
                case .sRGB: self.showAlert(with: "Wide color is not active")
                case .P3_D65: break
                }
            }
        }
        catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
            setupResult = .configurationFailed
        }
    }
    
    private func endSession() {
        session.stopRunning()
    }
    
    private func startSession() {
        session.startRunning()
    }
    
    private func requestAuthorizationIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            }
        default: setupResult = .notAuthorized
        }
    }
    
    private func showAlert(with message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        wideColorFilter.setValue(CIImage(cvPixelBuffer: imageBuffer), forKey: kCIInputImageKey)
        guard let output = wideColorFilter.outputImage else { return }
        renderQueue.async {
            let colorSpace = CGColorSpace(name: CGColorSpace.extendedSRGB)
            guard let cgImage = self.ciContext.createCGImage(output,
                                                             from: output.extent,
                                                             format: kCIFormatRGBAh,
                                                             colorSpace: colorSpace) else { return }
            DispatchQueue.main.async {
                self.previewView.image = UIImage(cgImage: cgImage)
            }
        }
    }
}


