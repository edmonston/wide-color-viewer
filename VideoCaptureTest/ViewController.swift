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
    @IBOutlet weak var previewView: PreviewView!
    @IBOutlet weak var miniPreviewView: UIImageView!
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
        
        var errorMessage: String {
            switch self {
            case .success: return ""
            case .notAuthorized: return "Need camera access"
            case .configurationFailed: return "Camera setup failed"
            }
        }
    }
    
    private var defaultDevice: AVCaptureDevice? {
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera], mediaType: .video, position: .back)
        return session.devices.first
    }
    
    private lazy var session: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        return session
    }()
    
    private var setupResult = SessionSetupResult.success
    
    private let sessionQueue = DispatchQueue(label: "com.peteredmonston.session_queue")
    private let bufferQueue = DispatchQueue(label: "com.peteredmonston.buffer_queue")
    private let renderQueue = DispatchQueue(label: "com.peteredmonston.render_queue")
    
    override func viewDidLoad() {
        super.viewDidLoad()
    //    previewView.session = session
        guard let url = Bundle.main.url(forResource: "default", withExtension: "metallib"),
            let data = try? Data(contentsOf: url),
            let kernel = try? CIKernel(functionName: "wide_color_kernel",
                                       fromMetalLibraryData: data,
                                       outputPixelFormat: kCIFormatRGBAh) else {
                fatalError("Unable to get metallib and create kernel")
        }
        WideColorFilter.setup(with: kernel)
        requestAuthorizationIfNeeded()
        sessionQueue.async {
            self.setupSession()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard setupResult == .success else {
            showAlert(with: setupResult.errorMessage)
            return
        }
        sessionQueue.async {
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
    
    private func setupSession() {
        guard let device = defaultDevice else {
            fatalError("No device found")
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            if (session.canAddInput(input)) {
                session.addInput(input)
            }
            
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: self.bufferQueue)
            if (session.canAddOutput(output)) {
                session.addOutput(output)
            }
            output.connections.first?.videoOrientation = .portrait
            
            let photoOutput = AVCapturePhotoOutput()
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
            session.commitConfiguration()
        }
        catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
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
    
    
    let wideColorFilter: CIFilter = WideColorFilter()
    let ciContext: CIContext = {
        let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        let pixelFormat = NSNumber(value: kCIFormatRGBAh)
        let options: [String: Any] = [kCIContextWorkingColorSpace: colorSpace, kCIContextWorkingFormat: pixelFormat]
        return CIContext(options: options)
    }()
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        wideColorFilter.setValue(CIImage(cvPixelBuffer: imageBuffer), forKey: kCIInputImageKey)
        guard let output = wideColorFilter.outputImage else { return }
        renderQueue.async {
            guard let filteredCGImage = self.ciContext.createCGImage(output,
                                                               from: output.extent,
                                                               format: kCIFormatRGBAh,
                                                               colorSpace: CGColorSpace(name: CGColorSpace.extendedSRGB)) else { return }
            DispatchQueue.main.async {
                self.miniPreviewView.image = UIImage(cgImage: filteredCGImage)
            }
        }
    }
}


