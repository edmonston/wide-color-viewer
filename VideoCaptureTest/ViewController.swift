//
//  ViewController.swift
//  VideoCaptureTest
//
//  Created by Peter Edmonston on 11/26/17.
//  Copyright © 2017 com.peteredmonston. All rights reserved.
//

import UIKit
import AVFoundation
import CoreImage
import OpenGLES

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
    
    private lazy var session: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        return session
    }()
    
    private var setupResult = SessionSetupResult.success
    
    private var defaultDevice: AVCaptureDevice? {
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera], mediaType: .video, position: .back)
        return session.devices.first
    }
    
    private let sessionQueue = DispatchQueue(label: "com.peteredmonston.session_queue")
    private let bufferQueue = DispatchQueue(label: "com.peteredmonston.buffer_queue")
    private let renderQueue = DispatchQueue(label: "com.peteredmonston.render_queue")

    override func viewDidLoad() {
        super.viewDidLoad()
        previewView.session = session
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
    
    let rosyFilter: CIFilter = {
        let filter = CIFilter(name: "CIColorMatrix")!// CIFilter(name: "CIColorMatrix")!
        let greenCoeffs: UnsafePointer<CGFloat> = UnsafePointer([CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0)])
        let vector = CIVector(values: greenCoeffs, count: 4)
        filter.setValue(vector, forKey: "inputGVector")
        return filter
    }()
    
    let ciContext: CIContext = {
        let eaglContext = EAGLContext(api: .openGLES2)!
        let options: [String: Any] = [kCIContextWorkingColorSpace: CGColorSpace(name: CGColorSpace.extendedSRGB)!, kCIContextWorkingFormat: NSNumber(value: kCIFormatRGBAh)]
        let context = CIContext(eaglContext: eaglContext, options: options)
        return context
    }()
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        if let iBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let rawImage = CIImage(cvPixelBuffer: iBuffer)
            rosyFilter.setValue(rawImage, forKey: kCIInputImageKey)
            if let output = rosyFilter.outputImage {
                
                renderQueue.async {
                    let filteredCGImage = self.ciContext.createCGImage(output,
                                                                       from: output.extent,
                                                                       format: kCIFormatRGBAh,
                                                                       colorSpace: CGColorSpace(name: CGColorSpace.extendedSRGB))
                    DispatchQueue.main.async {
                        guard let cgImage = filteredCGImage else { return }
                        print("got here with out put \(cgImage.colorSpace!)")
                        let image = UIImage(cgImage: cgImage)
                        self.miniPreviewView.image = image
                    }
                }
            }
            if let space = rawImage.colorSpace {
                print("space: \(space)")
            }
            //print("image: \(image)")
        } else {
            print("nope")
        }
    }
}


