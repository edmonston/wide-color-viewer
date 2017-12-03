//
//  Extensions+AVCaptureSession.swift
//  VideoCaptureTest
//
//  Created by Peter Edmonston on 12/3/17.
//  Copyright © 2017 com.peteredmonston. All rights reserved.
//

import Foundation
import AVFoundation

extension AVCaptureSession {
    func configure(_ configuration: (AVCaptureSession) -> ()) {
        beginConfiguration()
        configuration(self)
        commitConfiguration()
    }
    
    func addInputIfPossible(_ input: AVCaptureInput) {
        guard canAddInput(input) else { return }
        addInput(input)
    }
    
    func addOutputIfPossible(_ output: AVCaptureOutput) {
        guard canAddOutput(output) else { return }
        addOutput(output)
    }
}
